import 'package:ctrc/features/Auth/data/datasources/auth_remote_datasource.dart';
import 'package:ctrc/features/Auth/domain/models/user_model.dart';
import 'package:ctrc/features/Auth/presentation/providers/auth_provider.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = UserModel(
  user_id: '7',
  email: 'commuter@example.com',
  name: 'Commuter',
  password: '',
);

/// In-memory stand-in: starts signed in, and records whether the token was
/// actually asked to go away.
class _FakeAuthRemoteDataSource implements AuthRemoteDataSource {
  bool hasToken;
  bool failSignOut;

  _FakeAuthRemoteDataSource({this.hasToken = true, this.failSignOut = false});

  @override
  Future<bool> checkHealth() async => true;

  @override
  Future<UserModel> getCurrentUser() async {
    if (!hasToken) throw Exception('No token found');
    return _user;
  }

  @override
  Future<void> signOut() async {
    if (failSignOut) throw Exception('Storage unavailable');
    hasToken = false;
  }

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    hasToken = true;
    return _user;
  }

  @override
  Future<void> resetPassword(String email) async {}

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

ProviderContainer _containerWith(AuthRemoteDataSource dataSource) {
  final container = ProviderContainer(
    overrides: [authRemoteDataSourceProvider.overrideWithValue(dataSource)],
  );
  addTearDown(container.dispose);
  return container;
}

/// Waits for [AuthNotifier]'s constructor-time session restore to land.
Future<void> _settle(ProviderContainer container) async {
  container.read(authProvider);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('AuthState', () {
    test('a plain copyWith keeps the signed-in user', () {
      const state = AuthState(status: AuthStatus.authenticated, user: _user);

      expect(state.copyWith(isSubmitting: true).user, _user);
    });

    test('clearUser is the only way to empty the session', () {
      const state = AuthState(status: AuthStatus.authenticated, user: _user);

      // `user: null` reads as "leave unchanged", which is why the flag exists.
      expect(state.copyWith(user: null).user, _user);
      expect(state.copyWith(clearUser: true).user, isNull);
    });
  });

  group('signOut', () {
    test('drops the user and the session status', () async {
      final container = _containerWith(_FakeAuthRemoteDataSource());
      await _settle(container);
      expect(container.read(authProvider).user, isNotNull);

      await container.read(authProvider.notifier).signOut();

      final state = container.read(authProvider);
      expect(state.user, isNull);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.isSubmitting, isFalse);
    });

    test('reaches the guest state even if clearing the token fails', () async {
      final dataSource = _FakeAuthRemoteDataSource(failSignOut: true);
      final container = _containerWith(dataSource);
      await _settle(container);

      await container.read(authProvider.notifier).signOut();

      expect(container.read(authProvider).user, isNull);
      expect(container.read(isAuthenticatedProvider), isFalse);
    });

    test('flips every auth-gated derived provider', () async {
      final container = _containerWith(_FakeAuthRemoteDataSource());
      await _settle(container);
      expect(container.read(isAuthenticatedProvider), isTrue);
      expect(container.read(authIdentityProvider), '7');

      await container.read(authProvider.notifier).signOut();

      expect(container.read(isAuthenticatedProvider), isFalse);
      expect(container.read(authIdentityProvider), isNull);
    });

    test('a failed session restore leaves nobody signed in', () async {
      final container =
          _containerWith(_FakeAuthRemoteDataSource(hasToken: false));
      await _settle(container);

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      expect(container.read(authProvider).user, isNull);
      expect(container.read(isAuthenticatedProvider), isFalse);
    });
  });

  group('ReportModel.withoutViewerState', () {
    test('forgets the previous viewer save and vote', () {
      final report = ReportModel(
        reportId: 1,
        userId: 7,
        locationId: 1,
        title: 'Waterlogging',
        category: 'Flood',
        isSaved: true,
        userVoteType: 'up',
        upvoteCount: 4,
        commentCount: 2,
      );

      final guest = report.withoutViewerState();

      expect(guest.isSaved, isFalse);
      expect(guest.userVoteType, isNull);
      // Everything public about the incident is untouched.
      expect(guest.upvoteCount, 4);
      expect(guest.commentCount, 2);
      expect(guest.title, 'Waterlogging');
    });
  });
}
