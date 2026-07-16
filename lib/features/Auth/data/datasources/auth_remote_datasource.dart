import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/user_model.dart';

/// Abstract class for remote authentication data source
abstract class AuthRemoteDataSource {
  Future<UserModel> signIn({required String email, required String password});

  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    String? address, // Optional — null by default
    String? image_url, // Optional — null by default
  });

  Future<UserModel> getCurrentUser();

  Future<void> signOut();

  Future<void> resetPassword(String email);

  Future<UserModel> updateProfile({
    String? name,
    String? address,
    String? image_url,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({
    Dio? dio,
    String baseUrl =
        'http://127.0.0.1:8089', // Use localhost with adb reverse for physical device
  }) : dio =
           dio ??
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
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        // Save token to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['data']['token'] as String);
        
        // Backend returns ApiResponse<AuthResponse>: { success, data: {token: ..., user: {...}}, message }
        return UserModel.fromJson(data['data']['user'] as Map<String, dynamic>);
      } else {
        throw Exception(
          _extractErrorMessage(response.data) ?? 'Failed to sign in',
        );
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Sign in error');
    }
  }

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    String? address, // Optional — null by default
    String? image_url, // Optional — null by default
  }) async {
    try {
      final response = await dio.post(
        '/api/auth/signup',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'confirmPassword': password, // default confirmation match
          // Only include address & imageUrl if non-null; backend treats missing/null as NULL
          if (address != null) 'address': address,
          if (image_url != null) 'imageUrl': image_url,
        },
      );

      if (response.statusCode == 201) {
        final data = response.data;
        // Save token to preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['data']['token'] as String);
        
        return UserModel.fromJson(data['data']['user'] as Map<String, dynamic>);
      } else {
        throw Exception(
          _extractErrorMessage(response.data) ?? 'Failed to sign up',
        );
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Sign up error');
    }
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) {
      throw Exception('No token found');
    }
    
    try {
      final response = await dio.get(
        '/api/users/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        return UserModel.fromJson(data['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to get current user');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 400) {
        await prefs.remove('auth_token');
      }
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Session expired');
    }
  }

  @override
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  @override
  Future<void> resetPassword(String email) async {
    // Reset password simulation
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? address,
    String? image_url,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    
    if (token == null) {
      throw Exception('No token found');
    }
    
    try {
      final response = await dio.put(
        '/api/users/me',
        data: {
          'name': name,
          'address': address,
          'imageUrl': image_url,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        return UserModel.fromJson(data['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to update profile');
      }
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data);
      throw Exception(message ?? e.message ?? 'Profile update error');
    }
  }

  String? _extractErrorMessage(dynamic responseData) {
    if (responseData is Map) {
      return responseData['message'] as String?;
    }
    return null;
  }
}
