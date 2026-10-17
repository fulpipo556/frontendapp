import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

class ActivityItem {
  final int id;
  final String activity;
  final String title;
  final String type;
  final String date;
  final String time;
  final String endTime;
  final String responsible;
  final String place;
  final String modality;
  final String fileName;
  final String filePath;
  final List<String> speakers;

  ActivityItem({
    required this.id,
    required this.activity,
    this.title = '',
    this.type = '',
    required this.date,
    required this.time,
    required this.endTime,
    this.responsible = '',
    this.place = '',
    required this.modality,
    required this.fileName,
    required this.filePath,
    this.speakers = const [],
  });

  String get timeLabel => endTime.isEmpty ? time : '$time–$endTime';

  String get displayDate {
    final datePart = date.split('T').first;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(datePart);
    if (match == null) return datePart;
    return '${match.group(3)}/${match.group(2)}/${match.group(1)}';
  }

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    final time = json['time']?.toString() ?? '';
    final speakerValue = json['speakers']?.toString() ?? '';
    return ActivityItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      activity: json['activity']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type_name']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      time: time.length >= 5 ? time.substring(0, 5) : time,
      endTime: (json['time_end']?.toString() ?? '').length >= 5
          ? json['time_end'].toString().substring(0, 5)
          : json['time_end']?.toString() ?? '',
      responsible: json['responsible']?.toString() ?? '',
      place: json['place']?.toString() ?? '',
      modality: json['modality']?.toString() ?? '',
      fileName: json['file_name']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      speakers: speakerValue
          .split(',')
          .map((speaker) => speaker.trim())
          .where((speaker) => speaker.isNotEmpty)
          .toList(),
    );
  }
}

class ContentSection {
  const ContentSection({
    required this.id,
    required this.title,
    required this.body,
    required this.imagePath,
    required this.videoPath,
    required this.videoUrl,
    this.displayOrder = 0,
  });

  final int id;
  final String title;
  final String body;
  final String imagePath;
  final String videoPath;
  final String videoUrl;
  final int displayOrder;

  String get imageLink => AuthService.uploadUrl(imagePath);
  String get videoLink =>
      videoUrl.isNotEmpty ? videoUrl : AuthService.uploadUrl(videoPath);

  factory ContentSection.fromJson(Map<String, dynamic> json) => ContentSection(
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    title: json['title']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    imagePath: json['imagePath']?.toString() ?? '',
    videoPath: json['videoPath']?.toString() ?? '',
    videoUrl: json['videoUrl']?.toString() ?? '',
    displayOrder: int.tryParse(json['displayOrder']?.toString() ?? '') ?? 0,
  );
}

class WorkshopDayTime {
  final String date;
  final String startTime;
  final String endTime;

  const WorkshopDayTime({
    required this.date,
    required this.startTime,
    required this.endTime,
  });

  Map<String, String> toJson() => {
    'date': date,
    'startTime': startTime,
    'endTime': endTime,
  };

  String get displayDate {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
    return match == null
        ? 'sin fecha'
        : '${match.group(3)}/${match.group(2)}/${match.group(1)}';
  }
}

class WorkshopItem {
  final int id;
  final String title;
  final int capacity;
  final String address;
  final String room;
  final List<WorkshopDayTime> dayTimes;
  final int? rotationDay;
  final List<UserModel> teachers;

  String dayLabel(int day) => day < 0 || day >= dayTimes.length
      ? 'Sin horario'
      : '${dayTimes[day].displayDate} ${dayTimes[day].startTime} - ${dayTimes[day].endTime}';

  const WorkshopItem({
    required this.id,
    required this.title,
    required this.capacity,
    this.address = '',
    this.room = '',
    this.dayTimes = const [],
    this.rotationDay,
    required this.teachers,
  });

  factory WorkshopItem.fromJson(Map<String, dynamic> json) {
    final teacherValues = json['teachers'] as List<dynamic>? ?? const [];
    return WorkshopItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? '',
      capacity: int.tryParse(json['capacity']?.toString() ?? '') ?? 0,
      address: json['address']?.toString() ?? '',
      room: json['room']?.toString() ?? '',
      rotationDay: int.tryParse(json['rotationDay']?.toString() ?? ''),
      dayTimes: (json['dayTimes'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => WorkshopDayTime(
              date: item['date']?.toString() ?? '',
              startTime: item['startTime']?.toString() ?? '',
              endTime: item['endTime']?.toString() ?? '',
            ),
          )
          .toList(),
      teachers: teacherValues
          .whereType<Map<String, dynamic>>()
          .map(UserModel.fromJson)
          .toList(),
    );
  }
}

class WorkshopGroup {
  final int id;
  final String name;
  final int memberCount;

  const WorkshopGroup({
    required this.id,
    required this.name,
    required this.memberCount,
  });

  factory WorkshopGroup.fromJson(Map<String, dynamic> json) {
    return WorkshopGroup(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      memberCount: int.tryParse(json['member_count']?.toString() ?? '') ?? 0,
    );
  }
}

class WorkshopRotationAssignment {
  final String date;
  final int groupId;
  final String groupName;
  final int memberCount;
  final int workshopId;
  final String workshopTitle;
  final int capacity;
  final List<UserModel> teachers;

  const WorkshopRotationAssignment({
    required this.date,
    required this.groupId,
    required this.groupName,
    required this.memberCount,
    required this.workshopId,
    required this.workshopTitle,
    required this.capacity,
    required this.teachers,
  });

  String get displayDate {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(date);
    if (match == null) return date;
    return '${match.group(3)}/${match.group(2)}/${match.group(1)}';
  }

  factory WorkshopRotationAssignment.fromJson(Map<String, dynamic> json) {
    final teacherValues = json['teachers'] as List<dynamic>? ?? const [];
    return WorkshopRotationAssignment(
      date: json['date']?.toString() ?? '',
      groupId: int.tryParse(json['groupId']?.toString() ?? '') ?? 0,
      groupName: json['groupName']?.toString() ?? '',
      memberCount: int.tryParse(json['memberCount']?.toString() ?? '') ?? 0,
      workshopId: int.tryParse(json['workshopId']?.toString() ?? '') ?? 0,
      workshopTitle: json['workshopTitle']?.toString() ?? '',
      capacity: int.tryParse(json['capacity']?.toString() ?? '') ?? 0,
      teachers: teacherValues
          .whereType<Map<String, dynamic>>()
          .map(UserModel.fromJson)
          .toList(),
    );
  }
}

class WorkshopRotationSelection {
  final int groupId;
  final int workshopId;
  final int dayIndex;

  const WorkshopRotationSelection({
    required this.groupId,
    required this.workshopId,
    required this.dayIndex,
  });
}

class WordDocumentBlock {
  final String type;
  final String text;
  final List<List<String>> rows;

  const WordDocumentBlock({
    required this.type,
    this.text = '',
    this.rows = const [],
  });

  factory WordDocumentBlock.fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] as List<dynamic>? ?? const [])
        .whereType<List<dynamic>>()
        .map((row) => row.map((cell) => cell?.toString() ?? '').toList())
        .toList();
    return WordDocumentBlock(
      type: json['type']?.toString() ?? 'paragraph',
      text: json['text']?.toString() ?? '',
      rows: rows,
    );
  }
}

class AuthResponse {
  final bool success;
  final String message;
  final UserModel? user;
  final String? token;

  AuthResponse({
    required this.success,
    required this.message,
    this.user,
    this.token,
  });
}

class AdminUserImportResult {
  final String message;
  final int created;
  final int updated;
  final int alreadyRegistered;
  final int failed;
  final List<Map<String, dynamic>> results;

  const AdminUserImportResult({
    required this.message,
    required this.created,
    required this.updated,
    required this.alreadyRegistered,
    required this.failed,
    required this.results,
  });

  List<Map<String, dynamic>> get rowErrors =>
      results.where((row) => row['status'] == 'error').toList();

  List<Map<String, dynamic>> get updatedRows =>
      results.where((row) => row['status'] == 'updated').toList();

  List<Map<String, dynamic>> get alreadyRegisteredRows =>
      results.where((row) => row['status'] == 'already_registered').toList();
}

class AdminInvitationResult {
  final String message;
  final int sent;
  final int failed;
  final List<Map<String, dynamic>> errors;

  const AdminInvitationResult({
    required this.message,
    required this.sent,
    required this.failed,
    required this.errors,
  });
}

class SpeakerItem {
  final int id;
  final String name;
  final String photoPath;
  final String cvFileName;
  final String cvFilePath;
  final int cvWordCount;
  final int activityCount;

  const SpeakerItem({
    required this.id,
    required this.name,
    this.photoPath = '',
    this.cvFileName = '',
    this.cvFilePath = '',
    this.cvWordCount = 0,
    this.activityCount = 0,
  });

  bool get hasCv => cvFileName.isNotEmpty;

  String get photoUrl => AuthService.uploadUrl(photoPath);

  String get cvUrl => AuthService.uploadUrl(cvFilePath);

  factory SpeakerItem.fromJson(Map<String, dynamic> json) {
    return SpeakerItem(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      photoPath: json['photoPath']?.toString() ?? '',
      cvFileName: json['cvFileName']?.toString() ?? '',
      cvFilePath: json['cvFilePath']?.toString() ?? '',
      cvWordCount: int.tryParse(json['cvWordCount']?.toString() ?? '') ?? 0,
      activityCount: int.tryParse(json['activityCount']?.toString() ?? '') ?? 0,
    );
  }
}

class SpeakerList {
  final int minCvWords;
  final List<SpeakerItem> speakers;

  const SpeakerList({required this.minCvWords, required this.speakers});
}

class AttendanceScanResult {
  const AttendanceScanResult({
    required this.alreadyRegistered,
    required this.name,
    required this.email,
  });

  final bool alreadyRegistered;
  final String name;
  final String email;
}

class AttendanceDay {
  const AttendanceDay({
    required this.date,
    required this.today,
    required this.days,
    required this.totalTeachers,
    required this.rows,
    required this.schedules,
  });

  final String date;
  final String today;
  final List<String> days;
  final int totalTeachers;
  final List<AttendanceRow> rows;
  final List<AttendanceSchedule> schedules;
}

class AttendanceSchedule {
  const AttendanceSchedule({
    required this.attendanceStart,
    required this.attendanceEnd,
    required this.breakStart,
    required this.breakEnd,
    this.attendanceEnabled = true,
    this.breakEnabled = true,
  });

  final String attendanceStart;
  final String attendanceEnd;
  final String breakStart;
  final String breakEnd;
  final bool attendanceEnabled;
  final bool breakEnabled;

  @override
  bool operator ==(Object other) =>
      other is AttendanceSchedule &&
      attendanceStart == other.attendanceStart &&
      attendanceEnd == other.attendanceEnd &&
      breakStart == other.breakStart &&
      breakEnd == other.breakEnd &&
      attendanceEnabled == other.attendanceEnabled &&
      breakEnabled == other.breakEnabled;

  @override
  int get hashCode => Object.hash(
    attendanceStart,
    attendanceEnd,
    breakStart,
    breakEnd,
    attendanceEnabled,
    breakEnabled,
  );
}

class AttendanceRow {
  const AttendanceRow({
    required this.id,
    required this.name,
    required this.email,
    this.attendanceTime,
    this.breakTime,
  });

  final int id;
  final String name;
  final String email;
  final String? attendanceTime;
  final String? breakTime;
}

class AuthService {
  static const String _baseUrl = kIsWeb
      ? String.fromEnvironment(
          'API_URL',
          defaultValue: 'https://appbackend-production-de33.up.railway.app/api',
        )
      : String.fromEnvironment(
          'API_URL',
          defaultValue: 'https://appbackend-production-de33.up.railway.app/api',
        );

  static String uploadUrl(String storedPath) {
    if (storedPath.isEmpty) return '';
    if (Uri.tryParse(storedPath)?.hasScheme ?? false) return storedPath;
    return '${_baseUrl.substring(0, _baseUrl.length - '/api'.length)}'
        '$storedPath';
  }

  static Map<String, String> _authorizationHeaders(
    String token, {
    bool json = false,
  }) {
    return {
      'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
    };
  }

  static Future<AuthResponse> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('user', jsonEncode(data['user']));

      return AuthResponse(
        success: true,
        message: data['message'] ?? 'Login exitoso',
        user: UserModel.fromJson(data['user']),
        token: data['token'],
      );
    }

    return AuthResponse(
      success: false,
      message: data['message'] ?? 'Error al iniciar sesión',
    );
  }

  static Future<String> requestPasswordReset(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo enviar el correo');
    }
    return data['message']?.toString() ?? 'Revisa tu correo electrónico';
  }

  static Future<AuthResponse> register(
    String name,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 202) {
      return AuthResponse(
        success: true,
        message: data['message'] ?? 'Revisa tu correo para verificar tu cuenta',
      );
    }

    if (response.statusCode == 201 && data['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('user', jsonEncode(data['user']));

      return AuthResponse(
        success: true,
        message: data['message'] ?? 'Usuario registrado',
        user: UserModel.fromJson(data['user']),
        token: data['token'],
      );
    }

    return AuthResponse(
      success: false,
      message: data['message'] ?? 'Error al registrar usuario',
    );
  }

  static Future<AuthResponse> verifyEmail(String email, String code) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/verify-email'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );

    final data = jsonDecode(response.body);
    return AuthResponse(
      success: response.statusCode == 200,
      message: data['message'] ?? 'No se pudo verificar el correo',
    );
  }

  static Future<List<UserModel>> getAdminUsers() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para consultar usuarios');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/admin/users'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(
        data['message'] ?? 'No se pudo cargar la lista de usuarios',
      );
    }

    return (data['users'] as List<dynamic>)
        .map((user) => UserModel.fromJson(user as Map<String, dynamic>))
        .toList();
  }

  static Future<void> assignUserToGroup({
    required int userId,
    required String groupName,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para cambiar el grupo');
    }
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/users/$userId/group'),
      headers: _authorizationHeaders(token, json: true),
      body: jsonEncode({'groupName': groupName}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo cambiar el grupo');
    }
  }

  static Future<String> getLiveQrCode() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para generar tu QR');
    }
    final response = await http.get(
      Uri.parse('$_baseUrl/my/qr'),
      headers: _authorizationHeaders(token),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo generar el QR');
    }
    return data['code'] as String;
  }

  static Future<List<WorkshopItem>> getMyWorkshops() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para consultar tus talleres');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/my/workshops'),
      headers: _authorizationHeaders(token),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudieron cargar tus talleres');
    }
    return (data['workshops'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WorkshopItem.fromJson)
        .toList();
  }

  static Future<List<WorkshopItem>> getAdminWorkshops() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para consultar los talleres');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/admin/workshops'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudieron cargar los talleres');
    }
    return (data['workshops'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WorkshopItem.fromJson)
        .toList();
  }

  static Future<void> createWorkshop({
    required String title,
    required int capacity,
    required String address,
    required String room,
    required List<WorkshopDayTime> dayTimes,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para crear talleres');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/admin/workshops'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'capacity': capacity,
        'address': address,
        'room': room,
        'dayTimes': dayTimes.map((item) => item.toJson()).toList(),
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'No se pudo crear el taller');
    }
  }

  static Future<void> updateWorkshop({
    required int id,
    required String title,
    required int capacity,
    required String address,
    required String room,
    required List<WorkshopDayTime> dayTimes,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para actualizar talleres');
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/admin/workshops/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'capacity': capacity,
        'address': address,
        'room': room,
        'dayTimes': dayTimes.map((item) => item.toJson()).toList(),
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo actualizar el taller');
    }
  }

  static Future<void> deleteWorkshop(int id) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para eliminar talleres');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/workshops/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo eliminar el taller');
    }
  }

  static Future<void> assignWorkshopTeachers({
    required int workshopId,
    required List<int> teacherIds,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para asignar docentes');
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/admin/workshops/$workshopId/teachers'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'teacherIds': teacherIds}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudieron asignar los docentes');
    }
  }

  static Future<List<WorkshopGroup>> getAdminWorkshopGroups() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para consultar los grupos');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/admin/workshop-groups'),
      headers: _authorizationHeaders(token),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudieron cargar los grupos');
    }
    return (data['groups'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WorkshopGroup.fromJson)
        .toList();
  }

  static Future<void> saveAdminWorkshopGroup({
    int? id,
    required String name,
    required int memberCount,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para guardar grupos');
    }

    final response = id == null
        ? await http.post(
            Uri.parse('$_baseUrl/admin/workshop-groups'),
            headers: _authorizationHeaders(token, json: true),
            body: jsonEncode({'name': name, 'memberCount': memberCount}),
          )
        : await http.put(
            Uri.parse('$_baseUrl/admin/workshop-groups/$id'),
            headers: {
              'Authorization': '******',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'name': name, 'memberCount': memberCount}),
          );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final expectedStatus = id == null ? 201 : 200;
    if (response.statusCode != expectedStatus) {
      throw Exception(data['message'] ?? 'No se pudo guardar el grupo');
    }
  }

  static Future<void> deleteAdminWorkshopGroup(int id) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para eliminar grupos');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/workshop-groups/$id'),
      headers: _authorizationHeaders(token),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo eliminar el grupo');
    }
  }

  static Future<List<WorkshopRotationAssignment>>
  getAdminWorkshopRotation() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para consultar la rotación');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/admin/workshop-rotation'),
      headers: _authorizationHeaders(token),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo cargar la rotación');
    }
    return (data['assignments'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(WorkshopRotationAssignment.fromJson)
        .toList();
  }

  static Future<void> saveAdminWorkshopRotation({
    required DateTime startDate,
    required List<WorkshopRotationSelection> selections,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para guardar la programación');
    }

    final date =
        '${startDate.year.toString().padLeft(4, '0')}-'
        '${startDate.month.toString().padLeft(2, '0')}-'
        '${startDate.day.toString().padLeft(2, '0')}';
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/workshop-rotation'),
      headers: _authorizationHeaders(token, json: true),
      body: jsonEncode({
        'startDate': date,
        'assignments': selections
            .map(
              (selection) => {
                'groupId': selection.groupId,
                'workshopId': selection.workshopId,
                'dayIndex': selection.dayIndex,
              },
            )
            .toList(),
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo guardar la programación');
    }
  }

  static Future<void> createAdminUser({
    required String name,
    required String email,
    String role = 'teacher',
    String password = '',
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para crear usuarios');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/admin/users'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'role': role,
        if (password.isNotEmpty) 'password': password,
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 201) {
      throw Exception(data['message'] ?? 'No se pudo crear el usuario');
    }
  }

  static Future<AttendanceScanResult> registerAttendance({
    required String kind,
    required String code,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para registrar asistencia');
    }
    final response = await http.post(
      Uri.parse('$_baseUrl/attendance/scan'),
      headers: _authorizationHeaders(token, json: true),
      body: jsonEncode({'kind': kind, 'code': code}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 401) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');
      throw Exception(
        'La sesión del registrador expiró o ya no es válida. Inicia sesión nuevamente.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo registrar');
    }
    final user = data['user'] as Map<String, dynamic>? ?? const {};
    return AttendanceScanResult(
      alreadyRegistered: data['status'] == 'duplicate',
      name: (user['name'] ?? '').toString(),
      email: (user['email'] ?? '').toString(),
    );
  }

  static Future<void> removeAttendance({
    required int userId,
    required String kind,
    required String date,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para quitar asistencia');
    }
    final response = await http.delete(
      Uri.parse('$_baseUrl/attendance'),
      headers: _authorizationHeaders(token, json: true),
      body: jsonEncode({'userId': userId, 'kind': kind, 'date': date}),
    );
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(data['message'] ?? 'No se pudo quitar el registro');
    }
  }

  static Future<AttendanceDay> getAttendanceDay([String? date]) async {
    return _getAttendanceDay(
      Uri.parse('$_baseUrl/attendance/day${date == null ? '' : '?date=$date'}'),
    );
  }

  static Future<AttendanceDay> getAdminAttendanceDay([String? date]) async {
    return _getAttendanceDay(
      Uri.parse(
        '$_baseUrl/admin/attendance/day${date == null ? '' : '?date=$date'}',
      ),
    );
  }

  static Future<AttendanceDay> _getAttendanceDay(Uri uri) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para ver la asistencia');
    }
    final response = await http.get(uri, headers: _authorizationHeaders(token));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo cargar la asistencia');
    }
    return AttendanceDay(
      date: data['date'].toString(),
      today: data['today'].toString(),
      days: (data['days'] as List<dynamic>).map((d) => d.toString()).toList(),
      totalTeachers: data['totalTeachers'] as int? ?? 0,
      schedules: (data['schedules'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => AttendanceSchedule(
              attendanceStart: item['attendanceStart'].toString(),
              attendanceEnd: item['attendanceEnd'].toString(),
              breakStart: item['breakStart'].toString(),
              breakEnd: item['breakEnd'].toString(),
              attendanceEnabled:
                  item['attendanceEnabled'] != false &&
                  item['attendanceEnabled'] != 0,
              breakEnabled:
                  item['breakEnabled'] != false && item['breakEnabled'] != 0,
            ),
          )
          .toList(),
      rows: (data['teachers'] as List<dynamic>? ?? const [])
          .map(
            (item) => AttendanceRow(
              id: item['id'] as int,
              name: (item['name'] ?? '').toString(),
              email: (item['email'] ?? '').toString(),
              attendanceTime: item['attendanceTime'] as String?,
              breakTime: item['breakTime'] as String?,
            ),
          )
          .toList(),
    );
  }

  static Future<void> saveAdminAttendanceSchedule({
    required String date,
    required List<AttendanceSchedule> schedules,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para configurar el horario');
    }
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/attendance/schedule'),
      headers: _authorizationHeaders(token, json: true),
      body: jsonEncode({
        'date': date,
        'schedules': schedules
            .map(
              (schedule) => {
                'attendanceStart': schedule.attendanceStart,
                'attendanceEnd': schedule.attendanceEnd,
                'breakStart': schedule.breakStart,
                'breakEnd': schedule.breakEnd,
                'attendanceEnabled': schedule.attendanceEnabled,
                'breakEnabled': schedule.breakEnabled,
              },
            )
            .toList(),
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo guardar el horario');
    }
  }

  static Future<bool> setAdminAttendance({
    required int userId,
    required String kind,
    required String date,
    required bool registered,
  }) async {
    if (!registered) {
      await removeAttendance(userId: userId, kind: kind, date: date);
      return true;
    }

    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para modificar la asistencia');
    }
    final response = await http.post(
      Uri.parse('$_baseUrl/admin/attendance'),
      headers: _authorizationHeaders(token, json: true),
      body: jsonEncode({'userId': userId, 'kind': kind, 'date': date}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo actualizar el registro');
    }
    return data['status'] == 'registered';
  }

  static Future<void> deleteAttendanceDay(String date) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para quitar el día');
    }
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/attendance/day'),
      headers: _authorizationHeaders(token, json: true),
      body: jsonEncode({'date': date}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo quitar el día');
    }
  }

  static Future<AdminUserImportResult> importAdminUsers({
    required PlatformFile file,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para importar usuarios');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/admin/users/import'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await _wordFilePart(file));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw Exception(
        'El servidor devolvió una respuesta inesperada al importar el Word',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'El servidor devolvió una respuesta inesperada al importar el Word',
      );
    }
    final data = decoded;
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception(
        data['message'] ?? 'No se pudieron importar los usuarios',
      );
    }

    final results = (data['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    return AdminUserImportResult(
      message: data['message']?.toString() ?? 'Importación finalizada',
      created: int.tryParse(data['created']?.toString() ?? '') ?? 0,
      updated: int.tryParse(data['updated']?.toString() ?? '') ?? 0,
      alreadyRegistered:
          int.tryParse(data['alreadyRegistered']?.toString() ?? '') ?? 0,
      failed: int.tryParse(data['failed']?.toString() ?? '') ?? 0,
      results: results,
    );
  }

  static Future<String> sendAdminUserInvitation(int id) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para enviar invitaciones');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/admin/users/$id/invitation'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo enviar la invitación');
    }
    return data['message']?.toString() ?? 'Invitación enviada';
  }

  static Future<AdminInvitationResult> sendPendingTeacherInvitations() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para enviar invitaciones');
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/admin/users/invitations'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        data['message'] ?? 'No se pudieron enviar las invitaciones',
      );
    }

    final results = (data['results'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>();
    return AdminInvitationResult(
      message:
          data['message']?.toString() ?? 'Proceso de invitación finalizado',
      sent: int.tryParse(data['sent']?.toString() ?? '') ?? 0,
      failed: int.tryParse(data['failed']?.toString() ?? '') ?? 0,
      errors: results.where((result) => result['status'] == 'error').toList(),
    );
  }

  static Future<void> updateAdminUser({
    required int id,
    required String name,
    required String email,
    String password = '',
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para actualizar usuarios');
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/admin/users/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        if (password.isNotEmpty) 'password': password,
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo actualizar el usuario');
    }
  }

  static Future<void> deleteAdminUser(int id) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para eliminar usuarios');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/users/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo eliminar el usuario');
    }
  }

  static Future<void> deleteAdminActivity(int id) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para eliminar actividades');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/activities/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo eliminar la actividad');
    }
  }

  static Future<SpeakerList> getSpeakers() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para consultar conferencistas');
    }

    final response = await http.get(
      Uri.parse(
        '$_baseUrl/speakers?refresh=${DateTime.now().microsecondsSinceEpoch}',
      ),
      headers: _authorizationHeaders(token),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(
        data['message'] ?? 'No se pudo cargar la lista de conferencistas',
      );
    }

    return SpeakerList(
      minCvWords: int.tryParse(data['minCvWords']?.toString() ?? '') ?? 100,
      speakers: (data['speakers'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SpeakerItem.fromJson)
          .toList(),
    );
  }

  static Future<void> saveSpeaker({
    int? id,
    required String name,
    PlatformFile? photo,
    PlatformFile? cv,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para guardar conferencistas');
    }

    final request = http.MultipartRequest(
      id == null ? 'POST' : 'PUT',
      Uri.parse('$_baseUrl/admin/speakers${id == null ? '' : '/$id'}'),
    );
    request.headers.addAll(_authorizationHeaders(token));
    request.fields['name'] = name;
    if (photo != null) request.files.add(await _filePart('photo', photo));
    if (cv != null) request.files.add(await _filePart('cv', cv));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } on FormatException {
      data = null;
    }
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception(
        data?['message'] ??
            'No se pudo guardar el conferencista. Reinicia el backend e '
                'inténtalo de nuevo.',
      );
    }
  }

  static Future<void> deleteSpeaker(int id) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para eliminar conferencistas');
    }

    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/speakers/$id'),
      headers: _authorizationHeaders(token),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(
        data['message'] ?? 'No se pudo eliminar el conferencista',
      );
    }
  }

  static Future<http.MultipartFile> _filePart(
    String field,
    PlatformFile file,
  ) async {
    if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
      return http.MultipartFile.fromPath(
        field,
        file.path!,
        filename: file.name,
      );
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('No se pudieron leer los bytes de ${file.name}');
    }
    return http.MultipartFile.fromBytes(field, bytes, filename: file.name);
  }

  static Future<List<ContentSection>> getContentSections() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para consultar las secciones');
    }
    final response = await http.get(
      Uri.parse('$_baseUrl/sections'),
      headers: _authorizationHeaders(token),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudieron cargar las secciones');
    }
    return (data['sections'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ContentSection.fromJson)
        .toList();
  }

  static Future<void> saveContentSection({
    required String title,
    required String body,
    String videoUrl = '',
    PlatformFile? image,
    PlatformFile? video,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para crear secciones');
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/admin/sections'),
    );
    request.headers.addAll(_authorizationHeaders(token));
    request.fields['title'] = title;
    request.fields['body'] = body;
    request.fields['videoUrl'] = videoUrl;
    if (image != null) request.files.add(await _filePart('image', image));
    if (video != null) request.files.add(await _filePart('video', video));
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) data = decoded;
    } on FormatException {
      data = null;
    }
    if (response.statusCode != 201) {
      throw Exception(
        data?['message'] ??
            'El servidor no devolvió una respuesta válida al subir el video.',
      );
    }
  }

  static Future<void> deleteContentSection(int id) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para eliminar secciones');
    }
    final response = await http.delete(
      Uri.parse('$_baseUrl/admin/sections/$id'),
      headers: _authorizationHeaders(token),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo eliminar la sección');
    }
  }

  static Future<void> updateContentSection({
    required int id,
    required String title,
    required String body,
    String videoUrl = '',
    PlatformFile? image,
    PlatformFile? video,
    bool removeImage = false,
    bool removeVideo = false,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para actualizar secciones');
    }
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$_baseUrl/admin/sections/$id'),
    );
    request.headers.addAll(_authorizationHeaders(token));
    request.fields['title'] = title;
    request.fields['body'] = body;
    request.fields['videoUrl'] = videoUrl;
    request.fields['removeImage'] = removeImage.toString();
    request.fields['removeVideo'] = removeVideo.toString();
    if (image != null) request.files.add(await _filePart('image', image));
    if (video != null) request.files.add(await _filePart('video', video));
    final response = await request.send();
    final responseBody = await response.stream.bytesToString();
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) data = decoded;
    } on FormatException {
      data = null;
    }
    if (response.statusCode != 200) {
      throw Exception(data?['message'] ?? 'No se pudo actualizar la sección');
    }
  }

  static Future<void> moveContentSection(int id, {required bool up}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para ordenar las secciones');
    }
    final response = await http.put(
      Uri.parse('$_baseUrl/admin/sections/$id/order'),
      headers: _authorizationHeaders(token, json: true),
      body: jsonEncode({'direction': up ? 'up' : 'down'}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo actualizar el orden');
    }
  }

  static Future<List<ActivityItem>> getActivities() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para consultar actividades');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/activities'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw Exception(
        data['message'] ?? 'No se pudo cargar la lista de actividades',
      );
    }

    return (data['activities'] as List<dynamic>)
        .map(
          (activity) => ActivityItem.fromJson(activity as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<List<WordDocumentBlock>> getAdminActivityDocument(
    int id,
  ) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para ver el documento');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/admin/activities/$id/document'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo abrir el documento');
    }
    return _parseDocumentBlocks(data['blocks']);
  }

  static Future<List<WordDocumentBlock>> previewWordDocument(
    PlatformFile file,
  ) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para ver el documento');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/admin/activities/preview'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await _wordFilePart(file));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      if (streamed.statusCode == 404) {
        throw Exception(
          'Reinicia el backend para activar la vista previa de Word',
        );
      }
      throw Exception(
        'El servidor devolvió una respuesta inesperada al abrir el Word',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'El servidor devolvió una respuesta inesperada al abrir el Word',
      );
    }
    final data = decoded;
    if (streamed.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo abrir el documento');
    }
    return _parseDocumentBlocks(data['blocks']);
  }

  static Future<http.MultipartFile> _wordFilePart(PlatformFile file) async {
    if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
      return http.MultipartFile.fromPath(
        'file',
        file.path!,
        filename: file.name,
      );
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('No se pudieron leer los bytes del archivo Word');
    }
    return http.MultipartFile.fromBytes('file', bytes, filename: file.name);
  }

  static List<WordDocumentBlock> _parseDocumentBlocks(dynamic value) {
    if (value is! List<dynamic>) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(WordDocumentBlock.fromJson)
        .toList();
  }

  static Future<ActivityItem> uploadActivity({
    required String activity,
    required String date,
    required String time,
    required String modality,
    String responsible = '',
    String place = '',
    PlatformFile? file,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para subir la actividad');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/admin/activities'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['activity'] = activity;
    request.fields['date'] = date;
    request.fields['time'] = time;
    request.fields['responsible'] = responsible;
    request.fields['place'] = place;
    request.fields['modality'] = modality;

    if (file != null) {
      request.files.add(await _wordFilePart(file));
    }

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    final data = jsonDecode(body);

    if (streamed.statusCode != 201) {
      throw Exception(data['message'] ?? 'No se pudo guardar la actividad');
    }

    return ActivityItem.fromJson(data['activity'] as Map<String, dynamic>);
  }

  static Future<int> saveActivityBatch({
    required List<Map<String, dynamic>> activities,
    required PlatformFile file,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para guardar la agenda');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/admin/activities/batch'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['activities'] = jsonEncode(activities);
    request.files.add(await _wordFilePart(file));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (streamed.statusCode != 201) {
      throw Exception(data['message'] ?? 'No se pudo guardar la agenda');
    }
    return (data['activities'] as List<dynamic>).length;
  }

  static Future<ActivityItem> saveStructuredActivity({
    required String title,
    required String activity,
    required String date,
    required String time,
    required String modality,
    required String type,
    String? description,
    String? speakerName,
    required PlatformFile file,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para guardar la agenda');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/admin/activities'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title;
    request.fields['activity'] = activity;
    request.fields['date'] = date;
    request.fields['time'] = time;
    request.fields['modality'] = modality;
    request.fields['type'] = type;
    request.fields['description'] = description ?? '';
    if ((speakerName ?? '').trim().isNotEmpty) {
      request.fields['speaker_name'] = speakerName!.trim();
    }
    request.files.add(await _wordFilePart(file));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();
    final data = jsonDecode(body);

    if (streamed.statusCode != 201) {
      throw Exception(
        data['message'] ?? 'No se pudo guardar la agenda estructurada',
      );
    }

    return ActivityItem.fromJson(data['activity'] as Map<String, dynamic>);
  }

  static Future<void> updateAdminActivity({
    required int id,
    required String activity,
    required String date,
    required String time,
    required String modality,
    String responsible = '',
    String place = '',
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Inicia sesión para actualizar actividades');
    }

    final response = await http.put(
      Uri.parse('$_baseUrl/admin/activities/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'activity': activity,
        'date': date,
        'time': time,
        'responsible': responsible,
        'place': place,
        'modality': modality,
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message'] ?? 'No se pudo actualizar la actividad');
    }
  }

  static Future<AuthResponse> resendVerification(String email) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/resend-verification'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    final data = jsonDecode(response.body);
    return AuthResponse(
      success: response.statusCode == 202,
      message: data['message'] ?? 'No se pudo reenviar el código',
    );
  }

  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');

    if (userString == null || userString.isEmpty) return null;
    return UserModel.fromJson(jsonDecode(userString));
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}
