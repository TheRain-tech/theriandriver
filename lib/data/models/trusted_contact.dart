class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
  });

  final String id;
  final String name;
  final String phoneNumber;

  factory TrustedContact.fromJson(Map<String, dynamic> json) =>
      TrustedContact(
        id: json['id'] as String,
        name: json['name'] as String,
        phoneNumber: json['phoneNumber'] as String,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phoneNumber': phoneNumber,
  };
}
