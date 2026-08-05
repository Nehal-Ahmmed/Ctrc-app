class UserModel {
  final String user_id;
  final String email;
  final String name;
  final String password;
  final String? image_url; 
  final String? address;   

  const UserModel({
    required this.user_id,
    required this.email,
    required this.name,
    this.image_url,
    this.address,    
    required this.password,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      user_id: json['id']?.toString() ?? '', 
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      image_url: json['imageUrl'] as String?, 
      address: json['address'] as String?,
      password: json['password'] as String? ?? '', 
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
