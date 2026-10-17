import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  bool isLoading = false;
  String? message;
  UserModel? currentUser;

  bool get isAuthenticated => currentUser != null;

  Future<void> loadSession() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      currentUser = null;
      notifyListeners();
      return;
    }

    currentUser = await AuthService.getCurrentUser();
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    isLoading = true;
    message = null;
    notifyListeners();

    final result = await AuthService.login(email, password);
    currentUser = result.user;
    message = result.message;
    isLoading = false;
    notifyListeners();

    return result.success;
  }

  Future<bool> register(String name, String email, String password) async {
    isLoading = true;
    message = null;
    notifyListeners();

    final result = await AuthService.register(name, email, password);
    currentUser = result.user;
    message = result.message;
    isLoading = false;
    notifyListeners();

    return result.success;
  }

  Future<bool> verifyEmail(String email, String code) async {
    isLoading = true;
    message = null;
    notifyListeners();

    final result = await AuthService.verifyEmail(email, code);
    message = result.message;
    isLoading = false;
    notifyListeners();

    return result.success;
  }

  Future<bool> resendVerification(String email) async {
    isLoading = true;
    message = null;
    notifyListeners();

    final result = await AuthService.resendVerification(email);
    message = result.message;
    isLoading = false;
    notifyListeners();

    return result.success;
  }

  Future<void> logout() async {
    await AuthService.logout();
    currentUser = null;
    notifyListeners();
  }
}
