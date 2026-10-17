import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../home/admin_home_screen.dart';
import '../home/attendant_home_screen.dart';
import '../home/home_screen.dart';
import 'email_verification_screen.dart';

const _brandGreen = Color(0xFF075044);
const _brandGold = Color(0xFFC49A43);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final bool _isLogin = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? '';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final controller = context.read<AuthController>();
    final bool success;

    if (_isLogin) {
      success = await controller.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } else {
      success = await controller.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    }

    if (!mounted) return;

    final message = controller.message ?? 'Ocurrió un error';
    setState(() => _isSubmitting = false);

    if (success) {
      if (_isLogin) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(message)),
        );
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => controller.currentUser?.isAdmin == true
                ? const AdminHomeScreen()
                : controller.currentUser?.isAttendant == true
                ? const AttendantHomeScreen()
                : const HomeScreen(),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                EmailVerificationScreen(email: _emailController.text.trim()),
          ),
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _emailController.text);
    final formKey = GlobalKey<FormState>();
    var isSending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Recuperar contraseña'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ingresa tu correo y te enviaremos un enlace para cambiar tu clave.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Ingresa un correo válido',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: isSending
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSending = true);
                      String message;
                      try {
                        message = await AuthService.requestPasswordReset(
                          controller.text.trim(),
                        );
                      } catch (error) {
                        message = error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        );
                      }
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      if (!mounted) return;
                      ScaffoldMessenger.maybeOf(
                        context,
                      )?.showSnackBar(SnackBar(content: Text(message)));
                    },
              child: Text(isSending ? 'Enviando...' : 'Enviar enlace'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    return Theme(
      data: baseTheme.copyWith(
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: _brandGreen,
          onPrimary: Colors.white,
          secondary: _brandGold,
          onSecondary: Colors.white,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Color(0xFF536C64)),
          floatingLabelStyle: TextStyle(color: _brandGreen),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF9BAD9F)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: _brandGold, width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _brandGreen,
            foregroundColor: Colors.white,
            side: const BorderSide(color: _brandGold),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _brandGreen),
        ),
      ),
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: 0.36,
              child: Image.asset(
                'assets/images/campus_background.jpg',
                fit: BoxFit.cover,
              ),
            ),
            const ColoredBox(color: Color(0x33FFFFFF)),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 108,
                        height: 108,
                        child: Image.asset(
                          'assets/images/escudo_unesum.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FractionallySizedBox(
                        widthFactor: 0.75,
                        child: AspectRatio(
                          aspectRatio: 477 / 170,
                          child: Image.asset(
                            'assets/images/logo2016_transparent.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        color: const Color(0xFFF8FAF6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isLogin ? 'Iniciar sesión' : 'Crear cuenta',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(color: _brandGreen),
                                ),
                                const SizedBox(height: 24),
                                if (!_isLogin)
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Ingresa tu nombre';
                                      }
                                      return null;
                                    },
                                  ),
                                if (!_isLogin) const SizedBox(height: 16),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Correo electrónico',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Ingresa tu correo';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Correo inválido';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Contraseña',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Ingresa tu contraseña';
                                    }
                                    if (value.length < 6) {
                                      return 'Mínimo 6 caracteres';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _isSubmitting ? null : _submit,
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            _isLogin ? 'Entrar' : 'Registrarme',
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: _forgotPassword,
                                  child: const Text(
                                    '¿Olvidaste tu contraseña?',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
