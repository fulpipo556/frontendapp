import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/auth_controller.dart';
import 'views/auth/auth_gate.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthController(),
      child: MaterialApp(
        title: 'Flutter Login MySQL',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0D5C4D),
          ),
          scaffoldBackgroundColor: const Color(0xFFEAEFEA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0D5C4D),
            foregroundColor: Colors.white,
          ),
          useMaterial3: true,
        ),
        home: const AuthGate(),
      ),
    );
  }
}
