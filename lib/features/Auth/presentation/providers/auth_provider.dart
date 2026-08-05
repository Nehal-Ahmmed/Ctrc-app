import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../data/datasources/auth_local_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/models/auth_form_model.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

final authLocalDataSourceProvider = Provider<AuthLocalDataSource>((ref) {
  return AuthLocalDataSourceImpl();
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(
    localDataSource: ref.watch(authLocalDataSourceProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(
    remoteDataSource: dataSource,
    localDataSource: ref.watch(authLocalDataSourceProvider),
  );
});

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;
  final bool isSubmitting;

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
        
        if (cached == null || failure is SessionExpiredFailure) {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            clearUser: true,
            isRevalidating: false,
            error: null,
          );
          return;
        }

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
    String? address,   
    String? image_url, 
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    final form = SignUpFormModel(
      name: name,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      address: address,   
      image_url: image_url, 
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
      address: address,   
      image_url: image_url, 
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

final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(
    authProvider.select(
      (state) =>
          state.status == AuthStatus.authenticated && state.user != null,
    ),
  ),
);

final authIdentityProvider = Provider<String?>(
  (ref) => ref.watch(authProvider.select((state) => state.user?.user_id)),
);
