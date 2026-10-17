class UserModel {
  final int? id;
  final String name;
  final String email;
  final String role;
  final bool passwordSetupRequired;
  final int? groupId;
  final String? groupName;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    this.role = 'teacher',
    this.passwordSetupRequired = false,
    this.groupId,
    this.groupName,
  });

  String get normalizedRole => role.trim().toLowerCase();
  bool get isAdmin => normalizedRole == 'admin';
  bool get isAttendant => normalizedRole == 'attendant';
  bool get isTeacher => !isAdmin && !isAttendant;
  String get roleLabel => isAdmin
      ? 'Administrador'
      : isAttendant
      ? 'Registrador de asistencia'
      : 'Docente';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int?,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? 'teacher').toString(),
      passwordSetupRequired:
          json['password_setup_required'] == true ||
          json['password_setup_required'] == 1 ||
          json['password_setup_required']?.toString() == '1',
      groupId: int.tryParse(json['group_id']?.toString() ?? ''),
      groupName: json['group_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'password_setup_required': passwordSetupRequired,
    };
  }
}
