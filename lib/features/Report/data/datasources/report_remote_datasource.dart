import 'package:dio/dio.dart';
import '../../../../core/storage/local_store.dart';
import '../../domain/models/comment_model.dart';
import '../../domain/models/feed_filter.dart';
import '../../domain/models/report_model.dart';
import '../../domain/models/sub_report_model.dart';
import '../../domain/models/voter_model.dart';

abstract class ReportRemoteDataSource {
  
  Future<List<ReportModel>> getNearbyReports({
    required double lat,
    required double lng,
    double radius = 5.0,
    String? category,
    int? userId,
    FeedFilter? filter,

    int? withinHours,
  });
    Future<void> createReport({
        required int userId,
        required double latitude,
        required double longitude,
        required String title,
        required String description,
        required String category,
        String evidenceType,
        String? imageUrl,
        int? parentReportId,
        String? address,
        String? city,
    });

    Future<ReportModel> updateReport({
        required int reportId,
        required int userId,
        required String title,
        required String description,
        required String category,
        String evidenceType,
        String? imageUrl,
    });

    Future<void> deleteReport({
        required int reportId,
        required int userId,
    });

    Future<String> uploadReportImage(String filePath);

    Future<SubReportModel> getSubReportById(int subReportId, {int? userId});

    Future<List<CommentModel>> getSubReportComments(int subReportId, {int? userId});

    Future<void> addSubReportComment({
        required int subReportId,
        required int userId,
        required String content,
    });

    Future<void> voteSubReport({
        required int subReportId,
        required int userId,
        required String type,
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

    Future<ReportModel> getReportById(int reportId, {int? userId});

    Future<List<CommentModel>> getComments(int reportId, {int? userId});

    Future<String?> voteComment({
        required int commentId,
        required int userId,
        required String type,
    });

    Future<List<VoterModel>> getVotes(int reportId);
}

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final Dio dio;

  ReportRemoteDataSourceImpl({
    Dio? dio,
    String baseUrl = 'https://ctrc-backend.onrender.com', 
  }) : dio = dio ??
            (Dio(
              BaseOptions(
                baseUrl: baseUrl,
                
                connectTimeout: const Duration(seconds: 60),
                receiveTimeout: const Duration(seconds: 60),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            )..interceptors.add(LogInterceptor(
                request: true,
                requestBody: true,
                responseBody: true,
                error: true,
              )));

  @override
  Future<void> createReport({
    required int userId,
    required double latitude,
    required double longitude,
    required String title,
    required String description,
    required String category,
    String evidenceType = 'seen',
    String? imageUrl,
    int? parentReportId,
    String? address,
    String? city,
  }) async {
    try {
      final response = await dio.post(
        '/api/reports',
        data: {
          'userId': userId,
          'latitude': latitude,
          'longitude': longitude,
          'title': title,
          'description': description,
          'category': category,
          'evidenceType': evidenceType,
          if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
          if (parentReportId != null) 'parentReportId': parentReportId,
          if (address != null && address.isNotEmpty) 'address': address,
          if (city != null && city.isNotEmpty) 'city': city,
        },
        options: _authOptions(),
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
  Future<ReportModel> updateReport({
    required int reportId,
    required int userId,
    required String title,
    required String description,
    required String category,
    String evidenceType = 'seen',
    String? imageUrl,
  }) async {
    try {
      final response = await dio.put(
        '/api/reports/$reportId',
        data: {
          'title': title,
          'description': description,
          'category': category,
          'evidenceType': evidenceType,
          'imageUrl': imageUrl,
        },
        options: _authOptions(userId: userId),
      );

      final body = response.data;
      if (body is Map && body['data'] is Map) {
        return ReportModel.fromJson(
          Map<String, dynamic>.from(body['data'] as Map),
        );
      }
      throw Exception('Failed to update report');
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Failed to update report');
    }
  }

  @override
  Future<void> deleteReport({
    required int reportId,
    required int userId,
  }) async {
    try {
      final response = await dio.delete(
        '/api/reports/$reportId',
        options: _authOptions(userId: userId),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to delete report');
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Failed to delete report');
    }
  }

  @override
  Future<SubReportModel> getSubReportById(int subReportId, {int? userId}) async {
    try {
      final response = await dio.get(
        '/api/sub-reports/$subReportId',
        options: userId != null ? _authOptions(userId: userId) : null,
      );
      return SubReportModel.fromJson(response.data['data']);
    } catch (e) {
      throw Exception('Failed to load sub-report');
    }
  }

  @override
  Future<List<CommentModel>> getSubReportComments(int subReportId,
      {int? userId}) async {
    try {
      final response = await dio.get(
        '/api/sub-reports/$subReportId/comments',
        options: _authOptions(userId: userId),
      );
      final list = response.data['data'] as List;
      return list.map((c) => CommentModel.fromJson(c)).toList();
    } catch (e) {
      throw Exception('Failed to load sub-report comments');
    }
  }

  @override
  Future<void> addSubReportComment({
    required int subReportId,
    required int userId,
    required String content,
  }) async {
    try {
      await dio.post(
        '/api/sub-reports/$subReportId/comments',
        data: {'content': content},
        options: _authOptions(userId: userId),
      );
    } catch (e) {
      throw Exception('Failed to add comment to sub-report');
    }
  }

  @override
  Future<void> voteSubReport({
    required int subReportId,
    required int userId,
    required String type,
  }) async {
    try {
      await dio.post(
        '/api/sub-reports/$subReportId/vote',
        data: {'type': type},
        options: _authOptions(userId: userId),
      );
    } catch (e) {
      throw Exception('Failed to vote on sub-report');
    }
  }

  @override
  Future<String> uploadReportImage(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
      });

      final response = await dio.post(
        '/api/reports/upload-image',
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      final body = response.data;
      final url = body is Map
          ? (body['data'] is Map ? body['data']['url'] : body['url'])
          : null;

      if (url is! String || url.isEmpty) {
        throw Exception('Upload did not return an image link');
      }
      return url;
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Failed to upload the photo');
    }
  }

  @override
  Future<List<ReportModel>> getNearbyReports({
    required double lat,
    required double lng,
    double radius = 5.0,
    String? category,
    int? userId,
    FeedFilter? filter,
    int? withinHours,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'lat': lat,
        'lng': lng,
        'radius': radius,
        
        if (filter != null) ...filter.toQueryParameters(),
        
        if (withinHours != null) 'withinHours': withinHours,
      };
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = category;
      }

      final response = await dio.get(
        '/api/reports/nearby',
        queryParameters: queryParams,
        options: _authOptions(userId: userId),
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
      final response = await dio.post(
        '/api/reports/$reportId/vote',
        data: {'type': type},
        options: _authOptions(userId: userId),
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
      final response = await dio.get(
        '/api/reports/my-reports',
        options: _authOptions(userId: userId),
      );
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
      final response = await dio.get(
        '/api/reports/saved',
        options: _authOptions(userId: userId),
      );
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
      final response = await dio.post(
        '/api/reports/$reportId/save',
        options: _authOptions(userId: userId),
      );
      if (response.statusCode != 200) throw Exception('Failed to save report');
    } catch (e) {
      throw Exception('Failed to save report: $e');
    }
  }

  @override
  Future<void> unsaveReport(int reportId, int userId) async {
    try {
      final response = await dio.delete(
        '/api/reports/$reportId/save',
        options: _authOptions(userId: userId),
      );
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
      final response = await dio.post(
        '/api/reports/$reportId/comments',
        data: {'content': content},
        options: _authOptions(userId: userId),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to add comment');
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Failed to add comment');
    }
  }

  @override
  Future<ReportModel> getReportById(int reportId, {int? userId}) async {
    try {
      final response = await dio.get(
        '/api/reports/$reportId',
        options: _authOptions(userId: userId),
      );

      final data = response.data;
      if (response.statusCode == 200 && data is Map && data['data'] != null) {
        return ReportModel.fromJson(
          Map<String, dynamic>.from(data['data'] as Map),
        );
      }
      throw Exception('Failed to load report');
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Failed to load report');
    }
  }

  @override
  Future<List<CommentModel>> getComments(int reportId, {int? userId}) async {
    try {
      final response = await dio.get(
        '/api/reports/$reportId/comments',
        options: _authOptions(userId: userId),
      );

      final data = response.data;
      if (response.statusCode == 200 && data is Map && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map((json) => CommentModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Failed to load comments');
    }
  }

  @override
  Future<String?> voteComment({
    required int commentId,
    required int userId,
    required String type,
  }) async {
    try {
      final response = await dio.post(
        '/api/comments/$commentId/vote',
        data: {'type': type},
        options: _authOptions(userId: userId),
      );

      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return (data['data'] as Map)['userVoteType'] as String?;
      }
      return null;
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Failed to vote on the comment');
    }
  }

  Options _authOptions({int? userId}) {
    final token = LocalStore.instance.getString(StorageKeys.authToken);

    final headers = <String, dynamic>{
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (userId != null) 'X-User-Id': userId.toString(),
    };

    return headers.isEmpty ? Options() : Options(headers: headers);
  }

  @override
  Future<List<VoterModel>> getVotes(int reportId) async {
    try {
      final response = await dio.get(
        '/api/reports/$reportId/votes',
        options: _authOptions(),
      );

      final data = response.data;
      if (response.statusCode == 200 && data is Map && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map((json) => VoterModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Failed to load voters');
    }
  }

  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is Map) {
      return responseData['message'] as String?;
    }
    return null;
  }
}
