import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key, required this.email});

  final String email;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;

  Future<void> _verifyCode() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final controller = context.read<AuthController>();
      final success = await controller.verifyEmail(
        widget.email,
        _codeController.text.trim(),
      );
      if (!mounted) return;

      if (success) {
        await _showResult(
          'Correo verificado',
          controller.message ?? 'Tu cuenta ya está activa.',
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              controller.message ?? 'No se pudo verificar el correo',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('No se pudo conectar con el servidor')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    try {
      final controller = context.read<AuthController>();
      final success = await controller.resendVerification(widget.email);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              controller.message ??
                  (success
                      ? 'Código reenviado'
                      : 'No se pudo reenviar el código'),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('No se pudo conectar con el servidor')),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _showResult(String title, String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _openLogin();
            },
            child: const Text('Iniciar sesión'),
          ),
        ],
      ),
    );
  }

  void _openLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(initialEmail: widget.email),
      ),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificar correo')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Revisa tu correo',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enviamos un código de seis dígitos y un enlace a ${widget.email}.',
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Código de verificación',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.length != 6
                            ? 'Ingresa el código de seis dígitos'
                            : null,
                        onFieldSubmitted: (_) => _verifyCode(),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _isSubmitting ? null : _verifyCode,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Verificar y crear cuenta'),
                      ),
                      TextButton(
                        onPressed: _isResending ? null : _resendCode,
                        child: Text(
                          _isResending
                              ? 'Enviando...'
                              : 'Reenviar código y enlace',
                        ),
                      ),
                      TextButton(
                        onPressed: _openLogin,
                        child: const Text(
                          'Ya activé mi cuenta desde el enlace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
