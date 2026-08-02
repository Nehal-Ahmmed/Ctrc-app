import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/models/auth_form_model.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

/// The session as it exists on this device.
final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl();
});

// Data source provider (replace with actual implementation later)
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(
    localDataSource: ref.watch(authLocalDataSourceProvider),
  );
});

// Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(
    remoteDataSource: dataSource,
    localDataSource: ref.watch(authLocalDataSourceProvider),
  );
});

// Auth state
enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;
  final bool isSubmitting;

  /// The session came off the device and the backend has not confirmed it yet.
  /// The user is fully signed in meanwhile — this only marks that the profile
  /// on screen is the stored one.
  final bool isRevalidating;

  const AuthState({
    this.status = AuthStatus.uninitialized,
    this.user,
    this.error,
    this.isSubmitting = false,
    this.isRevalidating = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    // `user: null` cannot express "there is nobody signed in" because null also
    // means "leave unchanged", so signing out sets this flag instead.
    bool clearUser = false,
    String? error,
    bool? isSubmitting,
    bool? isRevalidating,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      error: error,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isRevalidating: isRevalidating ?? this.isRevalidating,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthState()) {
    _init();
  }

  /// Restores the session in two steps.
  ///
  /// The device already knows who was signed in last, so the app opens as that
  /// person immediately — no spinner, no signed-out flash, and no waiting on a
  /// backend that may be asleep. The server is then asked to confirm, and only
  /// an outright rejection ends the session. A phone with no signal keeps what
  /// it had, which is the whole point of storing it.
  Future<void> _init() async {
    final cached = _authRepository.cachedUser();

    state = cached != null
        ? state.copyWith(
            status: AuthStatus.authenticated,
            user: cached,
            isRevalidating: true,
          )
        : state.copyWith(status: AuthStatus.loading);

    final result = await _authRepository.getCurrentUser();

    result.fold(
      (failure) {
        // Either the token was refused, or there was never a session to
        // restore. Both mean nobody is signed in.
        if (cached == null || failure is SessionExpiredFailure) {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            clearUser: true,
            isRevalidating: false,
            error: null,
          );
          return;
        }

        // Unreachable, not rejected. Stay signed in on what was stored.
        state = state.copyWith(isRevalidating: false, error: null);
      },
      (user) => state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        isRevalidating: false,
        error: null,
      ),
    );
  }

  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    final form = SignInFormModel(email: email, password: password);
    final validationErrors = form.validateAll();
    final errorMessages = validationErrors.values
        .where((e) => e != null)
        .toList();
    if (errorMessages.isNotEmpty) {
      state = state.copyWith(
        isSubmitting: false,
        error: errorMessages.join('\n'),
      );
      return errorMessages.join('\n');
    }

    final result = await _authRepository.signIn(
      email: email,
      password: password,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isSubmitting: false, error: failure.message);
        return failure.message;
      },
      (user) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isSubmitting: false,
          error: null,
        );
        return null;
      },
    );
  }

  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    required String confirmPassword,
    String? address,   // Optional — null by default
    String? image_url, // Optional — null by default
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    final form = SignUpFormModel(
      name: name,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      address: address,   // nullable — no longer required
      image_url: image_url, // nullable — no longer required
    );
    final validationErrors = form.validateAll();
    final errorMessages = validationErrors.values
        .where((e) => e != null)
        .toList();
    if (errorMessages.isNotEmpty) {
      state = state.copyWith(
        isSubmitting: false,
        error: errorMessages.join('\n'),
      );
      return errorMessages.join('\n');
    }

    final result = await _authRepository.signUp(
      email: email,
      password: password,
      name: name,
      address: address,   // null if not provided
      image_url: image_url, // null if not provided
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isSubmitting: false, error: failure.message);
        return failure.message;
      },
      (user) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          isSubmitting: false,
          error: null,
        );
        return null;
      },
    );
  }

  Future<void> signOut() async {
    state = state.copyWith(isSubmitting: true);

    // The token only lives on this device, so failing to erase it is no reason
    // to keep the session on screen. Either way the app drops to the guest
    // state — a sign-out that half-worked is worse than one that fully did.
    await _authRepository.signOut();

    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      clearUser: true,
      isSubmitting: false,
      error: null,
    );
  }

  Future<String?> updateProfile({
    required String name,
    String? address,
    String? imageUrl,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    final result = await _authRepository.updateProfile(
      name: name,
      address: address,
      image_url: imageUrl,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isSubmitting: false, error: failure.message);
        return failure.message;
      },
      (user) {
        state = state.copyWith(
          user: user,
          isSubmitting: false,
          error: null,
        );
        return null;
      },
    );
  }

  Future<String?> uploadAvatar(String filePath) async {
    state = state.copyWith(isSubmitting: true, error: null);

    final result = await _authRepository.uploadAvatar(filePath);

    return result.fold(
      (failure) {
        state = state.copyWith(isSubmitting: false, error: failure.message);
        return failure.message;
      },
      (user) {
        state = state.copyWith(
          user: user,
          isSubmitting: false,
          error: null,
        );
        return null;
      },
    );
  }

  /// Returns null on success, or a message describing why it failed.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    final result = await _authRepository.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isSubmitting: false, error: failure.message);
        return failure.message;
      },
      (_) {
        state = state.copyWith(isSubmitting: false, error: null);
        return null;
      },
    );
  }

  /// Kicks off a password reset for [email].
  Future<String?> requestPasswordReset(String email) async {
    state = state.copyWith(isSubmitting: true, error: null);

    final result = await _authRepository.resetPassword(email);

    return result.fold(
      (failure) {
        state = state.copyWith(isSubmitting: false, error: failure.message);
        return failure.message;
      },
      (_) {
        state = state.copyWith(isSubmitting: false, error: null);
        return null;
      },
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthNotifier(repository);
});

/// Whether somebody is signed in. The one thing auth-gated UI should ask.
final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(
    authProvider.select(
      (state) =>
          state.status == AuthStatus.authenticated && state.user != null,
    ),
  ),
);

/// Id of the signed-in user, or null while browsing as a guest.
///
/// Pages that cache per-user data — saved flags, vote state, "my reports" —
/// watch this and drop what they are holding the moment it changes, so one
/// account's state never renders under another's, or under no account at all.
final authIdentityProvider = Provider<String?>(
  (ref) => ref.watch(authProvider.select((state) => state.user?.user_id)),
);
