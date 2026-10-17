import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/user_model.dart';

const String seminarQrData = 'UNESUM|SEMINARIO|GENERAL';

String userQrData(UserModel user) =>
    'UNESUM|SEMINARIO|USUARIO|${user.id ?? ''}|${user.name}|${user.email}';

Future<void> showAllTeachersQrDialog(
  BuildContext context,
  List<UserModel> users,
) {
  final teachers = users.where((user) => user.isTeacher).toList();
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('QR de docentes (${teachers.length})'),
      content: SizedBox(
        width: 320,
        height: 420,
        child: teachers.isEmpty
            ? const Center(child: Text('No hay docentes registrados'))
            : ListView.separated(
                itemCount: teachers.length,
                separatorBuilder: (_, _) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final teacher = teachers[index];
                  return Column(
                    children: [
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(8),
                        child: QrImageView(
                          data: userQrData(teacher),
                          size: 180,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        teacher.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(teacher.email, textAlign: TextAlign.center),
                    ],
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

Future<void> showQrDialog(
  BuildContext context, {
  required String title,
  required String data,
  String? caption,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const Key('qr_code_image'),
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(data: data, size: 220),
            ),
            if (caption != null) ...[
              const SizedBox(height: 12),
              Text(caption, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
