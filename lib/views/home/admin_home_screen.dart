import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'admin_attendance_tab.dart';
import 'admin_speakers_tab.dart';
import 'admin_sections_tab.dart';
import 'qr_dialog.dart';

class _DocumentAgendaRow {
  final String date;
  final DateTime? dateValue;
  final String time;
  final String startTime;
  final String endTime;
  final int? startMinute;
  final String activity;
  final String responsible;
  final String place;
  final String modality;

  const _DocumentAgendaRow({
    required this.date,
    required this.dateValue,
    required this.time,
    required this.startTime,
    required this.endTime,
    required this.startMinute,
    required this.activity,
    required this.responsible,
    required this.place,
    required this.modality,
  });
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<List<UserModel>> _users;
  late Future<List<ActivityItem>> _activities;
  late Future<List<WorkshopItem>> _workshops;

  final TextEditingController _activityController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _modalidadController = TextEditingController();
  final TextEditingController _responsibleController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  bool _isManagingUsers = false;
  bool _isSendingInvitations = false;
  bool _isManagingWorkshops = false;

  @override
  void initState() {
    super.initState();
    _users = AuthService.getAdminUsers();
    _activities = AuthService.getActivities();
    _workshops = AuthService.getAdminWorkshops();
  }

  @override
  void dispose() {
    _activityController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _modalidadController.dispose();
    _responsibleController.dispose();
    _placeController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    final users = AuthService.getAdminUsers();
    final activities = AuthService.getActivities();
    final workshops = AuthService.getAdminWorkshops();
    if (!mounted) return;
    setState(() {
      _users = users;
      _activities = activities;
      _workshops = workshops;
    });
    await Future.wait([users, activities, workshops]);
  }

  Future<void> _pickWordFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );

    if (result.isEmpty) {
      return;
    }

    final file = result.first;
    final extension = file.name.split('.').last.toLowerCase();
    if (extension != 'docx') {
      _showSnackBar('Solo se permiten archivos DOCX reales (.docx).');
      return;
    }

    setState(() {
      _selectedFile = file;
    });
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Selecciona la fecha de la actividad',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (selectedDate == null || !mounted) return;

    setState(() {
      _selectedDate = selectedDate;
      _dateController.text =
          '${selectedDate.day.toString().padLeft(2, '0')}/'
          '${selectedDate.month.toString().padLeft(2, '0')}/'
          '${selectedDate.year}';
    });
  }

  Future<void> _selectTime() async {
    if (_selectedDate == null) {
      _showSnackBar('Primero selecciona la fecha de la actividad.');
      return;
    }

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      helpText: 'Selecciona la hora',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

    if (selectedTime == null || !mounted) return;

    setState(() {
      _selectedTime = selectedTime;
      _timeController.text =
          '${selectedTime.hour.toString().padLeft(2, '0')}:'
          '${selectedTime.minute.toString().padLeft(2, '0')}';
    });
  }

  String? _optionalPasswordError(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return null;
    if (password.length < 8) return 'Mínimo 8 caracteres';
    if (password.length > 128) return 'Máximo 128 caracteres';
    return null;
  }

  Future<void> _editUser(UserModel user) async {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Actualizar usuario'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Ingresa un nombre'
                    : null,
              ),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Ingresa un correo válido';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña (opcional)',
                  helperText:
                      'Mínimo 8 caracteres. Déjala vacía para no cambiarla.',
                  helperMaxLines: 2,
                ),
                validator: _optionalPasswordError,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (shouldSave == true && user.id != null) {
      try {
        await AuthService.updateAdminUser(
          id: user.id!,
          name: nameController.text.trim(),
          email: emailController.text.trim(),
          password: passwordController.text,
        );
        await _refreshData();
        _showSnackBar(
          passwordController.text.isEmpty
              ? 'Usuario actualizado correctamente.'
              : 'Usuario y contraseña actualizados correctamente.',
        );
      } catch (error) {
        _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
      }
    }

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> _deleteUser(UserModel user) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Deseas eliminar la cuenta de ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || user.id == null) return;

    try {
      await AuthService.deleteAdminUser(user.id!);
      await _refreshData();
      _showSnackBar('Usuario eliminado correctamente.');
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _sendTeacherInvitation(UserModel user) async {
    if (user.id == null || user.isAdmin || !user.passwordSetupRequired) {
      return;
    }

    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enviar invitación'),
        content: Text(
          'Se enviará a ${user.email} un enlace para crear su contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (shouldSend != true || !mounted) return;

    setState(() {
      _isManagingUsers = true;
      _isSendingInvitations = true;
    });
    try {
      final message = await AuthService.sendAdminUserInvitation(user.id!);
      _showSnackBar(message);
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isManagingUsers = false;
          _isSendingInvitations = false;
        });
      }
    }
  }

  Future<void> _sendPendingTeacherInvitations(int pendingCount) async {
    final shouldSend = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enviar invitaciones a docentes'),
        content: Text(
          'Se enviará un correo individual a cada uno de los $pendingCount '
          'docentes que todavía no han configurado su contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enviar invitaciones'),
          ),
        ],
      ),
    );
    if (shouldSend != true || !mounted) return;

    setState(() {
      _isManagingUsers = true;
      _isSendingInvitations = true;
    });
    try {
      final result = await AuthService.sendPendingTeacherInvitations();
      if (!mounted) return;
      setState(() {
        _users = AuthService.getAdminUsers();
      });
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Resultado del envío'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.message),
                if (result.errors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Correos que no se pudieron enviar:'),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 220,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final error in result.errors)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                '${error['name']} (${error['email']}): '
                                '${error['message']}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isManagingUsers = false;
          _isSendingInvitations = false;
        });
      }
    }
  }

  Future<void> _createAdminUser() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var selectedRole = 'teacher';

    final shouldCreate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Agregar usuario'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatefulBuilder(
                  builder: (context, setRoleState) =>
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de cuenta',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'teacher',
                            child: Text('Docente'),
                          ),
                          DropdownMenuItem(
                            value: 'attendant',
                            child: Text('Registrador de asistencia'),
                          ),
                        ],
                        onChanged: (value) =>
                            setRoleState(() => selectedRole = value!),
                      ),
                ),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa un nombre'
                      : value.trim().length > 100
                      ? 'Máximo 100 caracteres'
                      : null,
                ),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                  ),
                  validator: (value) =>
                      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Ingresa un correo válido',
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña (opcional)',
                    helperText: 'Mínimo 8 caracteres. Déjala vacía para solo enviar el enlace.',
                    helperMaxLines: 2,
                  ),
                  validator: _optionalPasswordError,
                ),
                const SizedBox(height: 8),
                const Text(
                  'También se enviará un enlace al correo para que el usuario cree o cambie su contraseña.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Crear usuario'),
          ),
        ],
      ),
    );

    if (shouldCreate == true) {
      if (!mounted) return;
      setState(() => _isManagingUsers = true);
      try {
        await AuthService.createAdminUser(
          name: nameController.text.trim(),
          email: emailController.text.trim(),
          role: selectedRole,
          password: passwordController.text,
        );
        if (!mounted) return;
        final usersFuture = AuthService.getAdminUsers();
        setState(() {
          _users = usersFuture;
        });
        _showSnackBar(
          'Usuario creado. Se envió el enlace para configurar su contraseña.',
        );
        final createdEmail = emailController.text.trim().toLowerCase();
        final updatedUsers = await usersFuture;
        UserModel? created;
        for (final user in updatedUsers) {
          if (user.email.toLowerCase() == createdEmail) created = user;
        }
        if (created != null && mounted) {
          await showQrDialog(
            context,
            title: created.name,
            data: userQrData(created),
            caption: '${created.email}\nQR individual del docente',
          );
        }
      } catch (error) {
        _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _isManagingUsers = false);
      }
    }

    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  Future<void> _importAdminUsersFromWord() async {
    final selection = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (selection.isEmpty) return;

    final file = selection.first;
    if (file.name.split('.').last.toLowerCase() != 'docx') {
      _showSnackBar('Selecciona un documento Word DOCX.');
      return;
    }
    if (!mounted) return;

    setState(() => _isManagingUsers = true);
    try {
      final result = await AuthService.importAdminUsers(file: file);
      if (!mounted) return;
      setState(() {
        _users = AuthService.getAdminUsers();
      });
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Resultado de la importación'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.message),
                if (result.updatedRows.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Docentes actualizados:'),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 130,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final row in result.updatedRows)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Fila ${row['row']}: ${row['name']} '
                                '(${row['email']})',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (result.alreadyRegisteredRows.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Ya estaban registrados:'),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 130,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final row in result.alreadyRegisteredRows)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Fila ${row['row']}: ${row['name']} '
                                '(${row['email']})',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (result.rowErrors.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Filas que no se pudieron importar:'),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 220,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final error in result.rowErrors)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Fila ${error['row']}: ${error['email']} — ${error['message']}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isManagingUsers = false);
    }
  }

  Future<void> _editActivity(ActivityItem activity) async {
    final activityController = TextEditingController(text: activity.activity);
    final dateController = TextEditingController(
      text: activity.date.split('T').first,
    );
    final timeController = TextEditingController(text: activity.time);
    final modalityController = TextEditingController(text: activity.modality);
    final responsibleController = TextEditingController(
      text: activity.responsible,
    );
    final placeController = TextEditingController(text: activity.place);
    final formKey = GlobalKey<FormState>();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Editar actividad'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: activityController,
                  decoration: const InputDecoration(labelText: 'Actividad'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa una actividad'
                      : null,
                ),
                TextFormField(
                  controller: dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Fecha',
                    suffixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  onTap: () async {
                    final currentDate = DateTime.tryParse(dateController.text);
                    final selectedDate = await showDatePicker(
                      context: dialogContext,
                      initialDate: currentDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      helpText: 'Selecciona la fecha de la actividad',
                    );
                    if (selectedDate != null) {
                      dateController.text =
                          '${selectedDate.year.toString().padLeft(4, '0')}-'
                          '${selectedDate.month.toString().padLeft(2, '0')}-'
                          '${selectedDate.day.toString().padLeft(2, '0')}';
                    }
                  },
                  validator: (value) => DateTime.tryParse(value ?? '') == null
                      ? 'Fecha inválida'
                      : null,
                ),
                TextFormField(
                  controller: timeController,
                  keyboardType: TextInputType.datetime,
                  decoration: const InputDecoration(
                    labelText: 'Hora (HH:mm)',
                    suffixIcon: Icon(Icons.access_time_outlined),
                  ),
                  validator: (value) =>
                      RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                          .hasMatch(value?.trim() ?? '')
                      ? null
                      : 'Usa el formato HH:mm',
                ),
                TextFormField(
                  controller: responsibleController,
                  decoration: const InputDecoration(labelText: 'Responsable'),
                ),
                TextFormField(
                  controller: placeController,
                  decoration: const InputDecoration(labelText: 'Lugar'),
                ),
                TextFormField(
                  controller: modalityController,
                  decoration: const InputDecoration(labelText: 'Modalidad'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (shouldSave == true) {
      try {
        await AuthService.updateAdminActivity(
          id: activity.id,
          activity: activityController.text.trim(),
          date: dateController.text.trim(),
          time: timeController.text.trim(),
          modality: modalityController.text.trim(),
          responsible: responsibleController.text.trim(),
          place: placeController.text.trim(),
        );
        await _refreshData();
        _showSnackBar('Actividad actualizada correctamente.');
      } catch (error) {
        _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
      }
    }

    activityController.dispose();
    dateController.dispose();
    timeController.dispose();
    modalityController.dispose();
    responsibleController.dispose();
    placeController.dispose();
  }

  Future<void> _deleteActivity(ActivityItem activity) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar actividad'),
        content: Text('¿Deseas eliminar "${activity.activity}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await AuthService.deleteAdminActivity(activity.id);
      await _refreshData();
      _showSnackBar('Actividad eliminada correctamente.');
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _saveWorkshopTitle({WorkshopItem? workshop}) async {
    final titleController = TextEditingController(text: workshop?.title ?? '');
    final capacityController = TextEditingController(
      text: workshop == null || workshop.capacity == 0
          ? ''
          : workshop.capacity.toString(),
    );
    final addressController = TextEditingController(
      text: workshop?.address ?? '',
    );
    final roomController = TextEditingController(text: workshop?.room ?? '');
    final sessionCount = workshop == null || workshop.dayTimes.isEmpty
        ? 1
        : workshop.dayTimes.length;
    final dateControllers = List.generate(
      sessionCount,
      (i) => TextEditingController(text: workshop?.dayTimes[i].date ?? ''),
    );
    final startControllers = List.generate(
      sessionCount,
      (i) => TextEditingController(text: workshop?.dayTimes[i].startTime ?? ''),
    );
    final endControllers = List.generate(
      sessionCount,
      (i) => TextEditingController(text: workshop?.dayTimes[i].endTime ?? ''),
    );
    Future<void> pickDate(
      BuildContext dialogContext,
      TextEditingController controller,
    ) async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: dialogContext,
        initialDate: DateTime.tryParse(controller.text) ?? now,
        firstDate: DateTime(now.year - 1),
        lastDate: DateTime(now.year + 5),
      );
      if (picked != null) {
        controller.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      }
    }

    Future<void> pickTime(
      BuildContext dialogContext,
      TextEditingController controller,
    ) async {
      final parts = controller.text.split(':');
      final initial = parts.length == 2
          ? TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 8,
              minute: int.tryParse(parts[1]) ?? 0,
            )
          : const TimeOfDay(hour: 8, minute: 0);
      final picked = await showTimePicker(
        context: dialogContext,
        initialTime: initial,
      );
      if (picked != null) {
        controller.text =
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      }
    }

    final formKey = GlobalKey<FormState>();
    final formError = ValueNotifier<String?>(null);
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(workshop == null ? 'Crear taller' : 'Editar taller'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: formError,
                  builder: (context, error, _) => error == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            error,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: titleController,
                            autofocus: true,
                            maxLength: 150,
                            decoration: const InputDecoration(
                              labelText: 'Título del taller',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final title = value?.trim() ?? '';
                              if (title.isEmpty) {
                                return 'Escribe el título del taller';
                              }
                              if (title.length > 150) {
                                return 'Máximo 150 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: capacityController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Cupo máximo diario (personas)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final capacity = int.tryParse(
                                value?.trim() ?? '',
                              );
                              if (capacity == null ||
                                  capacity < 1 ||
                                  capacity > 100000) {
                                return 'Ingresa un cupo entre 1 y 100000';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: addressController,
                            maxLength: 255,
                            decoration: const InputDecoration(
                              labelText: 'Dirección / sede',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? 'Escribe la dirección'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: roomController,
                            maxLength: 150,
                            decoration: const InputDecoration(
                              labelText: 'Aula / laboratorio / salón',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                (value?.trim().isEmpty ?? true)
                                ? 'Escribe el aula, laboratorio o salón'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          for (
                            var day = 0;
                            day < dateControllers.length;
                            day++
                          ) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    dateControllers.length == 1
                                        ? 'Fecha y hora'
                                        : 'Fecha y hora ${day + 1}',
                                    style: Theme.of(dialogContext)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                ),
                                if (dateControllers.length > 1)
                                  IconButton(
                                    tooltip: 'Quitar',
                                    icon: const Icon(Icons.close),
                                    onPressed: () => setDialogState(() {
                                      dateControllers.removeAt(day).dispose();
                                      startControllers.removeAt(day).dispose();
                                      endControllers.removeAt(day).dispose();
                                    }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: dateControllers[day],
                              readOnly: true,
                              onTap: () =>
                                  pickDate(dialogContext, dateControllers[day]),
                              decoration: const InputDecoration(
                                labelText: 'Fecha',
                                suffixIcon: Icon(Icons.event),
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) => (value?.isEmpty ?? true)
                                  ? 'Elige la fecha'
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                for (final isStart in [true, false])
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: isStart ? 8 : 0,
                                      ),
                                      child: TextFormField(
                                        controller: isStart
                                            ? startControllers[day]
                                            : endControllers[day],
                                        readOnly: true,
                                        onTap: () => pickTime(
                                          dialogContext,
                                          isStart
                                              ? startControllers[day]
                                              : endControllers[day],
                                        ),
                                        decoration: InputDecoration(
                                          labelText: isStart ? 'Inicio' : 'Fin',
                                          suffixIcon: const Icon(
                                            Icons.access_time,
                                          ),
                                          border: const OutlineInputBorder(),
                                        ),
                                        validator: (value) {
                                          if (value?.isEmpty ?? true) {
                                            return 'Elige la hora';
                                          }
                                          if (!isStart &&
                                              startControllers[day].text
                                                      .compareTo(value!) >=
                                                  0) {
                                            return 'Debe ser posterior al inicio';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setDialogState(() {
                                dateControllers.add(TextEditingController());
                                startControllers.add(TextEditingController());
                                endControllers.add(TextEditingController());
                              }),
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar otra fecha y hora'),
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              } else {
                formError.value = 'Completa los campos marcados en rojo (revisa también fecha y hora más abajo).';
              }
            },
            child: Text(workshop == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );

    if (shouldSave == true && mounted) {
      final dayTimes = [
        for (var day = 0; day < dateControllers.length; day++)
          WorkshopDayTime(
            date: dateControllers[day].text,
            startTime: startControllers[day].text,
            endTime: endControllers[day].text,
          ),
      ];
      setState(() => _isManagingWorkshops = true);
      try {
        if (workshop == null) {
          await AuthService.createWorkshop(
            title: titleController.text.trim(),
            capacity: int.parse(capacityController.text.trim()),
            address: addressController.text.trim(),
            room: roomController.text.trim(),
            dayTimes: dayTimes,
          );
        } else {
          await AuthService.updateWorkshop(
            id: workshop.id,
            title: titleController.text.trim(),
            capacity: int.parse(capacityController.text.trim()),
            address: addressController.text.trim(),
            room: roomController.text.trim(),
            dayTimes: dayTimes,
          );
        }
        await _refreshData();
        _showSnackBar(
          workshop == null
              ? 'Taller creado correctamente.'
              : 'Taller y cupo actualizados.',
        );
      } catch (error) {
        _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
      } finally {
        if (mounted) setState(() => _isManagingWorkshops = false);
      }
    }

    titleController.dispose();
    capacityController.dispose();
    addressController.dispose();
    roomController.dispose();
    for (final controller in [
      ...dateControllers,
      ...startControllers,
      ...endControllers,
    ]) {
      controller.dispose();
    }
  }

  Future<void> _assignWorkshopTeachers(WorkshopItem workshop) async {
    if (!mounted) return;
    setState(() => _isManagingWorkshops = true);
    try {
      final users = await AuthService.getAdminUsers();
      final allWorkshops = await AuthService.getAdminWorkshops();
      if (!mounted) return;
      final assignedTeacherIds = allWorkshops
          .expand((item) => item.teachers)
          .map((teacher) => teacher.id)
          .whereType<int>()
          .toSet();
      final selectedTeacherIds = workshop.teachers
          .map((teacher) => teacher.id)
          .whereType<int>()
          .toSet();
      final teachers = users
          .where(
            (user) =>
                user.isTeacher &&
                user.id != null &&
                (!assignedTeacherIds.contains(user.id) ||
                    selectedTeacherIds.contains(user.id)),
          )
          .toList();
      final updatedTeacherIds = await showDialog<List<int>>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Asignar docentes a ${workshop.title}'),
            content: SizedBox(
              width: 460,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (teachers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No hay docentes disponibles sin asignación.',
                        ),
                      ),
                    for (final teacher in teachers)
                      CheckboxListTile(
                        value:
                            teacher.id != null &&
                            selectedTeacherIds.contains(teacher.id),
                        title: Text(teacher.name),
                        subtitle: Text(teacher.email),
                        onChanged: teacher.id == null
                            ? null
                            : (selected) {
                                setDialogState(() {
                                  if (selected == true) {
                                    selectedTeacherIds.add(teacher.id!);
                                  } else {
                                    selectedTeacherIds.remove(teacher.id);
                                  }
                                });
                              },
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, selectedTeacherIds.toList()),
                child: const Text('Guardar asignación'),
              ),
            ],
          ),
        ),
      );
      if (updatedTeacherIds == null || !mounted) return;

      await AuthService.assignWorkshopTeachers(
        workshopId: workshop.id,
        teacherIds: updatedTeacherIds,
      );
      await _refreshData();
      _showSnackBar('Docentes asignados correctamente.');
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isManagingWorkshops = false);
    }
  }

  Future<void> _removeWorkshopTeacher(
    WorkshopItem workshop,
    UserModel teacher,
  ) async {
    final teacherId = teacher.id;
    if (teacherId == null || !mounted) return;
    setState(() => _isManagingWorkshops = true);
    try {
      final teacherIds = workshop.teachers
          .map((item) => item.id)
          .whereType<int>()
          .where((id) => id != teacherId)
          .toList();
      await AuthService.assignWorkshopTeachers(
        workshopId: workshop.id,
        teacherIds: teacherIds,
      );
      await _refreshData();
      _showSnackBar('${teacher.name} fue retirado del taller.');
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isManagingWorkshops = false);
    }
  }

  Future<void> _deleteWorkshop(WorkshopItem workshop) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar taller'),
        content: Text(
          '¿Deseas eliminar "${workshop.title}" y sus asignaciones de docentes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    setState(() => _isManagingWorkshops = true);
    try {
      await AuthService.deleteWorkshop(workshop.id);
      await _refreshData();
      _showSnackBar('Taller eliminado correctamente.');
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isManagingWorkshops = false);
    }
  }

  Widget _buildRotationOverview(List<WorkshopItem> workshops) {
    final n = workshops.length;
    if (n < 3) {
      return const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Crea al menos 3 talleres para ver la rotación de los 3 días.',
        ),
      );
    }

    String normalizedTitle(String title) {
      return title
          .toUpperCase()
          .replaceAll(RegExp(r'[ÁÀÄÂ]'), 'A')
          .replaceAll(RegExp(r'[ÉÈËÊ]'), 'E')
          .replaceAll(RegExp(r'[ÍÌÏÎ]'), 'I')
          .replaceAll(RegExp(r'[ÓÒÖÔ]'), 'O')
          .replaceAll(RegExp(r'[ÚÙÜÛ]'), 'U')
          .trim();
    }

    final workshopIndexByName = <String, int>{};
    for (var index = 0; index < workshops.length; index++) {
      workshopIndexByName[normalizedTitle(workshops[index].title)] = index;
    }

    const rotationByGroup = <List<String>>[
      ['EVALUA', 'INSPIRA', 'INNOVA'],
      ['INSPIRA', 'EVALUA', 'TRANSFORMA'],
      ['INNOVA', 'TRANSFORMA', 'INSPIRA'],
      ['TRANSFORMA', 'INNOVA', 'EVALUA'],
    ];
    final namedRotation = [
      for (final route in rotationByGroup)
        [
          for (final workshopName in route)
            workshopIndexByName[workshopName] ?? -1,
        ],
    ];
    final hasNamedRotation = namedRotation.every(
      (group) => group.every((workshopIndex) => workshopIndex >= 0),
    );
    final groupCount = hasNamedRotation ? 4 : n;

    int workshopIndexFor(int group, int day) {
      if (hasNamedRotation) return namedRotation[group][day];
      return (group + day) % n;
    }

    String groupName(int g) => 'Grupo ${String.fromCharCode(65 + g % 26)}';
    String workshopNameFor(int group, int day) {
      if (hasNamedRotation) return rotationByGroup[group][day];
      return workshops[workshopIndexFor(group, day)].title;
    }

    final teachersByGroup = List.generate(
      groupCount,
      (_) => <int, UserModel>{},
    );
    if (hasNamedRotation) {
      const baseWorkshops = ['EVALUA', 'INSPIRA', 'INNOVA', 'TRANSFORMA'];
      for (final workshop in workshops) {
        final group = baseWorkshops.indexOf(normalizedTitle(workshop.title));
        if (group < 0) continue;
        for (final teacher in workshop.teachers) {
          if (teacher.id != null) {
            teachersByGroup[group][teacher.id!] = teacher;
          }
        }
      }
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rotación de 3 días', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            hasNamedRotation
                ? 'Distribución establecida para 4 grupos y 4 talleres. '
                      'Cada grupo cambia de taller cada día según la matriz '
                      'EVALÚA, INSPIRA, INNOVA y TRANSFORMA.'
                : '$n talleres y $n grupos. Cada grupo pasa cada día a un '
                      'taller distinto al que vio el día anterior.',
          ),
          const SizedBox(height: 12),
          Text('Personas por grupo', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var group = 0; group < groupCount; group++)
            Builder(
              builder: (context) {
                final teachers = teachersByGroup[group].values.toList();
                return Card(
                  child: ExpansionTile(
                    title: Text(
                      groupName(group),
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Text(
                      '${teachers.length} persona${teachers.length == 1 ? '' : 's'}',
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      if (teachers.isEmpty)
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('No hay personas asignadas.'),
                        ),
                      for (final teacher in teachers)
                        Row(
                          children: [
                            Expanded(child: Text('• ${teacher.name}')),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Recorrido: '
                          'Día 1 ${workshopNameFor(group, 0)} → '
                          'Día 2 ${workshopNameFor(group, 1)} → '
                          'Día 3 ${workshopNameFor(group, 2)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _viewActivityDocument(ActivityItem activity) async {
    if (activity.fileName.isEmpty) {
      await _showDocumentPreview(
        fileName: 'Planificación completa',
        documentContent: _loadSavedProgram(activity),
      );
      return;
    }

    await _showDocumentPreview(
      fileName: activity.fileName,
      documentContent: AuthService.getAdminActivityDocument(activity.id),
    );
  }

  Future<List<WordDocumentBlock>> _loadSavedProgram(
    ActivityItem selectedActivity,
  ) async {
    final activities = await AuthService.getActivities();
    if (!activities.any((activity) => activity.id == selectedActivity.id)) {
      activities.add(selectedActivity);
    }
    activities.sort((left, right) {
      final dateComparison = left.date.compareTo(right.date);
      if (dateComparison != 0) return dateComparison;
      return left.time.compareTo(right.time);
    });

    return [
      WordDocumentBlock(
        type: 'table',
        rows: [
          ['Fecha', 'Hora', 'Actividad', 'Responsable', 'Lugar', 'Modalidad'],
          for (final activity in activities)
            [
              activity.displayDate,
              activity.timeLabel,
              activity.activity,
              activity.responsible,
              activity.place,
              activity.modality,
            ],
        ],
      ),
    ];
  }

  Future<void> _previewSelectedWord() async {
    final file = _selectedFile;
    if (file == null) return;
    final documentContent = AuthService.previewWordDocument(file);

    await _showDocumentPreview(
      fileName: file.name,
      documentContent: documentContent,
      onSave: () => _savePreviewAgenda(documentContent, file),
    );
  }

  Future<void> _showDocumentPreview({
    required String fileName,
    required Future<List<WordDocumentBlock>> documentContent,
    Future<bool> Function()? onSave,
  }) async {
    final verticalController = ScrollController();
    final horizontalController = ScrollController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(fileName),
            content: SizedBox(
              width: (MediaQuery.of(dialogContext).size.width * 0.9)
                  .clamp(280.0, 1000.0)
                  .toDouble(),
              height: (MediaQuery.of(dialogContext).size.height * 0.65)
                  .clamp(220.0, 640.0)
                  .toDouble(),
              child: FutureBuilder<List<WordDocumentBlock>>(
                future: documentContent,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                    );
                  }

                  final blocks = snapshot.data ?? const <WordDocumentBlock>[];
                  if (blocks.isEmpty) {
                    return const Text(
                      'El documento no contiene texto para mostrar.',
                    );
                  }
                  return _buildDocumentTable(
                    blocks,
                    verticalController,
                    horizontalController,
                  );
                },
              ),
            ),
            actions: [
              if (onSave != null)
                ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          final saved = await onSave();
                          if (!dialogContext.mounted) {
                            return;
                          }
                          if (saved) {
                            Navigator.pop(dialogContext);
                          } else {
                            setDialogState(() => isSaving = false);
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt),
                  label: Text(isSaving ? 'Guardando...' : 'Guardar'),
                ),
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      },
    );
    verticalController.dispose();
    horizontalController.dispose();
  }

  Widget _buildDocumentTable(
    List<WordDocumentBlock> blocks,
    ScrollController verticalController,
    ScrollController horizontalController,
  ) {
    final agendaRows = _parseDocumentAgendaRows(blocks);

    if (agendaRows.isEmpty) {
      return const Text('El documento no contiene actividades para mostrar.');
    }

    const borderColor = Color(0xFF252525);
    const dateWidth = 100.0;
    const timeWidth = 100.0;
    const activityWidth = 280.0;
    const responsibleWidth = 220.0;
    const placeWidth = 180.0;
    const modalityWidth = 120.0;
    const tableWidth =
        dateWidth +
        timeWidth +
        activityWidth +
        responsibleWidth +
        placeWidth +
        modalityWidth;

    const gridLine = BorderSide(color: borderColor, width: 0.8);
    const tableBorder = TableBorder(
      top: gridLine,
      bottom: gridLine,
      left: gridLine,
      right: gridLine,
      horizontalInside: gridLine,
      verticalInside: gridLine,
    );

    Widget headerCell(String label) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'serif',
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget dataCell(String text, {bool centered = false}) => Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      alignment: centered ? Alignment.center : Alignment.centerLeft,
      child: SelectableText(
        text,
        textAlign: centered ? TextAlign.center : TextAlign.left,
        style: const TextStyle(fontFamily: 'serif', fontSize: 13),
      ),
    );

    final table = Table(
      border: tableBorder,
      columnWidths: {
        0: FixedColumnWidth(dateWidth),
        1: FixedColumnWidth(timeWidth),
        2: FixedColumnWidth(activityWidth),
        3: FixedColumnWidth(responsibleWidth),
        4: FixedColumnWidth(placeWidth),
        5: FixedColumnWidth(modalityWidth),
      },
      children: [
        TableRow(
          children: [
            headerCell('Fecha'),
            headerCell('Hora'),
            headerCell('Actividad'),
            headerCell('Responsable'),
            headerCell('Lugar'),
            headerCell('Modalidad'),
          ],
        ),
        for (var index = 0; index < agendaRows.length; index++)
          _buildAgendaTableRow(agendaRows, index, dataCell),
      ],
    );

    return Scrollbar(
      controller: verticalController,
      thumbVisibility: true,
      notificationPredicate: (notification) =>
          notification.depth == 1 && notification.metrics.axis == Axis.vertical,
      child: Scrollbar(
        controller: horizontalController,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.depth == 0 &&
            notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: horizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth + 16,
            child: SingleChildScrollView(
              controller: verticalController,
              padding: const EdgeInsets.only(right: 16, bottom: 16),
              child: table,
            ),
          ),
        ),
      ),
    );
  }

  TableRow _buildAgendaTableRow(
    List<_DocumentAgendaRow> agendaRows,
    int index,
    Widget Function(String text, {bool centered}) dataCell,
  ) {
    final row = agendaRows[index];
    return TableRow(
      children: [
        dataCell(row.date, centered: true),
        dataCell(row.time, centered: true),
        dataCell(row.activity),
        dataCell(row.responsible, centered: true),
        dataCell(row.place, centered: true),
        dataCell(row.modality, centered: true),
      ],
    );
  }

  List<_DocumentAgendaRow> _parseDocumentAgendaRows(
    List<WordDocumentBlock> blocks,
  ) {
    final agendaRows = <_DocumentAgendaRow>[];
    final documentHeadings = <String>[];
    String currentDate = '';
    DateTime? currentDateValue;

    for (final block in blocks) {
      if (block.type != 'table') {
        final text = block.text.trim();
        if (text.isNotEmpty) documentHeadings.add(text);
        continue;
      }

      int? headerLength;
      int? timeColumn;
      int? dateColumn;
      int? activityColumn;
      int? responsibleColumn;
      int? placeColumn;
      int? modalityColumn;

      for (final row in block.rows) {
        final cells = row.map((cell) => cell.trim()).toList();
        final normalizedCells = cells
            .map((cell) => cell.toLowerCase())
            .toList();
        final headerMatches = normalizedCells
            .where(
              (cell) =>
                  cell.length <= 20 &&
                  (cell.contains('fecha') ||
                      cell.contains('hora') ||
                      cell.contains('actividad') ||
                      cell.contains('responsable') ||
                      cell.contains('lugar') ||
                      cell.contains('modalidad')),
            )
            .length;
        final isHeader = headerMatches >= 2;
        if (isHeader) {
          headerLength = cells.length;
          dateColumn = normalizedCells.indexWhere(
            (cell) => cell.contains('fecha'),
          );
          timeColumn = normalizedCells.indexWhere(
            (cell) => cell.contains('hora'),
          );
          activityColumn = normalizedCells.indexWhere(
            (cell) => cell.contains('actividad') || cell.contains('evento'),
          );
          responsibleColumn = normalizedCells.indexWhere(
            (cell) => cell.contains('responsable'),
          );
          placeColumn = normalizedCells.indexWhere(
            (cell) => cell.contains('lugar') || cell.contains('sitio'),
          );
          modalityColumn = normalizedCells.indexWhere(
            (cell) => cell.contains('modalidad'),
          );
          continue;
        }

        // Una fecha combinada verticalmente solo aparece en la primera fila,
        // por lo que las demás filas llegan con una celda menos.
        final dateIndex = dateColumn;
        if (headerLength != null &&
            dateIndex != null &&
            dateIndex >= 0 &&
            cells.length < headerLength) {
          final missing = headerLength - cells.length;
          cells.insertAll(
            dateIndex.clamp(0, cells.length),
            List.filled(missing, ''),
          );
        }

        var parsedDate =
            dateColumn != null && dateColumn >= 0 && dateColumn < cells.length
            ? _parseDocumentDate(cells[dateColumn])
            : null;
        if (parsedDate == null) {
          for (final cell in cells) {
            if (cell.length > 40) continue;
            parsedDate = _parseDocumentDate(cell);
            if (parsedDate != null) break;
          }
        }
        if (parsedDate != null) {
          currentDateValue = parsedDate;
          currentDate =
              '${parsedDate.day.toString().padLeft(2, '0')}/'
              '${parsedDate.month.toString().padLeft(2, '0')}/'
              '${parsedDate.year}';
        }

        var parsedTime =
            timeColumn != null && timeColumn >= 0 && timeColumn < cells.length
            ? _parseDocumentTime(cells[timeColumn])
            : null;
        if (parsedTime == null) {
          for (var index = 0; index < cells.length; index++) {
            final candidate = _parseDocumentTime(cells[index]);
            if (candidate != null) {
              parsedTime = candidate;
              break;
            }
          }
        }

        final activity =
            activityColumn != null &&
                activityColumn >= 0 &&
                activityColumn < cells.length
            ? cells[activityColumn]
            : '';
        final responsible =
            responsibleColumn != null &&
                responsibleColumn >= 0 &&
                responsibleColumn < cells.length
            ? cells[responsibleColumn]
            : '';
        final place =
            placeColumn != null &&
                placeColumn >= 0 &&
                placeColumn < cells.length
            ? cells[placeColumn]
            : '';
        final modality =
            modalityColumn != null &&
                modalityColumn >= 0 &&
                modalityColumn < cells.length
            ? cells[modalityColumn]
            : '';
        if (activity.isEmpty) continue;

        agendaRows.add(
          _DocumentAgendaRow(
            date: currentDate,
            dateValue: currentDateValue,
            time: parsedTime?.label ?? '',
            startTime: parsedTime?.startTime ?? '',
            endTime: parsedTime?.endTime ?? '',
            startMinute: parsedTime?.startMinute,
            activity: activity,
            responsible: responsible,
            place: place,
            modality: modality,
          ),
        );
      }
    }

    final originalOrder = {
      for (var i = 0; i < agendaRows.length; i++) agendaRows[i]: i,
    };
    agendaRows.sort((left, right) {
      if (left.dateValue == null && right.dateValue != null) return -1;
      if (left.dateValue != null && right.dateValue == null) return 1;
      final dateComparison = (left.dateValue ?? DateTime(1)).compareTo(
        right.dateValue ?? DateTime(1),
      );
      if (dateComparison != 0) return dateComparison;
      final timeComparison = (left.startMinute ?? -1).compareTo(
        right.startMinute ?? -1,
      );
      if (timeComparison != 0) return timeComparison;
      return originalOrder[left]!.compareTo(originalOrder[right]!);
    });
    return agendaRows;
  }

  DateTime? _parseDocumentDate(String value) {
    final text = value.trim().toLowerCase();
    var match = RegExp(r'(\d{1,2})\s*[-/.]\s*(\d{1,2})\s*[-/.]\s*(\d{4})')
        .firstMatch(text);
    int day;
    int month;
    int year;
    if (match != null) {
      day = int.parse(match.group(1)!);
      month = int.parse(match.group(2)!);
      year = int.parse(match.group(3)!);
    } else {
      match = RegExp(
        r'(\d{1,2})\s*(?:de\s+)?([a-záéíóú]+)\s*(?:de|del)?\s*(\d{4})',
      ).firstMatch(text);
      const months = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ];
      if (match == null) {
        final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
        if (iso == null) return null;
        year = int.parse(iso.group(1)!);
        month = int.parse(iso.group(2)!);
        day = int.parse(iso.group(3)!);
      } else {
        var monthName = match.group(2)!;
        if (monthName == 'setiembre') monthName = 'septiembre';
        final monthIndex = months.indexOf(monthName);
        if (monthIndex < 0) return null;
        day = int.parse(match.group(1)!);
        month = monthIndex + 1;
        year = int.parse(match.group(3)!);
      }
    }
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  ({String label, int startMinute, String startTime, String? endTime})?
  _parseDocumentTime(String value) {
    final match = RegExp(
      r'(\d{1,2})\s*(?::|h|\.)\s*(\d{2})(?:\s*(?:h|hrs?\.?)?\s*(?:[-–—−]|a|al|hasta)\s*(\d{1,2})\s*(?::|h|\.)\s*(\d{2}))?',
      caseSensitive: false,
    ).firstMatch(value.trim().replaceAll('\u00a0', ' '));
    if (match == null || value.trim().length > 40) return null;

    final startHour = int.parse(match.group(1)!);
    final startMinute = int.parse(match.group(2)!);
    final endHour = match.group(3) == null ? null : int.parse(match.group(3)!);
    final endMinute = match.group(4) == null
        ? null
        : int.parse(match.group(4)!);
    if (startHour > 23 ||
        startMinute > 59 ||
        (endHour != null && endHour > 23) ||
        (endMinute != null && endMinute > 59)) {
      return null;
    }

    final start =
        '${startHour.toString().padLeft(2, '0')}:'
        '${startMinute.toString().padLeft(2, '0')}';
    if (endHour == null || endMinute == null) {
      return (
        label: start,
        startMinute: startHour * 60 + startMinute,
        startTime: start,
        endTime: null,
      );
    }
    final end =
        '${endHour.toString().padLeft(2, '0')}:'
        '${endMinute.toString().padLeft(2, '0')}';
    return (
      label: '$start–$end',
      startMinute: startHour * 60 + startMinute,
      startTime: start,
      endTime: end,
    );
  }

  Future<bool> _submitActivity() async {
    if (_isUploading) return false;

    final activity = _activityController.text.trim();
    final selectedDate = _selectedDate;
    final selectedTime = _selectedTime;
    final modality = _modalidadController.text.trim();

    if (selectedDate == null || selectedTime == null) {
      _showSnackBar('Selecciona primero la fecha y la hora.');
      return false;
    }

    if (activity.isEmpty) {
      _showSnackBar('Completa la actividad.');
      return false;
    }

    if (!mounted) return false;
    setState(() => _isUploading = true);

    try {
      await AuthService.uploadActivity(
        activity: activity,
        date: selectedDate.toIso8601String().split('T').first,
        time:
            '${selectedTime.hour.toString().padLeft(2, '0')}:'
            '${selectedTime.minute.toString().padLeft(2, '0')}',
        modality: modality,
        responsible: _responsibleController.text.trim(),
        place: _placeController.text.trim(),
        file: _selectedFile,
      );

      if (!mounted) return false;
      _activityController.clear();
      _responsibleController.clear();
      _placeController.clear();
      _dateController.clear();
      _timeController.clear();
      _modalidadController.clear();
      setState(() {
        _selectedDate = null;
        _selectedTime = null;
        _selectedFile = null;
      });
      await _refreshData();
      _showSnackBar('Actividad cargada correctamente.');
      return true;
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<bool> _savePreviewAgenda(
    Future<List<WordDocumentBlock>> documentContent,
    PlatformFile file,
  ) async {
    if (_isUploading) return false;

    try {
      final rows = _parseDocumentAgendaRows(await documentContent);
      if (rows.isEmpty) {
        _showSnackBar('El documento no contiene actividades para guardar.');
        return false;
      }
      final invalidRow = rows
          .where((row) => row.dateValue == null || row.startTime.isEmpty)
          .firstOrNull;
      if (invalidRow != null) {
        final summary = invalidRow.activity.replaceAll('\n', ' ');
        _showSnackBar(
          'Falta una fecha u hora válida en: '
          '"${summary.length > 60 ? '${summary.substring(0, 60)}…' : summary}"'
          ' (fecha: ${invalidRow.date.isEmpty ? 'vacía' : invalidRow.date}, '
          'hora: ${invalidRow.time.isEmpty ? 'vacía' : invalidRow.time}).',
        );
        return false;
      }

      if (!mounted) return false;
      setState(() => _isUploading = true);
      final savedCount = await AuthService.saveActivityBatch(
        activities: rows
            .map(
              (row) => {
                'activity': row.activity,
                'date': row.dateValue!.toIso8601String().split('T').first,
                'time': row.startTime,
                'timeEnd': row.endTime.isEmpty ? null : row.endTime,
                'responsible': row.responsible,
                'place': row.place,
                'modality': row.modality,
              },
            )
            .toList(),
        file: file,
      );

      if (!mounted) return false;
      if (mounted) setState(() => _selectedFile = null);
      await _refreshData();
      _showSnackBar('Se guardaron $savedCount actividades del documento.');
      return true;
    } catch (error) {
      _showSnackBar(error.toString().replaceFirst('Exception: ', ''));
      return false;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    final controller = context.read<AuthController>();
    await controller.logout();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de administración'),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            indicatorPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Color(0xFF075044),
            unselectedLabelColor: Colors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600),
            overlayColor: WidgetStatePropertyAll(Color(0x33FFFFFF)),
            tabs: [
              Tab(icon: Icon(Icons.event_note_outlined), text: 'Actividades'),
              Tab(icon: Icon(Icons.upload_file_outlined), text: 'Subir'),
              Tab(icon: Icon(Icons.people_outline), text: 'Usuarios'),
              Tab(icon: Icon(Icons.groups_outlined), text: 'Talleres'),
              Tab(icon: Icon(Icons.fact_check_outlined), text: 'Asistencia'),
              Tab(
                icon: Icon(Icons.record_voice_over_outlined),
                text: 'Conferencistas',
              ),
              Tab(
                icon: Icon(Icons.dashboard_customize_outlined),
                text: 'Secciones',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  FutureBuilder<List<ActivityItem>>(
                    future: _activities,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }

                      final activities =
                          snapshot.data ?? const <ActivityItem>[];
                      final activitiesByDate = <String, List<ActivityItem>>{};
                      for (final activity in activities) {
                        activitiesByDate
                            .putIfAbsent(activity.displayDate, () => [])
                            .add(activity);
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Actividades cargadas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (activities.isEmpty)
                            const Text('Todavía no hay actividades cargadas.')
                          else
                            ...activitiesByDate.entries.map(
                              (entry) => Card(
                                child: ExpansionTile(
                                  leading: const Icon(
                                    Icons.calendar_month_outlined,
                                  ),
                                  title: Text(entry.key),
                                  subtitle: Text(
                                    '${entry.value.length} '
                                    '${entry.value.length == 1 ? 'actividad' : 'actividades'}',
                                  ),
                                  children: [
                                    for (final activity in entry.value)
                                      ListTile(
                                        title: Text(activity.activity),
                                        subtitle: Text(
                                          [
                                            activity.timeLabel,
                                            if (activity.responsible.isNotEmpty)
                                              'Responsable: ${activity.responsible}',
                                            if (activity.place.isNotEmpty)
                                              'Lugar: ${activity.place}',
                                            if (activity.modality.isNotEmpty)
                                              'Modalidad: ${activity.modality}',
                                          ].join('\n'),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              tooltip:
                                                  activity.fileName.isNotEmpty
                                                  ? 'Ver documento Word'
                                                  : 'Ver actividad',
                                              icon: const Icon(
                                                Icons.visibility_outlined,
                                              ),
                                              onPressed: () =>
                                                  _viewActivityDocument(
                                                    activity,
                                                  ),
                                            ),
                                            IconButton(
                                              tooltip: 'Editar actividad',
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                              ),
                                              onPressed: () =>
                                                  _editActivity(activity),
                                            ),
                                            IconButton(
                                              tooltip: 'Eliminar actividad',
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              onPressed: () =>
                                                  _deleteActivity(activity),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Subir actividad',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _dateController,
                            readOnly: true,
                            onTap: _selectDate,
                            decoration: const InputDecoration(
                              labelText: 'Fecha de la actividad',
                              hintText: 'Seleccionar fecha',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_month_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _timeController,
                            readOnly: true,
                            enabled: _selectedDate != null,
                            onTap: _selectTime,
                            decoration: const InputDecoration(
                              labelText: 'Hora de la actividad',
                              hintText: 'Selecciona primero la fecha',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.access_time_outlined),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _activityController,
                            decoration: const InputDecoration(
                              labelText: 'Actividad',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _responsibleController,
                            decoration: const InputDecoration(
                              labelText: 'Responsable',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _placeController,
                            decoration: const InputDecoration(
                              labelText: 'Lugar',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _modalidadController,
                            decoration: const InputDecoration(
                              labelText: 'Modalidad',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _pickWordFile,
                                    icon: const Icon(Icons.upload_file),
                                    label: Text(
                                      _selectedFile == null
                                          ? 'Seleccionar archivo Word'
                                          : _selectedFile!.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                if (_selectedFile != null)
                                  IconButton(
                                    tooltip: 'Visualizar archivo seleccionado',
                                    onPressed: _isUploading
                                        ? null
                                        : _previewSelectedWord,
                                    icon: const Icon(Icons.visibility_outlined),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isUploading ? null : _submitActivity,
                              icon: _isUploading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_alt),
                              label: Text(
                                _isUploading
                                    ? 'Guardando...'
                                    : 'Guardar actividad',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  FutureBuilder<List<UserModel>>(
                    future: _users,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text(snapshot.error.toString()));
                      }

                      final users = snapshot.data ?? const <UserModel>[];
                      final pendingTeacherCount = users
                          .where(
                            (user) =>
                                user.isTeacher && user.passwordSetupRequired,
                          )
                          .length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Usuarios',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text('${users.length} cuentas registradas'),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isManagingUsers
                                    ? null
                                    : _createAdminUser,
                                icon: const Icon(Icons.person_add_alt_1),
                                label: const Text('Agregar uno'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isManagingUsers
                                    ? null
                                    : _importAdminUsersFromWord,
                                icon: _isManagingUsers
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.upload_file),
                                label: Text(
                                  _isManagingUsers
                                      ? 'Importando...'
                                      : 'Importar desde Word',
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    showAllTeachersQrDialog(context, users),
                                icon: const Icon(Icons.qr_code_2),
                                label: const Text('QR de todos los docentes'),
                              ),
                              if (pendingTeacherCount > 0)
                                OutlinedButton.icon(
                                  onPressed: _isManagingUsers
                                      ? null
                                      : () => _sendPendingTeacherInvitations(
                                          pendingTeacherCount,
                                        ),
                                  icon: _isSendingInvitations
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.mark_email_read_outlined,
                                        ),
                                  label: Text(
                                    _isSendingInvitations
                                        ? 'Enviando...'
                                        : 'Enviar invitaciones ($pendingTeacherCount)',
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Para importar, el DOCX debe tener una tabla con las columnas "Nombre" y "Correo electrónico".',
                          ),
                          const SizedBox(height: 16),
                          for (final user in users)
                            ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  user.name.isEmpty
                                      ? '?'
                                      : user.name[0].toUpperCase(),
                                ),
                              ),
                              title: Text(user.name),
                              subtitle: Text(
                                '${user.email}\n${user.roleLabel}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Opciones de usuario',
                                enabled: !_isManagingUsers,
                                onSelected: (action) {
                                  if (action == 'invite') {
                                    _sendTeacherInvitation(user);
                                  } else if (action == 'qr') {
                                    showQrDialog(
                                      context,
                                      title: user.name,
                                      data: userQrData(user),
                                      caption: user.email,
                                    );
                                  } else if (action == 'edit') {
                                    _editUser(user);
                                  } else if (action == 'delete') {
                                    _deleteUser(user);
                                  }
                                },
                                itemBuilder: (context) => [
                                  if (!user.isAdmin &&
                                      user.passwordSetupRequired)
                                    const PopupMenuItem(
                                      value: 'invite',
                                      child: ListTile(
                                        leading: Icon(
                                          Icons.mark_email_read_outlined,
                                        ),
                                        title: Text('Enviar invitación'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  const PopupMenuItem(
                                    value: 'qr',
                                    child: ListTile(
                                      leading: Icon(Icons.qr_code_2),
                                      title: Text('Generar QR'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: ListTile(
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('Actualizar'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: ListTile(
                                      leading: Icon(Icons.delete_outline),
                                      title: Text('Eliminar'),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Talleres',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Crea los talleres, indica el cupo diario y asigna docentes.',
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _isManagingWorkshops
                          ? null
                          : () => _saveWorkshopTitle(),
                      icon: const Icon(Icons.add),
                      label: const Text('Crear taller'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<WorkshopItem>>(
                    future: _workshops,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Text(
                          'No se pudieron cargar los talleres: ${snapshot.error}',
                        );
                      }

                      final workshops = snapshot.data ?? const <WorkshopItem>[];
                      return Column(
                        children: [
                          if (workshops.isEmpty)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Todavía no hay talleres creados.'),
                            ),
                          for (final workshop in workshops)
                            Card(
                              child: ExpansionTile(
                                leading: const Icon(Icons.school_outlined),
                                title: Text(workshop.title),
                                subtitle: Text(
                                  '${workshop.teachers.length} '
                                  '${workshop.teachers.length == 1 ? 'docente asignado' : 'docentes asignados'} · '
                                  '${workshop.address.isEmpty ? 'Sin dirección' : workshop.address}',
                                ),
                                trailing: PopupMenuButton<String>(
                                  tooltip: 'Configuración del taller',
                                  enabled: !_isManagingWorkshops,
                                  onSelected: (action) {
                                    if (action == 'assign') {
                                      _assignWorkshopTeachers(workshop);
                                    } else if (action == 'edit') {
                                      _saveWorkshopTitle(workshop: workshop);
                                    } else if (action == 'delete') {
                                      _deleteWorkshop(workshop);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem(
                                      value: 'assign',
                                      child: ListTile(
                                        leading: Icon(Icons.person_add_alt_1),
                                        title: Text('Asignar docentes'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: ListTile(
                                        leading: Icon(Icons.edit_outlined),
                                        title: Text('Editar taller'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: ListTile(
                                        leading: Icon(Icons.delete_outline),
                                        title: Text('Eliminar taller'),
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                                children: [
                                  ListTile(
                                    dense: true,
                                    title: Text(
                                      'Cupo diario: ${workshop.capacity} personas',
                                    ),
                                    subtitle: Text(
                                      '${workshop.dayTimes.isEmpty ? 'Sin horario' : [for (var d = 0; d < workshop.dayTimes.length; d++) workshop.dayLabel(d)].join(' | ')}\n'
                                      '${workshop.address.isEmpty ? 'Sin dirección' : workshop.address} · ${workshop.room.isEmpty ? 'Sin aula' : workshop.room}',
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  if (workshop.teachers.isEmpty)
                                    const ListTile(
                                      dense: true,
                                      title: Text('Sin docentes asignados'),
                                    )
                                  else
                                    for (final teacher in workshop.teachers)
                                      ListTile(
                                        dense: true,
                                        leading: const Icon(
                                          Icons.person_outline,
                                        ),
                                        title: Text(teacher.name),
                                        subtitle: Text(teacher.email),
                                        trailing: IconButton(
                                          tooltip: 'Quitar del taller',
                                          onPressed: _isManagingWorkshops
                                              ? null
                                              : () => _removeWorkshopTeacher(
                                                  workshop,
                                                  teacher,
                                                ),
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                        ),
                                      ),
                                ],
                              ),
                            ),
                          _buildRotationOverview(workshops),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const AdminAttendanceTab(),
            const AdminSpeakersTab(),
            const AdminSectionsTab(),
          ],
        ),
      ),
    );
  }
}
