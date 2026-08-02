import '../../../../core/storage/local_store.dart';
import '../../domain/models/user_model.dart';

/// What the device remembers about the last sign-in.
class StoredSession {
  const StoredSession({
    required this.token,
    required this.user,
    required this.savedAt,
  });

  final String token;
  final UserModel user;

  /// When the profile was last confirmed with the backend. A stale one is still
  /// shown — the app opens on it and corrects it once the server answers.
  final DateTime savedAt;
}

/// The device's side of the session.
///
/// A token on its own is not enough to open the app as a signed-in person: the
/// name and avatar have to come from somewhere before the network answers. So
/// the profile is stored beside the token and the two are written, read and
/// erased together.
abstract class AuthLocalDataSource {
  /// The bearer token every authenticated request carries, or null for a guest.
  String? readToken();

  /// The full session, or null when there is no complete one on this device.
  StoredSession? readSession();

  Future<void> saveToken(String token);

  Future<void> saveUser(UserModel user);

  /// Ends the session and erases everything that belonged to that account.
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
    // An entry with no id came from a shape this build no longer understands.
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
    // Read the id before the profile goes, because it is the key to everything
    // else this account left behind — its feed, its saved posts, its reports.
    // Taken from the stored profile rather than [readSession] so a session that
    // has already lost its token still cleans up after itself.
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

  /// Written in the same shape the backend sends, so [UserModel.fromJson] reads
  /// it back without a second, divergent parser.
  ///
  /// The password is not in this map and never will be. [UserModel] carries the
  /// field because the sign-up form fills it in, but a credential has no reason
  /// to outlive the request it was typed for.
  Map<String, dynamic> _encode(UserModel user) => {
        'id': user.user_id,
        'email': user.email,
        'name': user.name,
        'imageUrl': user.image_url,
        'address': user.address,
      };
}
