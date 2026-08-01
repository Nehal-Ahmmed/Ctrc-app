import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/geo_bounds.dart';
import '../../domain/models/map_scope.dart';
import '../../domain/models/place_suggestion.dart';
import 'geo_request_cache.dart';

/// Nominatim-backed search / reverse geocoding.
///
/// Nominatim is free but asks for an identifying User-Agent and no more than
/// one request a second. Three things keep us inside that budget:
///  * callers debounce typing (see `PlaceAutocompleteField`),
///  * every result is cached, so repeating a search costs nothing,
///  * outgoing calls are serialised through a [RequestThrottle].
class GeocodingDataSource {
  final Dio _dio;

  /// Shared across instances so the map page and the route planner sheet see
  /// each other's cached results and share one request budget.
  static final GeoRequestCache<List<PlaceSuggestion>> _searchCache =
      GeoRequestCache<List<PlaceSuggestion>>();
  static final GeoRequestCache<ResolvedArea> _areaCache =
      GeoRequestCache<ResolvedArea>(ttl: const Duration(hours: 1));
  static final GeoRequestCache<String> _describeCache =
      GeoRequestCache<String>(ttl: const Duration(hours: 1));
  static final RequestThrottle _throttle = RequestThrottle();

  GeocodingDataSource({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://nominatim.openstreetmap.org',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'User-Agent': 'com.ctrc.app (CTRC incident map)',
                  'Accept': 'application/json',
                },
              ),
            );

  /// Free-text place / institution lookup. Results are biased towards [near]
  /// when a location is known so local matches surface first.
  ///
  /// Throws [GeoServiceException] when the service is unreachable or busy.
  Future<List<PlaceSuggestion>> search(
    String query, {
    LatLng? near,
    int limit = 6,
    CancelToken? cancelToken,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    final asCoordinates = PlaceSuggestion.tryParseCoordinates(trimmed);
    if (asCoordinates != null) return [asCoordinates];

    final cacheKey = _searchKey(trimmed, near);
    final cached = _searchCache.get(cacheKey);
    if (cached != null) return cached;

    final params = <String, dynamic>{
      'q': trimmed,
      'format': 'jsonv2',
      'addressdetails': 1,
      'limit': limit,
    };

    if (near != null) {
      // ~1.5 degree box around the user, as a soft preference only.
      params['viewbox'] = '${near.longitude - 1.5},${near.latitude + 1.5},'
          '${near.longitude + 1.5},${near.latitude - 1.5}';
      params['bounded'] = 0;
    }

    try {
      final response = await _throttle.run(() {
        // The user may have typed on while we waited our turn in the queue;
        // skipping here also frees the slot for the newer query immediately.
        if (cancelToken?.isCancelled ?? false) {
          throw const ThrottledRequestSkipped();
        }
        return _dio.get<dynamic>(
          '/search',
          queryParameters: params,
          cancelToken: cancelToken,
        );
      });

      final data = response.data;
      if (data is! List) return const [];

      final results = data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(PlaceSuggestion.fromNominatim)
          .toList();

      _searchCache.put(cacheKey, results);
      return results;
    } on ThrottledRequestSkipped {
      // A newer query is already running; the caller ignores stale results.
      return const [];
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      throw GeoServiceException.fromStatus(e.response?.statusCode, 'place search');
    }
  }

  /// Resolves an administrative [scope] (city / division) around [at] into a
  /// concrete circle + bounding box. Falls back to a fixed radius on failure.
  Future<ResolvedArea> resolveArea({
    required LatLng at,
    required MapScope scope,
  }) async {
    final fixed = scope.fixedRadiusMeters;
    if (fixed != null) {
      return ResolvedArea(scope: scope, center: at, radiusMeters: fixed);
    }

    // Administrative areas are huge, so a coarse key still hits for anyone
    // moving around inside the same city.
    final cacheKey = '${scope.name}|${_round(at.latitude, 1)},'
        '${_round(at.longitude, 1)}';
    final cached = _areaCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      final response = await _throttle.run(() => _dio.get<dynamic>(
            '/reverse',
            queryParameters: {
              'lat': at.latitude,
              'lon': at.longitude,
              'format': 'jsonv2',
              'addressdetails': 1,
              'zoom': scope.reverseZoom,
            },
          ));

      final data = response.data;
      if (data is! Map) return ResolvedArea.fallback(scope, at);

      final json = Map<String, dynamic>.from(data);
      final bounds = GeoBounds.fromNominatim(json['boundingbox']);
      final address = json['address'] is Map
          ? Map<String, dynamic>.from(json['address'] as Map)
          : const <String, dynamic>{};

      final name = scope == MapScope.city
          ? (address['city'] ??
              address['town'] ??
              address['municipality'] ??
              address['county'] ??
              address['state_district']) as String?
          : (address['state'] ??
              address['region'] ??
              address['state_district']) as String?;

      final ResolvedArea area;
      if (bounds == null) {
        area = ResolvedArea(
          scope: scope,
          center: at,
          radiusMeters: scope.fallbackRadiusMeters,
          name: name,
        );
      } else {
        // Guard against Nominatim occasionally handing back a country-sized box.
        final radius = bounds.radiusMeters.clamp(
          scope == MapScope.city ? 3000.0 : 20000.0,
          scope == MapScope.city ? 60000.0 : 300000.0,
        );

        area = ResolvedArea(
          scope: scope,
          center: bounds.center,
          radiusMeters: radius,
          bounds: bounds,
          name: name,
        );
      }

      _areaCache.put(cacheKey, area);
      return area;
    } catch (_) {
      // The map still works with a sensible fixed radius, so never surface this.
      return ResolvedArea.fallback(scope, at);
    }
  }

  /// Short human label for a point, used for the "From: current location" row.
  Future<String?> describe(LatLng at) async {
    final cacheKey = '${_round(at.latitude, 3)},${_round(at.longitude, 3)}';
    final cached = _describeCache.get(cacheKey);
    if (cached != null) return cached;

    try {
      final response = await _throttle.run(() => _dio.get<dynamic>(
            '/reverse',
            queryParameters: {
              'lat': at.latitude,
              'lon': at.longitude,
              'format': 'jsonv2',
              'zoom': 16,
            },
          ));

      final data = response.data;
      if (data is! Map) return null;
      final display = data['display_name'] as String?;
      if (display == null) return null;

      final label =
          display.split(',').map((e) => e.trim()).take(3).join(', ');
      _describeCache.put(cacheKey, label);
      return label;
    } catch (_) {
      return null;
    }
  }

  String _searchKey(String query, LatLng? near) {
    final bias = near == null
        ? 'anywhere'
        : '${_round(near.latitude, 1)},${_round(near.longitude, 1)}';
    return '${query.toLowerCase()}|$bias';
  }

  static String _round(double value, int decimals) =>
      value.toStringAsFixed(decimals);
}
