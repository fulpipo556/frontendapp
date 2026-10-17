import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class AdminAttendanceTab extends StatefulWidget {
  const AdminAttendanceTab({super.key});

  @override
  State<AdminAttendanceTab> createState() => _AdminAttendanceTabState();
}

class _AdminAttendanceTabState extends State<AdminAttendanceTab> {
  late Future<AttendanceDay> _attendance;
  String? _selectedDate;
  String? _scheduleDate;
  bool _isUpdating = false;
  bool _isDeletingDay = false;

  @override
  void initState() {
    super.initState();
    _attendance = AuthService.getAdminAttendanceDay();
  }

  void _selectDate(String date) {
    setState(() {
      _selectedDate = date;
      _scheduleDate = date;
      _attendance = AuthService.getAdminAttendanceDay(date);
    });
  }

  Future<void> _selectScheduleDate() async {
    final initialDate = _scheduleDate == null
        ? DateTime.now()
        : DateTime.parse(_scheduleDate!);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Seleccione la fecha del horario',
      cancelText: 'Cancelar',
      confirmText: 'Continuar',
    );
    if (picked == null || !mounted) return;
    final date =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    _selectDate(date);
  }

  Future<void> _refresh() async {
    final attendance = AuthService.getAdminAttendanceDay(_selectedDate);
    setState(() {
      _attendance = attendance;
    });
    await attendance;
  }

  Future<void> _toggleRecord(
    AttendanceRow row,
    String kind,
    String date,
    bool isRegistered,
  ) async {
    final label = kind == 'attendance' ? 'asistencia' : 'coffee break';
    if (isRegistered) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Quitar registro'),
          content: Text('¿Quitar $label de ${row.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Quitar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Registrar $label'),
          content: Text(
            '¿Registrar $label para ${row.name} el ${_shortDate(date)}? '
            'Se guardará en el mismo registro oficial que se crea al escanear '
            'el código QR del docente. Se usará la fecha seleccionada y la '
            'hora actual.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Registrar'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isUpdating = true);
    try {
      final changed = await AuthService.setAdminAttendance(
        userId: row.id,
        kind: kind,
        date: date,
        registered: !isRegistered,
      );
      if (!mounted) return;
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              !changed
                  ? '${row.name} ya tenía registrado el $label para el ${_shortDate(date)}.'
                  : isRegistered
                  ? 'Se quitó el registro de $label de ${row.name}.'
                  : 'Se registró el $label de ${row.name} el ${_shortDate(date)} en el mismo registro que usa el escaneo QR.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _deleteDay(String date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Quitar día del seminario'),
        content: Text(
          'Se eliminarán las actividades y todos los registros de asistencia '
          'y coffee break del ${_shortDate(date)}. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar día'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeletingDay = true);
    try {
      await AuthService.deleteAttendanceDay(date);
      if (!mounted) return;
      final attendance = AuthService.getAdminAttendanceDay(
        _selectedDate == date ? null : _selectedDate,
      );
      setState(() {
        if (_selectedDate == date) _selectedDate = null;
        if (_scheduleDate == date) _scheduleDate = null;
        _attendance = attendance;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se eliminó el día ${_shortDate(date)}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeletingDay = false);
    }
  }

  String _shortDate(String value) {
    final parts = value.split('-');
    return parts.length == 3 ? '${parts[2]}/${parts[1]}' : value;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<AttendanceDay>(
        future: _attendance,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'No se pudo cargar el registro: '
                  '${snapshot.error.toString().replaceFirst('Exception: ', '')}',
                ),
              ],
            );
          }

          final day = snapshot.data!;
          final present = day.rows
              .where((row) => row.attendanceTime != null)
              .length;
          final breaks = day.rows.where((row) => row.breakTime != null).length;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Registro de asistencia y coffee break',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Seleccione una fecha para crear o editar el horario '
                          'de asistencia y coffee break.',
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: !_isUpdating && !_isDeletingDay
                            ? _selectScheduleDate
                            : null,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          _scheduleDate == null
                              ? 'Elegir fecha'
                              : _shortDate(_scheduleDate!),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_scheduleDate != null && _scheduleDate == day.date)
                _ScheduleEditor(
                  date: day.date,
                  schedules: day.schedules,
                  enabled: !_isUpdating && !_isDeletingDay,
                  onSaved: _refresh,
                ),
              const SizedBox(height: 12),
              if (day.days.isNotEmpty)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final date in day.days)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            label: Text(
                              date == day.today
                                  ? 'Hoy ${_shortDate(date)}'
                                  : _shortDate(date),
                            ),
                            selected: date == day.date,
                            onPressed: () => _selectDate(date),
                            onDeleted: _isDeletingDay || _isUpdating
                                ? null
                                : () => _deleteDay(date),
                            deleteButtonTooltipMessage:
                                'Quitar día y sus datos',
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _AttendanceCount(
                        label: 'Asistencia',
                        count: present,
                        total: day.totalTeachers,
                        icon: Icons.how_to_reg_outlined,
                      ),
                      _AttendanceCount(
                        label: 'Coffee break',
                        count: breaks,
                        total: day.totalTeachers,
                        icon: Icons.coffee_outlined,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (day.rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('No hay registros para la fecha seleccionada.'),
                  ),
                ),
              for (final row in day.rows)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(row.name),
                          subtitle: Text(row.email),
                        ),
                        _AttendanceRecordControl(
                          label: 'Asistencia',
                          time: row.attendanceTime,
                          icon: Icons.how_to_reg_outlined,
                          enabled: !_isUpdating && !_isDeletingDay,
                          onToggle: () => _toggleRecord(
                            row,
                            'attendance',
                            day.date,
                            row.attendanceTime != null,
                          ),
                        ),
                        _AttendanceRecordControl(
                          label: 'Coffee break',
                          time: row.breakTime,
                          icon: Icons.coffee_outlined,
                          enabled: !_isUpdating && !_isDeletingDay,
                          onToggle: () => _toggleRecord(
                            row,
                            'break',
                            day.date,
                            row.breakTime != null,
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
    );
  }
}

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({
    required this.date,
    required this.schedules,
    required this.enabled,
    required this.onSaved,
  });

  final String date;
  final List<AttendanceSchedule> schedules;
  final bool enabled;
  final Future<void> Function() onSaved;

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late List<AttendanceSchedule> _schedules;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _setValues();
  }

  @override
  void didUpdateWidget(covariant _ScheduleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date ||
        oldWidget.schedules != widget.schedules) {
      _setValues();
    }
  }

  void _setValues() {
    _schedules = widget.schedules.isEmpty
        ? [
            const AttendanceSchedule(
              attendanceStart: '08:00',
              attendanceEnd: '10:00',
              breakStart: '10:00',
              breakEnd: '11:00',
            ),
          ]
        : List.of(widget.schedules);
  }

  Future<void> _pick(int index, String field, String current) async {
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final old = _schedules[index];
    final updated = AttendanceSchedule(
      attendanceStart: field == 'attendanceStart' ? value : old.attendanceStart,
      attendanceEnd: field == 'attendanceEnd' ? value : old.attendanceEnd,
      breakStart: field == 'breakStart' ? value : old.breakStart,
      breakEnd: field == 'breakEnd' ? value : old.breakEnd,
      attendanceEnabled: old.attendanceEnabled,
      breakEnabled: old.breakEnabled,
    );
    setState(() => _schedules[index] = updated);
  }

  void _toggleKind(int index, String kind, bool enabled) {
    final old = _schedules[index];
    if (!enabled &&
        ((kind == 'attendance' && !old.breakEnabled) ||
            (kind == 'break' && !old.attendanceEnabled))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe quedar habilitada al menos una opción por franja.'),
        ),
      );
      return;
    }
    final updated = AttendanceSchedule(
      attendanceStart: old.attendanceStart,
      attendanceEnd: old.attendanceEnd,
      breakStart: old.breakStart,
      breakEnd: old.breakEnd,
      attendanceEnabled:
          kind == 'attendance' ? enabled : old.attendanceEnabled,
      breakEnabled: kind == 'break' ? enabled : old.breakEnabled,
    );
    setState(() => _schedules[index] = updated);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AuthService.saveAdminAttendanceSchedule(
        date: widget.date,
        schedules: _schedules,
      );
      if (!mounted) return;
      await widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horario guardado correctamente.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _timeButton(
    int index,
    String label,
    String field,
    String value, {
    required bool enabled,
  }) {
    return OutlinedButton.icon(
      onPressed: widget.enabled && !_saving && enabled
          ? () => _pick(index, field, value)
          : null,
      icon: const Icon(Icons.schedule, size: 18),
      label: Text('$label: $value'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horario de control (${widget.date})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            const Text(
              'El QR permanece visible, pero el registrador solo podrá escanear '
              'cada tipo dentro de su horario.',
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < _schedules.length; index++)
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Franja ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: _schedules[index].attendanceEnabled,
                            onChanged: widget.enabled && !_saving
                                ? (value) =>
                                    _toggleKind(index, 'attendance', value)
                                : null,
                          ),
                          const Text('Asistencia'),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: _schedules[index].breakEnabled,
                            onChanged: widget.enabled && !_saving
                                ? (value) => _toggleKind(index, 'break', value)
                                : null,
                          ),
                          const Text('Coffee break'),
                        ],
                      ),
                      _timeButton(
                        index,
                        'Asistencia desde',
                        'attendanceStart',
                        _schedules[index].attendanceStart,
                        enabled: _schedules[index].attendanceEnabled,
                      ),
                      _timeButton(
                        index,
                        'Asistencia hasta',
                        'attendanceEnd',
                        _schedules[index].attendanceEnd,
                        enabled: _schedules[index].attendanceEnabled,
                      ),
                      _timeButton(
                        index,
                        'Coffee desde',
                        'breakStart',
                        _schedules[index].breakStart,
                        enabled: _schedules[index].breakEnabled,
                      ),
                      _timeButton(
                        index,
                        'Coffee hasta',
                        'breakEnd',
                        _schedules[index].breakEnd,
                        enabled: _schedules[index].breakEnabled,
                      ),
                      if (_schedules.length > 1)
                        OutlinedButton.icon(
                          onPressed: widget.enabled && !_saving
                              ? () => setState(() => _schedules.removeAt(index))
                              : null,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Quitar franja'),
                        ),
                    ],
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: widget.enabled && !_saving
                  ? () => setState(
                      () => _schedules.add(
                        const AttendanceSchedule(
                          attendanceStart: '08:00',
                          attendanceEnd: '10:00',
                          breakStart: '10:00',
                          breakEnd: '11:00',
                        ),
                      ),
                    )
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('Agregar otra franja'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: widget.enabled && !_saving ? _save : null,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Guardar horario'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRecordControl extends StatelessWidget {
  const _AttendanceRecordControl({
    required this.label,
    required this.time,
    required this.icon,
    required this.enabled,
    required this.onToggle,
  });

  final String label;
  final String? time;
  final IconData icon;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isRegistered = time != null;
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0D5C4D)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: ${time ?? 'Sin registro'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (isRegistered)
          OutlinedButton.icon(
            onPressed: enabled ? onToggle : null,
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            label: const Text('Quitar'),
          )
        else
          IconButton(
            tooltip: 'Registrar $label',
            onPressed: enabled ? onToggle : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
      ],
    );
  }
}

class _AttendanceCount extends StatelessWidget {
  const _AttendanceCount({
    required this.label,
    required this.count,
    required this.total,
    required this.icon,
  });

  final String label;
  final int count;
  final int total;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF0D5C4D)),
        const SizedBox(width: 8),
        Text('$label: $count de $total'),
      ],
    );
  }
}
