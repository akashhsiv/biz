class AppUser {
  final String id;
  final String username;
  final String fullName;
  final String roleName;
  final String roleId;
  final bool isActive;

  AppUser({required this.id, required this.username, required this.fullName, required this.roleName, required this.roleId, required this.isActive});

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        username: json['username'] as String,
        fullName: json['fullName'] as String,
        roleName: json['roleName'] as String,
        roleId: json['roleId'] as String,
        isActive: json['isActive'] as bool,
      );
}

class AppRole {
  final String id;
  final String name;
  final bool isSystemRole;
  final List<String> permissions;

  AppRole({required this.id, required this.name, required this.isSystemRole, required this.permissions});

  factory AppRole.fromJson(Map<String, dynamic> json) => AppRole(
        id: json['id'] as String,
        name: json['name'] as String,
        isSystemRole: json['isSystemRole'] as bool,
        permissions: List<String>.from(json['permissions'] as List),
      );
}

class AppPermission {
  final String key;
  final String module;
  final String? description;

  AppPermission({required this.key, required this.module, this.description});

  factory AppPermission.fromJson(Map<String, dynamic> json) => AppPermission(
        key: json['key'] as String,
        module: json['module'] as String,
        description: json['description'] as String?,
      );
}
