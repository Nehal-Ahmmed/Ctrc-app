class UserModel {
  final String user_id;
  final String email;
  final String name;
  final String password;
  final String? image_url; // Optional — null if not provided at signup
  final String? address;   // Optional — null if not provided at signup

  const UserModel({
    required this.user_id,
    required this.email,
    required this.name,
    this.image_url,
    this.address,    // nullable
    required this.password,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      user_id: json['user_id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      image_url: json['image_url'] as String?,
      address: json['address'] as String?,   // nullable
      password: json['password'] as String? ?? '', // password won't be in response
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': user_id,
      'email': email,
      'name': name,
      'image_url': image_url,
      'address': address,
      'password': password,
    };
  }

  UserModel copyWith({
    String? user_id,
    String? email,
    String? name,
    String? image_url,
    String? address,
    String? password,
  }) {
    return UserModel(
      user_id: user_id ?? this.user_id,
      email: email ?? this.email,
      name: name ?? this.name,
      image_url: image_url ?? this.image_url,
      address: address ?? this.address,
      password: password ?? this.password,
    );
  }
}
