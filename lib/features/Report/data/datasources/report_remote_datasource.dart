import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/report_model.dart';

abstract class ReportRemoteDataSource {
  Future<List<ReportModel>> getNearbyReports({
    required double lat,
    required double lng,
    double radius = 5.0,
  });
}

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final Dio dio;

  ReportRemoteDataSourceImpl({
    Dio? dio,
    String baseUrl = 'https://ctrc-backend.onrender.com', 
  }) : dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 10),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  @override
  Future<List<ReportModel>> getNearbyReports({
    required double lat,
    required double lng,
    double radius = 5.0,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final options = token != null 
          ? Options(headers: {'Authorization': 'Bearer $token'})
          : Options();

      final response = await dio.get(
        '/api/reports/nearby',
        queryParameters: {
          'lat': lat,
          'lng': lng,
          'radius': radius,
        },
        options: options,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final List<dynamic> reportsData = data['data'];
          return reportsData.map((json) => ReportModel.fromJson(json as Map<String, dynamic>)).toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch nearby reports');
        }
      } else {
        throw Exception('Failed to fetch nearby reports');
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Failed to fetch nearby reports');
    }
  }

  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is Map) {
      return responseData['message'] as String?;
    }
    return null;
  }
}
