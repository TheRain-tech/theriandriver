class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.phoneNumber,
    required this.displayName,
    this.isMock = false,
  });

  final String uid;
  final String email;
  final String phoneNumber;
  final String displayName;
  final bool isMock;
}
