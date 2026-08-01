import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../Report/domain/models/report_model.dart';

/// One incident returned by the corridor scan, with where it sits relative to
/// the road.
typedef CorridorHit = ({
  ReportModel report,
  double offsetMeters,
  double alongMeters,
});

/// Thrown when the backend does not expose `/api/reports/along-route` yet, so
/// the caller can fall back to probing `/nearby` along the route.
class CorridorEndpointUnavailable implements Exception {
  final String message;
  const CorridorEndpointUnavailable(this.message);

  @override
  String toString() => message;
}

/// Talks to the single-call route corridor endpoint.
class RouteCorridorDataSource {
  final Dio dio;

  RouteCorridorDataSource({
    Dio? dio,
    String baseUrl = 'https://ctrc-backend.onrender.com',
  }) : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  Future<List<CorridorHit>> getReportsAlongRoute({
    required List<LatLng> path,
    double corridorKm = 2.0,
    String? category,
    int? userId,
  }) async {
    if (path.isEmpty) return const [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final headers = <String, dynamic>{
        if (token != null) 'Authorization': 'Bearer $token',
        if (userId != null) 'X-User-Id': userId.toString(),
      };

      final response = await dio.post(
        '/api/reports/along-route',
        data: {
          'path': path
              .map((p) => {'lat': p.latitude, 'lng': p.longitude})
              .toList(),
          'corridorKm': corridorKm,
          if (category != null && category.isNotEmpty && category != 'All')
            'category': category,
        },
        options: headers.isEmpty ? null : Options(headers: headers),
      );

      final data = response.data;
      if (data is! Map || data['data'] is! List) {
        throw const CorridorEndpointUnavailable(
          'Corridor endpoint returned an unexpected body',
        );
      }

      return (data['data'] as List)
          .whereType<Map>()
          .map(_parseHit)
          .whereType<CorridorHit>()
          .toList();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // A backend that predates this endpoint answers 404/405; treat that as
      // "not deployed yet" rather than a hard failure.
      if (status == 404 || status == 405 || status == 501) {
        throw CorridorEndpointUnavailable(
          'Backend has no /along-route endpoint (HTTP $status)',
        );
      }
      rethrow;
    }
  }

  CorridorHit? _parseHit(Map raw) {
    final reportJson = raw['report'];
    if (reportJson is! Map) return null;

    return (
      report: ReportModel.fromJson(Map<String, dynamic>.from(reportJson)),
      offsetMeters: ((raw['offsetMeters'] as num?) ?? 0).toDouble(),
      alongMeters: ((raw['alongMeters'] as num?) ?? 0).toDouble(),
    );
  }
}
