class SignInFormModel {
  final String email;
  final String password;

  const SignInFormModel({required this.email, required this.password});

  String? validateEmail() {
    if (email.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) return 'Invalid email format';
    return null;
  }

  String? validatePassword() {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Map<String, String?> validateAll() {
    return {'email': validateEmail(), 'password': validatePassword()};
  }

  bool get isValid => validateAll().values.every((e) => e == null);
}

class SignUpFormModel {
  final String name;
  final String email;
  final String password;
  final String confirmPassword;
  final String? address;   // Optional — null if not provided
  final String? image_url; // Optional — null if not provided

  const SignUpFormModel({
    required this.name,
    required this.email,
    required this.password,
    required this.confirmPassword,
    this.address,   // nullable
    this.image_url, // nullable
  });

  String? validateName() {
    if (name.isEmpty) return 'Name is required';
    if (name.length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? validateEmail() {
    if (email.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) return 'Invalid email format';
    return null;
  }

  String? validatePassword() {
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? validateConfirmPassword() {
    if (confirmPassword.isEmpty) return 'Please confirm your password';
    if (password != confirmPassword) return 'Passwords do not match';
    return null;
  }

  // address and image_url are optional — no validation required

  Map<String, String?> validateAll() {
    return {
      'name': validateName(),
      'email': validateEmail(),
      'password': validatePassword(),
      'confirmPassword': validateConfirmPassword(),
      // address and image_url are optional; excluded from required validation
    };
  }

  bool get isValid => validateAll().values.every((e) => e == null);
}
