class User {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String role;
  final String? profilePicture;
  final DateTime? createdAt;
  final String? gender;
  final String? age;
  final String? mrNumber; // Auto-generated Medical Record Number (patients only)
  final String? cnic;
  final String? specialization;
  final List<String>? conditionsTreated;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.role,
    this.profilePicture,
    this.createdAt,
    this.gender,
    this.age,
    this.mrNumber,
    this.cnic,
    this.specialization,
    this.conditionsTreated,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phoneNumber: (json['phoneNumber'] ?? json['phone'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      profilePicture: (json['profilePicture'] ?? json['profile_picture'] ?? json['image'] ?? json['avatar'] ?? json['photo'])?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      gender: json['gender']?.toString(),
      age: json['age']?.toString(),
      mrNumber: json['mrNumber']?.toString(),
      cnic: (json['cnic'] ?? json['idCard'] ?? json['id_card'])?.toString(),
      specialization: json['specialization']?.toString(),
      conditionsTreated: (json['conditionsTreated'] as List?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role,
      'profilePicture': profilePicture,
      'createdAt': createdAt?.toIso8601String(),
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
      if (mrNumber != null) 'mrNumber': mrNumber,
      if (cnic != null) 'cnic': cnic,
      if (specialization != null) 'specialization': specialization,
      if (conditionsTreated != null) 'conditionsTreated': conditionsTreated,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? role,
    String? profilePicture,
    DateTime? createdAt,
    String? gender,
    String? age,
    String? mrNumber,
    String? cnic,
    String? specialization,
    List<String>? conditionsTreated,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      profilePicture: profilePicture ?? this.profilePicture,
      createdAt: createdAt ?? this.createdAt,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      mrNumber: mrNumber ?? this.mrNumber,
      cnic: cnic ?? this.cnic,
      specialization: specialization ?? this.specialization,
      conditionsTreated: conditionsTreated ?? this.conditionsTreated,
    );
  }
}
