import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/report_model.dart';

abstract class ReportRemoteDataSource {
  Future<List<ReportModel>> getNearbyReports({
    required double lat,
    required double lng,
    double radius = 5.0,
    String? category,
  });
    Future<void> createReport({
        required int userId,
        required double latitude,
        required double longitude,
        required String title,
        required String description,
        required String category,
        int? parentReportId,
    });
    Future<void> voteReport({
        required int reportId,
        required int userId,
        required String type,
    });
    Future<void> addComment({
        required int reportId,
        required int userId,
        required String content,
    });
    Future<List<ReportModel>> getMyReports(int userId);
    Future<List<ReportModel>> getSavedReports(int userId);
    Future<void> saveReport(int reportId, int userId);
    Future<void> unsaveReport(int reportId, int userId);
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
  Future<void> createReport({
    required int userId,
    required double latitude,
    required double longitude,
    required String title,
    required String description,
    required String category,
    int? parentReportId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final options = token != null 
          ? Options(headers: {'Authorization': 'Bearer $token'})
          : Options();

      final response = await dio.post(
        '/api/reports',
        data: {
          'userId': userId,
          'latitude': latitude,
          'longitude': longitude,
          'title': title,
          'description': description,
          'category': category,
          if (parentReportId != null) 'parentReportId': parentReportId,
        },
        options: options,
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to create report');
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Failed to create report');
    }
  }

  @override
  Future<List<ReportModel>> getNearbyReports({
    required double lat,
    required double lng,
    double radius = 5.0,
    String? category,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final options = token != null 
          ? Options(headers: {'Authorization': 'Bearer $token'})
          : Options();

      final Map<String, dynamic> queryParams = {
        'lat': lat,
        'lng': lng,
        'radius': radius,
      };
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = category;
      }

      final response = await dio.get(
        '/api/reports/nearby',
        queryParameters: queryParams,
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

  @override
  Future<void> voteReport({
    required int reportId,
    required int userId,
    required String type,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final options = token != null 
          ? Options(headers: {
              'Authorization': 'Bearer $token',
              'X-User-Id': userId.toString(),
            })
          : Options(headers: {'X-User-Id': userId.toString()});

      final response = await dio.post(
        '/api/reports/$reportId/vote',
        data: {'type': type},
        options: options,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to vote');
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Failed to vote');
    }
  }

  @override
  Future<List<ReportModel>> getMyReports(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final options = token != null 
          ? Options(headers: {'Authorization': 'Bearer $token', 'X-User-Id': userId.toString()})
          : Options(headers: {'X-User-Id': userId.toString()});

      final response = await dio.get('/api/reports/my-reports', options: options);
      if (response.statusCode == 200) {
        final List data = response.data['data'];
        return data.map((json) => ReportModel.fromJson(json as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to load my reports');
    } catch (e) {
      throw Exception('Failed to load my reports: $e');
    }
  }

  @override
  Future<List<ReportModel>> getSavedReports(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final options = token != null 
          ? Options(headers: {'Authorization': 'Bearer $token', 'X-User-Id': userId.toString()})
          : Options(headers: {'X-User-Id': userId.toString()});

      final response = await dio.get('/api/reports/saved', options: options);
      if (response.statusCode == 200) {
        final List data = response.data['data'];
        return data.map((json) {
          final report = ReportModel.fromJson(json as Map<String, dynamic>);
          return report.copyWith(isSaved: true);
        }).toList();
      }
      throw Exception('Failed to load saved reports');
    } catch (e) {
      throw Exception('Failed to load saved reports: $e');
    }
  }

  @override
  Future<void> saveReport(int reportId, int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final options = token != null 
          ? Options(headers: {'Authorization': 'Bearer $token', 'X-User-Id': userId.toString()})
          : Options(headers: {'X-User-Id': userId.toString()});

      final response = await dio.post('/api/reports/$reportId/save', options: options);
      if (response.statusCode != 200) throw Exception('Failed to save report');
    } catch (e) {
      throw Exception('Failed to save report: $e');
    }
  }

  @override
  Future<void> unsaveReport(int reportId, int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final options = token != null 
          ? Options(headers: {'Authorization': 'Bearer $token', 'X-User-Id': userId.toString()})
          : Options(headers: {'X-User-Id': userId.toString()});

      final response = await dio.delete('/api/reports/$reportId/save', options: options);
      if (response.statusCode != 200) throw Exception('Failed to unsave report');
    } catch (e) {
      throw Exception('Failed to unsave report: $e');
    }
  }

  @override
  Future<void> addComment({
    required int reportId,
    required int userId,
    required String content,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      
      final options = token != null 
          ? Options(headers: {
              'Authorization': 'Bearer $token',
              'X-User-Id': userId.toString(),
            })
          : Options(headers: {'X-User-Id': userId.toString()});

      final response = await dio.post(
        '/api/reports/$reportId/comments',
        data: {'content': content},
        options: options,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to add comment');
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Failed to add comment');
    }
  }

  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is Map) {
      return responseData['message'] as String?;
    }
    return null;
  }
}
