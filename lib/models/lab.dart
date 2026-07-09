class Lab {
  final String? id;
  final String? profileId;
  final String? title;
  final String? photo;
  final List<String>? tests;
  final dynamic testFee;
  final String? address;
  final String? delivery;
  final dynamic rating;

  const Lab({
    this.id,
    this.profileId,
    this.title,
    this.photo,
    this.tests,
    this.testFee,
    this.address,
    this.delivery,
    this.rating,
  });

  factory Lab.fromJson(Map<String, dynamic> json) {
    return Lab(
      id: json['id']?.toString(),
      profileId: json['profileId']?.toString(),
      title: json['title'],
      photo: json['photo'],
      tests: json['tests'] != null ? List<String>.from(json['tests']) : null,
      testFee: json['testFee'] ?? json['appointmentFee'],
      address: json['address'],
      delivery: json['delivery'],
      rating: json['rating'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'title': title,
      'photo': photo,
      'tests': tests,
      'testFee': testFee,
      'address': address,
      'delivery': delivery,
      'rating': rating,
    };
  }
}
