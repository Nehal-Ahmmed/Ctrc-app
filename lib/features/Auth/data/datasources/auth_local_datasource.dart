import '../../../../core/storage/local_store.dart';
import '../../domain/models/user_model.dart';

class StoredSession {
  const StoredSession({
    required this.token,
    required this.user,
    required this.savedAt,
  });

  final String token;
  final UserModel user;

  final DateTime savedAt;
}

abstract class AuthLocalDataSource {
  
  String? readToken();

  StoredSession? readSession();

  Future<void> saveToken(String token);

  Future<void> saveUser(UserModel user);

  Future<void> clear();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  AuthLocalDataSourceImpl({LocalStore? store})
      : _store = store ?? LocalStore.instance;

  final LocalStore _store;

  @override
  String? readToken() {
    final token = _store.getString(StorageKeys.authToken);
    return (token == null || token.isEmpty) ? null : token;
  }

  @override
  StoredSession? readSession() {
    final token = readToken();
    if (token == null) return null;

    final stamped = _store.getStamped(StorageKeys.authUser);
    final data = stamped?.value;
    if (stamped == null || data is! Map) return null;

    final user = UserModel.fromJson(Map<String, dynamic>.from(data));
    
    if (user.user_id.isEmpty) return null;

    return StoredSession(token: token, user: user, savedAt: stamped.savedAt);
  }

  @override
  Future<void> saveToken(String token) =>
      _store.setString(StorageKeys.authToken, token);

  @override
  Future<void> saveUser(UserModel user) =>
      _store.setStamped(StorageKeys.authUser, _encode(user));

  @override
  Future<void> clear() async {
    
    final userId = _storedUserId();

    await _store.remove(StorageKeys.authToken);
    await _store.remove(StorageKeys.authUser);

    if (userId != null) {
      await _store.clearUserScope(userId);
    }
  }

  String? _storedUserId() {
    final data = _store.getStamped(StorageKeys.authUser)?.value;
    if (data is! Map) return null;

    final id = data['id']?.toString();
    return (id == null || id.isEmpty) ? null : id;
  }

  Map<String, dynamic> _encode(UserModel user) => {
        'id': user.user_id,
        'email': user.email,
        'name': user.name,
        'imageUrl': user.image_url,
        'address': user.address,
      };
}
