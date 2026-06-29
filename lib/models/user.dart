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
  final String? mrNumber;
  final String? cnic;
  final String? specialization;
  final List<String>? conditionsTreated;
  final List<Map<String, String>>? emergencyContacts;
  final bool isPhoneVerified;
  final bool isEmailVerified;

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
    this.emergencyContacts,
    this.isPhoneVerified = true,
    this.isEmailVerified = true,
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
      emergencyContacts: (json['emergencyContacts'] as List?)
          ?.map((e) => Map<String, String>.from(
              (e as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))))
          .toList(),
      // Old accounts without these fields default to true (grandfathered)
      isPhoneVerified: json['isPhoneVerified'] as bool? ?? true,
      isEmailVerified: json['isEmailVerified'] as bool? ?? true,
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
      if (emergencyContacts != null) 'emergencyContacts': emergencyContacts,
      'isPhoneVerified': isPhoneVerified,
      'isEmailVerified': isEmailVerified,
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
    List<Map<String, String>>? emergencyContacts,
    bool? isPhoneVerified,
    bool? isEmailVerified,
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
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }
}
