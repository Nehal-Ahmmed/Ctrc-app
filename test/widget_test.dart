import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ctrc/features/Auth/data/datasources/auth_remote_datasource.dart';
import 'package:ctrc/features/Auth/domain/models/user_model.dart';
import 'package:ctrc/features/Auth/presentation/providers/auth_provider.dart';
import 'package:ctrc/main.dart';

class _FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  @override
  Future<bool> checkHealth() async => false;

  @override
  Future<UserModel> getCurrentUser() async => throw Exception('No token found');

  @override
  Future<void> signOut() async {}

  @override
  Future<void> resetPassword(String email) async {}

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async =>
      throw UnimplementedError();

  @override
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    String? address,
    String? image_url,
  }) async =>
      throw UnimplementedError();

  @override
  Future<UserModel> updateProfile({
    String? name,
    String? address,
    String? image_url,
  }) async =>
      throw UnimplementedError();

  @override
  Future<UserModel> uploadAvatar(String filePath) async =>
      throw UnimplementedError();

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async =>
      throw UnimplementedError();
}

void main() {
  setUp(() {
    
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App opens on the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRemoteDataSourceProvider
              .overrideWithValue(_FakeAuthRemoteDataSource()),
        ],
        child: const CTRCApp(),
      ),
    );
    await tester.pump();

    expect(find.text('CTRC System'), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
