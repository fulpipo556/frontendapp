import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthResponse {
  final bool success;
  final String message;
  final Map<String, dynamic>? user;
  final String? token;

  AuthResponse({
    required this.success,
    required this.message,
    this.user,
    this.token,
  });
}

class AuthService {
  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://appbackend-production-de33.up.railway.app/api',
  );

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
        user: data['user'],
        token: data['token'],
      );
    }

    return AuthResponse(
      success: false,
      message: data['message'] ?? 'Error al iniciar sesión',
    );
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

    if (response.statusCode == 201 && data['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['token']);
      await prefs.setString('user', jsonEncode(data['user']));

      return AuthResponse(
        success: true,
        message: data['message'] ?? 'Usuario registrado',
        user: data['user'],
        token: data['token'],
      );
    }

    return AuthResponse(
      success: false,
      message: data['message'] ?? 'Error al registrar usuario',
    );
  }

  static Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');

    if (userString == null) return null;
    return jsonDecode(userString);
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
