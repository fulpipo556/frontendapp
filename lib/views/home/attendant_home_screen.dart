import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';

const _green = Color(0xFF075044);

class AttendantHomeScreen extends StatefulWidget {
  const AttendantHomeScreen({super.key});

  @override
  State<AttendantHomeScreen> createState() => _AttendantHomeScreenState();
}

class _AttendantHomeScreenState extends State<AttendantHomeScreen> {
  final MobileScannerController _scanner = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  late Future<AttendanceDay> _rows;
  String? _selectedDay;

  String _kind = 'attendance';
  bool _processing = false;
  String? _lastCode;
  DateTime _lastScanAt = DateTime.fromMillisecondsSinceEpoch(0);
  _ScanFeedback? _feedback;

  String get _kindLabel =>
      _kind == 'attendance' ? 'Asistencia' : 'Coffee break';

  @override
  void initState() {
    super.initState();
    _rows = AuthService.getAttendanceDay();
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() => _rows = AuthService.getAttendanceDay(_selectedDay));
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    await context.read<AuthController>().logout();
    if (!mounted) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || _processing) return;
    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastScanAt).inSeconds < 3) return;
    _lastCode = code;
    _lastScanAt = now;
    await _register(
      () => AuthService.registerAttendance(kind: _kind, code: code),
    );
  }

  Future<void> _register(Future<AttendanceScanResult> Function() action) async {
    setState(() => _processing = true);
    _ScanFeedback feedback;
    try {
      final result = await action();
      feedback = _ScanFeedback(
        result.alreadyRegistered
            ? '${result.name}\nya registró hoy $_kindLabel'
            : '${result.name}\n$_kindLabel registrado',
        result.alreadyRegistered ? Colors.orange : Colors.green,
        result.alreadyRegistered ? Icons.info_outline : Icons.check_circle,
      );
    } catch (error) {
      feedback = _ScanFeedback(
        error.toString().replaceFirst('Exception: ', ''),
        Colors.red,
        Icons.error_outline,
      );
    }
    if (!mounted) return;
    setState(() {
      _processing = false;
      _feedback = feedback;
    });
    _refresh();
  }

  Widget _kindSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'attendance',
            icon: Icon(Icons.how_to_reg),
            label: Text('Asistencia'),
          ),
          ButtonSegment(
            value: 'break',
            icon: Icon(Icons.coffee_outlined),
            label: Text('Coffee break'),
          ),
        ],
        selected: {_kind},
        onSelectionChanged: (value) => setState(() {
          _kind = value.first;
          _feedback = null;
        }),
      ),
    );
  }

  Widget _scannerTab() {
    return Column(
      children: [
        _kindSelector(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scanner,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No se pudo abrir la cámara. Revisa el permiso de cámara del dispositivo.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                    ),
                  ),
                  if (_processing)
                    const ColoredBox(
                      color: Color(0x66000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_feedback != null)
          Container(
            key: const Key('scan_feedback'),
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _feedback!.color.withValues(alpha: 0.15),
              border: Border.all(color: _feedback!.color),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(_feedback!.icon, color: _feedback!.color),
                const SizedBox(width: 12),
                Expanded(child: Text(_feedback!.message)),
              ],
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text('Apunta la cámara al QR del docente'),
          ),
      ],
    );
  }

  Widget _listTab() {
    return RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await _rows;
      },
      child: FutureBuilder<AttendanceDay>(
        future: _rows,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                  ),
                ),
              ],
            );
          }
          final day = snapshot.data!;
          final rows = day.rows;
          final present = rows
              .where((row) => row.attendanceTime != null)
              .length;
          final breaks = rows.where((row) => row.breakTime != null).length;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final value in day.days)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            value == day.today
                                ? 'Hoy ${_shortDate(value)}'
                                : _shortDate(value),
                          ),
                          selected: value == day.date,
                          onSelected: (_) => _selectDay(value),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$present de ${day.totalTeachers} docentes con asistencia · $breaks con coffee break',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Aún no hay docentes registrados este día'),
                  ),
                ),
              for (final row in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(row.name),
                  subtitle: Text(
                    'Asistencia: ${row.attendanceTime ?? '—'}   ·   Break: ${row.breakTime ?? '—'}',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  String _shortDate(String value) {
    final parts = value.split('-');
    return parts.length == 3 ? '${parts[2]}/${parts[1]}' : value;
  }

  void _selectDay(String value) {
    setState(() {
      _selectedDay = value;
      _rows = AuthService.getAttendanceDay(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          title: const Text('Registro de asistencia'),
          actions: [
            IconButton(
              tooltip: 'Cerrar sesión',
              icon: const Icon(Icons.logout),
              onPressed: _logout,
            ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'Escáner'),
              Tab(icon: Icon(Icons.list_alt), text: 'Registrados'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [_scannerTab(), _listTab()],
        ),
      ),
    );
  }
}

class _ScanFeedback {
  const _ScanFeedback(this.message, this.color, this.icon);

  final String message;
  final Color color;
  final IconData icon;
}
