import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/user_model.dart';
import '../home/admin_home_screen.dart';
import '../home/attendant_home_screen.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late AuthController _controller;
  bool _sessionLoadStarted = false;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = context.read<AuthController>();
    if (!_sessionLoadStarted) {
      _sessionLoadStarted = true;
      _initAuth();
    }
  }

  Future<void> _initAuth() async {
    await _controller.loadSession();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthController, UserModel?>(
      (controller) => controller.currentUser,
    );

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) return const LoginScreen();

    return user.isAdmin
        ? const AdminHomeScreen()
        : user.isAttendant
        ? const AttendantHomeScreen()
        : const HomeScreen();
  }
}
