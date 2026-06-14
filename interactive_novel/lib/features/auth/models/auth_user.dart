class AuthUser {
  final String id;
  final String email;
  final String username;
  final String role;
  final bool isVerified;
  final String? displayName;
  final String? avatarUrl;
  final bool totpEnabled;

  AuthUser({
    required this.id,
    required this.email,
    required this.username,
    required this.role,
    required this.isVerified,
    this.displayName,
    this.avatarUrl,
    this.totpEnabled = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'].toString(),
        email: json['email'] as String,
        username: json['username'] as String,
        role: (json['role'] ?? 'user') as String,
        isVerified: (json['is_verified'] ?? false) as bool,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        totpEnabled: (json['totp_enabled'] ?? false) as bool,
      );
}
