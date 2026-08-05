import 'package:ctrc/core/storage/local_store.dart';
import 'package:ctrc/features/Auth/data/datasources/auth_local_datasource.dart';
import 'package:ctrc/features/Auth/data/datasources/auth_remote_datasource.dart';
import 'package:ctrc/features/Auth/data/repositories/auth_repository_impl.dart';
import 'package:ctrc/features/Auth/domain/models/user_model.dart';
import 'package:ctrc/features/Auth/presentation/providers/auth_provider.dart';
import 'package:ctrc/features/Report/data/datasources/report_local_cache.dart';
import 'package:ctrc/features/Report/domain/models/feed_filter.dart';
import 'package:ctrc/features/Report/domain/models/report_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = UserModel(
  user_id: '7',
  email: 'commuter@example.com',
  name: 'Commuter',
  password: 'hunter2',
);

class _OfflineRemote implements AuthRemoteDataSource {
  int currentUserCalls = 0;

  @override
  Future<UserModel> getCurrentUser() async {
    currentUserCalls++;
    throw Exception('Could not reach the server');
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> checkHealth() async => false;

  @override
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    await AuthLocalDataSourceImpl().saveToken('issued-token');
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

class _RejectingRemote extends _OfflineRemote {
  @override
  Future<UserModel> getCurrentUser() async {
    currentUserCalls++;
    throw const SessionExpiredException();
  }
}

void _seedSession(LocalStore store) {
  store.setString(StorageKeys.authToken, 'stored-token');
  store.setStamped(StorageKeys.authUser, {
    'id': _user.user_id,
    'email': _user.email,
    'name': _user.name,
  });
}

ProviderContainer _containerWith(AuthRemoteDataSource remote) {
  final container = ProviderContainer(
    overrides: [authRemoteDataSourceProvider.overrideWithValue(remote)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle(ProviderContainer container) async {
  container.read(authProvider);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  final store = LocalStore.instance;
  setUp(store.resetForTest);

  group('LocalStore', () {
    test('reads back what it wrote, without waiting on the disk', () {
      store.setString('greeting', 'hello');
      store.setJson('filter', const FeedFilter().toJson());

      expect(store.getString('greeting'), 'hello');
      expect(store.getJson('filter'), isA<Map>());
    });

    test('unreadable json is dropped rather than thrown', () {
      store.setString('broken', '{not json');

      expect(store.getJson('broken'), isNull);
      
      expect(store.getString('broken'), isNull);
    });

    test('clearing one account leaves the device preferences alone', () async {
      store.setInt(StorageKeys.themeMode, 2);
      store.setString(StorageKeys.scoped('reports.feed', '7'), 'mine');
      store.setString(StorageKeys.scoped('reports.feed', '9'), 'someone else');

      await store.clearUserScope('7');

      expect(store.getString(StorageKeys.scoped('reports.feed', '7')), isNull);
      expect(store.getString(StorageKeys.scoped('reports.feed', '9')), isNotNull);
      expect(store.getInt(StorageKeys.themeMode), 2);
    });
  });

  group('AuthLocalDataSource', () {
    final local = AuthLocalDataSourceImpl();

    test('a saved session comes back whole', () async {
      await local.saveToken('abc');
      await local.saveUser(_user);

      final session = local.readSession();
      expect(session, isNotNull);
      expect(session!.token, 'abc');
      expect(session.user.user_id, '7');
      expect(session.user.name, 'Commuter');
      expect(session.user.email, 'commuter@example.com');
    });

    test('the password is never written to the device', () async {
      await local.saveToken('abc');
      await local.saveUser(_user);

      expect(local.readSession()!.user.password, isEmpty);
      expect(
        store.getString(StorageKeys.authUser),
        isNot(contains('hunter2')),
      );
    });

    test('a profile without a token is not a session', () async {
      await local.saveUser(_user);

      expect(local.readSession(), isNull);
    });

    test('clearing takes the account cache with it', () async {
      await local.saveToken('abc');
      await local.saveUser(_user);
      await ReportLocalCache().write(
        ReportLocalCache.feedBucket,
        [_report],
        userId: '7',
      );

      await local.clear();

      expect(local.readSession(), isNull);
      expect(local.readToken(), isNull);
      expect(
        ReportLocalCache().read(ReportLocalCache.feedBucket, userId: '7'),
        isNull,
      );
    });
  });

  group('session restore', () {
    test('opens signed in from the device before the server answers', () async {
      _seedSession(store);
      final remote = _OfflineRemote();
      final container = _containerWith(remote);

      container.read(authProvider);

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.name, 'Commuter');
      expect(state.isRevalidating, isTrue);
    });

    test('an unreachable backend does not sign anybody out', () async {
      _seedSession(store);
      final remote = _OfflineRemote();
      final container = _containerWith(remote);

      await _settle(container);

      expect(remote.currentUserCalls, 1);
      expect(container.read(isAuthenticatedProvider), isTrue);
      expect(container.read(authProvider).isRevalidating, isFalse);
      
      expect(AuthLocalDataSourceImpl().readSession(), isNotNull);
    });

    test('a refused token ends the session and wipes it', () async {
      _seedSession(store);
      final container = _containerWith(_RejectingRemote());

      await _settle(container);

      expect(container.read(isAuthenticatedProvider), isFalse);
      expect(container.read(authProvider).user, isNull);
      expect(AuthLocalDataSourceImpl().readSession(), isNull);
    });

    test('nothing stored means nobody is signed in', () async {
      final container = _containerWith(_OfflineRemote());

      await _settle(container);

      expect(container.read(authProvider).status, AuthStatus.unauthenticated);
      expect(container.read(isAuthenticatedProvider), isFalse);
    });

    test('signing in stores the profile for next time', () async {
      final container = _containerWith(_OfflineRemote());
      await _settle(container);

      await container
          .read(authProvider.notifier)
          .signIn(email: _user.email, password: 'hunter2');

      expect(AuthLocalDataSourceImpl().readSession()?.user.name, 'Commuter');
    });

    test('signing out clears the device even if the call fails', () async {
      _seedSession(store);
      final repository = AuthRepositoryImpl(remoteDataSource: _ThrowingSignOut());

      await repository.signOut();

      expect(AuthLocalDataSourceImpl().readSession(), isNull);
    });
  });

  group('FeedFilter storage', () {
    test('survives a round trip', () {
      const filter = FeedFilter(
        sort: FeedSort.top,
        status: FeedStatus.verified,
        evidence: FeedEvidence.seen,
        age: FeedAge.lastDay,
        withPhotoOnly: true,
      );

      expect(FeedFilter.fromJson(filter.toJson()), filter);
    });

    test('a filter written by an older build still opens', () {
      final restored = FeedFilter.fromJson({'sort': 'byVibes', 'age': 42});

      expect(restored, FeedFilter.initial);
    });
  });

  group('ReportLocalCache', () {
    test('keeps one account\'s list away from another\'s', () async {
      final cache = ReportLocalCache();
      await cache.write(ReportLocalCache.feedBucket, [_report], userId: '7');

      expect(cache.read(ReportLocalCache.feedBucket, userId: '7'), isNotNull);
      expect(cache.read(ReportLocalCache.feedBucket, userId: '9'), isNull);
      expect(cache.read(ReportLocalCache.feedBucket), isNull);
    });

    test('a guest copy carries no saves or votes', () async {
      final cache = ReportLocalCache();
      await cache.write(ReportLocalCache.feedBucket, [_report]);

      final cached = cache.read(ReportLocalCache.feedBucket)!;
      expect(cached.reports.single.isSaved, isFalse);
      expect(cached.reports.single.userVoteType, isNull);
      
      expect(cached.reports.single.upvoteCount, 4);
    });

    test('is bounded so it cannot grow without limit', () async {
      final cache = ReportLocalCache();
      final many = List.generate(
        ReportLocalCache.maxReports + 25,
        (i) => ReportModel(
          reportId: i,
          userId: 1,
          locationId: 1,
          title: 'Report $i',
          category: 'Flood',
        ),
      );

      await cache.write(ReportLocalCache.feedBucket, many, userId: '7');

      final cached = cache.read(ReportLocalCache.feedBucket, userId: '7')!;
      expect(cached.reports.length, ReportLocalCache.maxReports);
    });
  });
}

final _report = ReportModel(
  reportId: 1,
  userId: 7,
  locationId: 1,
  title: 'Waterlogging',
  category: 'Flood',
  isSaved: true,
  userVoteType: 'up',
  upvoteCount: 4,
);

class _ThrowingSignOut extends _OfflineRemote {
  @override
  Future<void> signOut() async => throw Exception('Storage unavailable');
}
