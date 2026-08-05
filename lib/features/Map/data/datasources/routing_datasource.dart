import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/route_models.dart';
import 'geo_request_cache.dart';

class RoutingDataSource {
  final Dio _dio;

  static final GeoRequestCache<List<RoutePlan>> _routeCache =
      GeoRequestCache<List<RoutePlan>>(
    ttl: Duration(minutes: 20),
    maxEntries: 20,
  );

  RoutingDataSource({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://router.project-osrm.org',
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
              ),
            );

  Future<List<RoutePlan>> route({
    required LatLng from,
    required LatLng to,
    String profile = 'driving',
  }) async {
    final coords = '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}';

    final cacheKey = '$profile|$coords';
    final cached = _routeCache.get(cacheKey);
    if (cached != null) return cached;

    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '/route/v1/$profile/$coords',
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'alternatives': 'true',
          'steps': 'false',
        },
      );
    } on DioException catch (e) {
      throw GeoServiceException.fromStatus(e.response?.statusCode, 'routing');
    }

    final data = response.data;
    if (data is! Map || data['routes'] is! List) {
      throw const GeoServiceException(
        'The routing service returned an unexpected response.',
      );
    }

    final routes = (data['routes'] as List)
        .whereType<Map>()
        .map(_parseRoute)
        .whereType<RoutePlan>()
        .toList();

    if (routes.isEmpty) {
      throw const GeoServiceException(
        'No road route found between those two points.',
      );
    }

    routes.sort((a, b) => a.duration.compareTo(b.duration));
    _routeCache.put(cacheKey, routes);
    return routes;
  }

  RoutePlan? _parseRoute(Map raw) {
    final geometry = raw['geometry'];
    if (geometry is! Map || geometry['coordinates'] is! List) return null;

    final points = (geometry['coordinates'] as List)
        .whereType<List>()
        .where((c) => c.length >= 2)
        .map((c) => LatLng(
              (c[1] as num).toDouble(),
              (c[0] as num).toDouble(),
            ))
        .toList();

    if (points.length < 2) return null;

    return RoutePlan(
      points: points,
      distanceMeters: ((raw['distance'] as num?) ?? 0).toDouble(),
      duration: Duration(seconds: ((raw['duration'] as num?) ?? 0).round()),
    );
  }
}
