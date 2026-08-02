import 'package:dio/dio.dart';
import '../../../../core/storage/local_store.dart';
import '../../domain/models/comment_model.dart';
import '../../domain/models/feed_filter.dart';
import '../../domain/models/report_model.dart';
import '../../domain/models/voter_model.dart';

abstract class ReportRemoteDataSource {
  /// Reports around a point. [filter] decides both which of them come back and
  /// the order they arrive in; leaving it out gives the plain closest-first
  /// list.
  Future<List<ReportModel>> getNearbyReports({
    required double lat,
    required double lng,
    double radius = 5.0,
    String? category,
    int? userId,
    FeedFilter? filter,
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

    /// Edits a report the signed-in user filed. Only the text side changes,
    /// the location it was pinned at stays as it was. Pass `imageUrl: null`
    /// to remove the photo.
    Future<ReportModel> updateReport({
        required int reportId,
        required int userId,
        required String title,
        required String description,
        required String category,
        String evidenceType,
        String? imageUrl,
    });

    /// Sends one photo to the backend, which stores it on Cloudinary and
    /// hands back the link. Call this before [createReport] and pass the
    /// result as `imageUrl`.
    Future<String> uploadReportImage(String filePath);

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

    /// Single report with its location, used by the report details page.
    /// Pass [userId] so the server can resolve saved / vote state.
    Future<ReportModel> getReportById(int reportId, {int? userId});

    /// Comment thread for a report, oldest first.
    Future<List<CommentModel>> getComments(int reportId);

    /// Voters list for a report.
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
                // Generous, because the hosted backend sleeps when idle and a
                // photo upload on mobile data is nowhere near instant.
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
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'lat': lat,
        'lng': lng,
        'radius': radius,
        // The server does the narrowing and the ordering; the app never
        // re-sorts what comes back.
        if (filter != null) ...filter.toQueryParameters(),
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
  Future<List<CommentModel>> getComments(int reportId) async {
    try {
      final response = await dio.get(
        '/api/reports/$reportId/comments',
        options: _authOptions(),
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

  /// Attaches the stored bearer token (and optionally the user id header).
  ///
  /// The token is read straight out of memory — [LocalStore] loaded it during
  /// startup — so every call in this class uses this instead of reopening
  /// storage, which they each used to do.
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
