class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final String? userId;
  final String username;
  final String fullName;
  final String roleName;
  final Set<String> permissions;

  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.userId,
    this.username = '',
    this.fullName = '',
    this.roleName = '',
    this.permissions = const {},
  });

  bool has(String permission) => permissions.contains(permission);

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    String? userId,
    String? username,
    String? fullName,
    String? roleName,
    Set<String>? permissions,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      roleName: roleName ?? this.roleName,
      permissions: permissions ?? this.permissions,
    );
  }

  static const initial = AuthState();
}
