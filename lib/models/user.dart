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
  final String? bloodGroup;
  final String? existingConditions;
  final String? healthGoals;
  final String? address;
  final String? height;
  final String? weight;

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
    this.bloodGroup,
    this.existingConditions,
    this.healthGoals,
    this.address,
    this.height,
    this.weight,
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
      isPhoneVerified: json['isPhoneVerified'] as bool? ?? true,
      isEmailVerified: json['isEmailVerified'] as bool? ?? true,
      bloodGroup: (json['bloodGroup'] ?? json['blood_group'])?.toString(),
      existingConditions: (json['existingConditions'] ?? json['existing_conditions'])?.toString(),
      healthGoals: (json['healthGoals'] ?? json['health_goals'])?.toString(),
      address: json['address']?.toString(),
      height: json['height']?.toString(),
      weight: json['weight']?.toString(),
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
      if (bloodGroup != null) 'bloodGroup': bloodGroup,
      if (existingConditions != null) 'existingConditions': existingConditions,
      if (healthGoals != null) 'healthGoals': healthGoals,
      if (address != null) 'address': address,
      if (height != null) 'height': height,
      if (weight != null) 'weight': weight,
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
    String? bloodGroup,
    String? existingConditions,
    String? healthGoals,
    String? address,
    String? height,
    String? weight,
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
      bloodGroup: bloodGroup ?? this.bloodGroup,
      existingConditions: existingConditions ?? this.existingConditions,
      healthGoals: healthGoals ?? this.healthGoals,
      address: address ?? this.address,
      height: height ?? this.height,
      weight: weight ?? this.weight,
    );
  }
}
