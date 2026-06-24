import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/models/auth_form_model.dart';
import '../../domain/models/user_model.dart';
import '../../domain/repositories/auth_repository.dart';

// Data source provider (replace with actual implementation later)
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl();
});

// Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(remoteDataSource: dataSource);
});

// Auth state
enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;
  final bool isSubmitting;

  const AuthState({
    this.status = AuthStatus.uninitialized,
    this.user,
    this.error,
    this.isSubmitting = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
    bool? isSubmitting,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(status: AuthStatus.loading);
    final result = await _authRepository.getCurrentUser();
    result.fold(
      (failure) => state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: null,
      ),
      (user) =>
          state = state.copyWith(status: AuthStatus.authenticated, user: user),
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
    final result = await _authRepository.signOut();
    result.fold(
      (failure) =>
          state = state.copyWith(isSubmitting: false, error: failure.message),
      (_) => state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        isSubmitting: false,
        error: null,
      ),
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
