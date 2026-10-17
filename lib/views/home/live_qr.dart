import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/auth_service.dart';

/// QR que se renueva cada pocos segundos; una foto o captura deja de servir.
class LiveQr extends StatefulWidget {
  const LiveQr({super.key, this.size = 200});

  final double size;

  @override
  State<LiveQr> createState() => _LiveQrState();
}

class _LiveQrState extends State<LiveQr> {
  static const _refreshEvery = Duration(seconds: 10);

  Timer? _timer;
  String? _code;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(_refreshEvery, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final code = await AuthService.getLiveQrCode();
      if (!mounted) return;
      setState(() {
        _code = code;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _code = null;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: code != null
          ? QrImageView(data: code, size: widget.size)
          : Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(
                      'Sin conexión: $_error',
                      textAlign: TextAlign.center,
                    ),
            ),
    );
  }
}
