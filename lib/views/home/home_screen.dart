import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../controllers/auth_controller.dart';
import '../../services/auth_service.dart';
import '../auth/login_screen.dart';
import 'live_qr.dart';

String seminarDateRangeLabel(List<ActivityItem> activities) {
  final dates =
      activities
          .map((activity) => DateTime.tryParse(activity.date.split('T').first))
          .whereType<DateTime>()
          .toList()
        ..sort();

  if (dates.isEmpty) return 'Fechas por definir · Jipijapa, EC';

  const monthNames = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  String formatDate(DateTime date) =>
      '${date.day} ${monthNames[date.month - 1]} ${date.year}';

  final start = dates.first;
  final end = dates.last;
  final dateRange =
      start.year == end.year && start.month == end.month && start.day == end.day
      ? formatDate(start)
      : start.year == end.year && start.month == end.month
      ? 'Del ${start.day} al ${end.day} '
            '${monthNames[end.month - 1]} ${end.year}'
      : start.year == end.year
      ? 'Del ${start.day} ${monthNames[start.month - 1]} al '
            '${end.day} ${monthNames[end.month - 1]} ${end.year}'
      : 'Del ${formatDate(start)} al ${formatDate(end)}';
  return '$dateRange · Jipijapa, EC';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _selectedDay = DateTime.now().day;
  String _selectedTab = 'inicio';
  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;
  late Future<List<ActivityItem>> _activities;
  late Future<List<WorkshopItem>> _myWorkshops;
  late Future<SpeakerList> _speakers;
  late Future<List<ContentSection>> _sections;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleClockUpdate();
    _activities = AuthService.getActivities();
    _myWorkshops = AuthService.getMyWorkshops();
    _speakers = AuthService.getSpeakers();
    _sections = AuthService.getContentSections();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshClock();
    }
  }

  void _refreshClock() {
    _clockTimer?.cancel();
    setState(() => _currentTime = DateTime.now());
    _scheduleClockUpdate();
  }

  void _scheduleClockUpdate() {
    final now = DateTime.now();
    _clockTimer = Timer(Duration(seconds: 60 - now.second), () {
      if (!mounted) return;
      setState(() => _currentTime = DateTime.now());
      _scheduleClockUpdate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    super.dispose();
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
      final daysInMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
      ).day;
      if (_selectedDay > daysInMonth) {
        _selectedDay = daysInMonth;
      }
    });
  }

  void _openAgenda() {
    setState(() {
      _selectedTab = 'agenda';
      _activities = AuthService.getActivities();
    });
  }

  void _refreshActivities() {
    setState(() => _activities = AuthService.getActivities());
  }

  Future<void> _openSectionVideo(ContentSection section) async {
    if (section.videoLink.isEmpty) return;
    final opened = await launchUrl(Uri.parse(section.videoLink));
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el video.')),
      );
    }
  }

  String get _monthLabel {
    const monthNames = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';
  }

  List<int?> _buildCalendarDays(DateTime month) {
    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = firstDayOfMonth.weekday - 1;

    final days = List<int?>.filled(42, null);
    for (int day = 1; day <= daysInMonth; day++) {
      days[leadingBlanks + day - 1] = day;
    }
    return days;
  }

  String get _eventDateLabel {
    const monthNames = [
      'ENERO',
      'FEBRERO',
      'MARZO',
      'ABRIL',
      'MAYO',
      'JUNIO',
      'JULIO',
      'AGOSTO',
      'SEPTIEMBRE',
      'OCTUBRE',
      'NOVIEMBRE',
      'DICIEMBRE',
    ];
    return '${monthNames[_selectedMonth.month - 1]} $_selectedDay, '
        '${_selectedMonth.year}';
  }

  DateTime? _activityDate(ActivityItem activity) {
    return DateTime.tryParse(activity.date.split('T').first);
  }

  bool _hasActivitiesOn(List<ActivityItem> activities, DateTime date) {
    return activities.any((activity) {
      final activityDate = _activityDate(activity);
      return activityDate != null &&
          activityDate.year == date.year &&
          activityDate.month == date.month &&
          activityDate.day == date.day;
    });
  }

  List<ActivityItem> _activitiesOn(
    List<ActivityItem> activities,
    DateTime date,
  ) {
    final matchingActivities = activities.where((activity) {
      final activityDate = _activityDate(activity);
      return activityDate != null &&
          activityDate.year == date.year &&
          activityDate.month == date.month &&
          activityDate.day == date.day;
    }).toList();
    matchingActivities.sort((left, right) => left.time.compareTo(right.time));
    return matchingActivities;
  }

  Widget _buildSectionHeader({
    required String subtitle,
    required String title,
    VoidCallback? onRefresh,
    Widget? subtitleContent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: const BoxDecoration(color: Color(0xFF0B5E49)),
      child: Column(
        children: [
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                TimeOfDay.fromDateTime(_currentTime).format(context),
                key: const ValueKey('device_clock'),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.signal_cellular_4_bar,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.signal_wifi_4_bar, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Icon(
                    Icons.battery_full_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child:
                    subtitleContent ??
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xE6F4F2EE),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
              if (onRefresh != null) ...[
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: onRefresh,
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 14),
              ],
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: () async {
                  final controller = context.read<AuthController>();
                  final navigator = Navigator.of(context);
                  await controller.logout();
                  if (!mounted) return;
                  navigator.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _refreshWorkshops() {
    setState(() => _myWorkshops = AuthService.getMyWorkshops());
  }

  void _refreshSpeakers() {
    setState(() => _speakers = AuthService.getSpeakers());
  }

  Future<void> _openSpeakerCv(SpeakerItem speaker) async {
    if (speaker.cvUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No hay hoja de vida para ${speaker.name}.')),
      );
      return;
    }

    final opened = await launchUrl(
      Uri.parse(speaker.cvUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir la hoja de vida de ${speaker.name}.'),
        ),
      );
    }
  }

  Widget _buildSpeakersContent() {
    return FutureBuilder<SpeakerList>(
      future: _speakers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudieron cargar los ponentes: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final speakers = snapshot.data?.speakers ?? const <SpeakerItem>[];
        if (speakers.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Aún no hay ponentes registrados.'),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final speaker in speakers)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: const Color(0xFFD5E7E0),
                        foregroundImage: speaker.photoPath.isEmpty
                            ? null
                            : NetworkImage(speaker.photoUrl),
                        onForegroundImageError: speaker.photoPath.isEmpty
                            ? null
                            : (_, _) {},
                        child: Text(
                          speaker.name.isEmpty
                              ? '?'
                              : speaker.name.characters.first.toUpperCase(),
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        speaker.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (speaker.hasCv)
                        TextButton.icon(
                          onPressed: () => _openSpeakerCv(speaker),
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('Ver hoja de vida'),
                        )
                      else
                        const Text('Hoja de vida no disponible'),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAgendaContent(BuildContext context) {
    final days = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];
    final calendarDays = _buildCalendarDays(_selectedMonth);

    return SafeArea(
      child: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0C2B23),
                  blurRadius: 15,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSectionHeader(
                      subtitle: 'Agenda de conferencias',
                      title: 'Calendario',
                      onRefresh: _refreshActivities,
                    ),
                    Container(
                      color: const Color(0xFFF7F8F7),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 36,
                                child: IconButton(
                                  key: const ValueKey('month_prev_button'),
                                  onPressed: () => _changeMonth(-1),
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    color: Color(0xFF1E2A28),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _monthLabel,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF1E2A28),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 36,
                                child: IconButton(
                                  key: const ValueKey('month_next_button'),
                                  onPressed: () => _changeMonth(1),
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF1E2A28),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: days
                                .map(
                                  (day) => SizedBox(
                                    width: 28,
                                    child: Text(
                                      day,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF576D69),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<List<ActivityItem>>(
                            future: _activities,
                            builder: (context, snapshot) {
                              final activities =
                                  snapshot.data ?? const <ActivityItem>[];
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: calendarDays.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 7,
                                      childAspectRatio: 1.12,
                                      mainAxisSpacing: 8,
                                      crossAxisSpacing: 6,
                                    ),
                                itemBuilder: (context, index) {
                                  final day = calendarDays[index];
                                  final isSelected = day == _selectedDay;
                                  final hasActivities =
                                      day != null &&
                                      _hasActivitiesOn(
                                        activities,
                                        DateTime(
                                          _selectedMonth.year,
                                          _selectedMonth.month,
                                          day,
                                        ),
                                      );

                                  return Center(
                                    child: SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: day == null
                                            ? null
                                            : () => setState(
                                                () => _selectedDay = day,
                                              ),
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              width: 28,
                                              height: 28,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? const Color(0xFF0D5C4D)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: day == null
                                                  ? const SizedBox.shrink()
                                                  : Text(
                                                      '$day',
                                                      style: TextStyle(
                                                        color: isSelected
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF2A302F,
                                                              ),
                                                        fontSize: 12,
                                                        fontWeight: isSelected
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                      ),
                                                    ),
                                            ),
                                            if (hasActivities)
                                              Positioned(
                                                bottom: 0,
                                                child: Container(
                                                  width: 4,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF0D5C4D,
                                                          ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 18,
                            runSpacing: 8,
                            children: const [
                              _LegendDot(
                                color: Color(0xFF0D5C4D),
                                label: 'Evento programado',
                              ),
                              _LegendDot(
                                color: Color(0xFFC8D4D0),
                                label: 'Sin eventos',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _eventDateLabel,
                            style: const TextStyle(
                              color: Color(0xFF586862),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FutureBuilder<List<ActivityItem>>(
                            future: _activities,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.hasError) {
                                return Text(
                                  'No se pudieron cargar las actividades: '
                                  '${snapshot.error}',
                                );
                              }

                              final activities = _activitiesOn(
                                snapshot.data ?? const <ActivityItem>[],
                                DateTime(
                                  _selectedMonth.year,
                                  _selectedMonth.month,
                                  _selectedDay,
                                ),
                              );
                              if (activities.isEmpty) {
                                return const Text(
                                  'No hay actividades planificadas para este día.',
                                );
                              }

                              return Column(
                                children: [
                                  for (final activity in activities)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0D5C4D),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  activity.activity,
                                                  style: const TextStyle(
                                                    color: Color(0xFF1F2B29),
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  [
                                                    activity.timeLabel,
                                                    if (activity
                                                        .responsible
                                                        .isNotEmpty)
                                                      'Responsable: ${activity.responsible}',
                                                    if (activity
                                                        .place
                                                        .isNotEmpty)
                                                      'Lugar: ${activity.place}',
                                                    if (activity
                                                        .modality
                                                        .isNotEmpty)
                                                      'Modalidad: ${activity.modality}',
                                                  ].join('\n'),
                                                  style: const TextStyle(
                                                    color: Color(0xFF4D5E5A),
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
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
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(color: Color(0xFFF3F5F2)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 5;
          return Row(
            children: [
              SizedBox(
                width: itemWidth,
                child: _BottomTab(
                  key: _selectedTab == 'inicio'
                      ? const ValueKey('tab_inicio_active')
                      : null,
                  icon: Icons.home_rounded,
                  label: 'inicio',
                  active: _selectedTab == 'inicio',
                  onTap: () => setState(() => _selectedTab = 'inicio'),
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _BottomTab(
                  key: _selectedTab == 'agenda'
                      ? const ValueKey('tab_agenda_active')
                      : null,
                  icon: Icons.calendar_today_rounded,
                  label: 'agenda',
                  active: _selectedTab == 'agenda',
                  onTap: _openAgenda,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _BottomTab(
                  key: _selectedTab == 'ponentes'
                      ? const ValueKey('tab_ponentes_active')
                      : null,
                  icon: Icons.groups_rounded,
                  label: 'ponentes',
                  active: _selectedTab == 'ponentes',
                  onTap: () => setState(() {
                    _selectedTab = 'ponentes';
                    _speakers = AuthService.getSpeakers();
                  }),
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _BottomTab(
                  key: _selectedTab == 'talleres'
                      ? const ValueKey('tab_talleres_active')
                      : null,
                  icon: Icons.menu_book_rounded,
                  label: 'talleres',
                  active: _selectedTab == 'talleres',
                  onTap: () => setState(() {
                    _selectedTab = 'talleres';
                    _myWorkshops = AuthService.getMyWorkshops();
                  }),
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _BottomTab(
                  key: _selectedTab == 'perfil'
                      ? const ValueKey('tab_perfil_active')
                      : null,
                  icon: Icons.person_rounded,
                  label: 'perfil',
                  active: _selectedTab == 'perfil',
                  onTap: () => setState(() => _selectedTab = 'perfil'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWorkshopsContent() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          final future = AuthService.getMyWorkshops();
          setState(() => _myWorkshops = future);
          await future;
        },
        child: FutureBuilder<List<WorkshopItem>>(
          future: _myWorkshops,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    snapshot.error.toString().replaceFirst('Exception: ', ''),
                  ),
                ],
              );
            }
            final workshops = snapshot.data ?? const <WorkshopItem>[];
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Mis talleres',
                  style: TextStyle(
                    color: Color(0xFF0C5A4A),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Talleres y ubicaciones de cada día.'),
                const SizedBox(height: 12),
                if (workshops.isEmpty)
                  const Text('Aún no tienes talleres asignados.'),
                for (final workshop in workshops)
                  Card(
                    color: const Color(0xFFEDF6F2),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (workshop.rotationDay != null) ...[
                            Text(
                              'Día ${workshop.rotationDay! + 1}',
                              style: const TextStyle(
                                color: Color(0xFF0C5A4A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            workshop.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _workshopInfoRow(
                            Icons.place_outlined,
                            workshop.address.isEmpty
                                ? 'Dirección por definir'
                                : workshop.address,
                          ),
                          _workshopInfoRow(
                            Icons.meeting_room_outlined,
                            workshop.room.isEmpty
                                ? 'Aula por definir'
                                : workshop.room,
                          ),
                          if (workshop.rotationDay != null)
                            _workshopInfoRow(
                              Icons.event_outlined,
                              workshop.dayLabel(workshop.rotationDay!),
                            )
                          else if (workshop.dayTimes.isEmpty)
                            _workshopInfoRow(
                              Icons.event_outlined,
                              'Fecha y hora por definir',
                            )
                          else
                            for (var i = 0; i < workshop.dayTimes.length; i++)
                              _workshopInfoRow(
                                Icons.event_outlined,
                                workshop.dayLabel(i),
                              ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _workshopInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0C5A4A)),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final user = context.watch<AuthController>().currentUser;
    if (user == null) {
      return const Center(child: Text('No hay sesión activa'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Card(
        color: const Color(0xFFEDF6F2),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                key: const Key('profile_qr'),
                color: Colors.white,
                padding: const EdgeInsets.all(10),
                child: const LiveQr(size: 200),
              ),
              const SizedBox(height: 8),
              const Text(
                'Este QR se renueva solo. Muéstralo desde tu celular al registrador.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              Text(
                user.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF0C5A4A),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(user.email, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(user.roleLabel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String tab) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            color: const Color(0xFFEDF6F2),
            child: SizedBox(
              width: 260,
              height: 180,
              child: Center(
                child: Text(
                  tab.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF0C5A4A),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3F1),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A0C2B23),
                  blurRadius: 15,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                children: [
                  _buildSectionHeader(
                    subtitle: 'Eventos de la UNESUM',
                    title: 'Inicio',
                    onRefresh: _refreshActivities,
                  ),
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF4F6F3),
                      padding: const EdgeInsets.all(16),
                      child: FutureBuilder<List<ContentSection>>(
                        future: _sections,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'No se pudieron cargar las secciones: '
                                '${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          final sections =
                              snapshot.data ?? const <ContentSection>[];
                          if (sections.isEmpty) {
                            return const Center(
                              child: Text(
                                'No hay contenido publicado.',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return ListView(
                            children: [
                              for (final section in sections)
                                Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  clipBehavior: Clip.antiAlias,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  surfaceTintColor: Colors.transparent,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      14,
                                      14,
                                      12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (section.title.isNotEmpty) ...[
                                          Text(
                                            section.title,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge
                                                ?.copyWith(
                                                  color: const Color(
                                                    0xFF075044,
                                                  ),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        if (section.imageLink.isNotEmpty)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minHeight: 90,
                                                maxHeight: 180,
                                              ),
                                              padding: EdgeInsets.zero,
                                              child: Image.network(
                                                section.imageLink,
                                                width: double.infinity,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, _, _) =>
                                                    const Center(
                                                      child: Icon(
                                                        Icons
                                                            .image_not_supported_outlined,
                                                        color: Color(
                                                          0xFF55706A,
                                                        ),
                                                        size: 36,
                                                      ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        if (section.body.isNotEmpty)
                                          Text(
                                            section.body,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Color(0xFF334943),
                                              fontSize: 15,
                                              height: 1.45,
                                            ),
                                          ),
                                        if (section.videoLink.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          if (section.videoPath.isNotEmpty)
                                            SectionVideoPlayer(
                                              videoUrl: section.videoLink,
                                            )
                                          else
                                            Center(
                                              child: OutlinedButton.icon(
                                                onPressed: () =>
                                                    _openSectionVideo(section),
                                                icon: const Icon(
                                                  Icons.play_circle_outline,
                                                ),
                                                label: const Text('Ver video'),
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _selectedTab == 'inicio'
        ? _buildHomeContent(context)
        : _selectedTab == 'agenda'
        ? _buildAgendaContent(context)
        : Column(
            children: [
              _buildSectionHeader(
                subtitle: _selectedTab == 'talleres'
                    ? 'Mis asignaciones'
                    : _selectedTab == 'ponentes'
                    ? 'Conferencistas del evento'
                    : 'Mi cuenta',
                title: _selectedTab == 'talleres'
                    ? 'Talleres'
                    : _selectedTab == 'ponentes'
                    ? 'Ponentes'
                    : 'Perfil',
                onRefresh: _selectedTab == 'talleres'
                    ? _refreshWorkshops
                    : _selectedTab == 'ponentes'
                    ? _refreshSpeakers
                    : null,
              ),
              Expanded(
                child: _selectedTab == 'talleres'
                    ? _buildWorkshopsContent()
                    : _selectedTab == 'ponentes'
                    ? _buildSpeakersContent()
                    : _selectedTab == 'perfil'
                    ? _buildProfileTab()
                    : _buildPlaceholderTab(_selectedTab),
              ),
            ],
          );

    final viewportWidth = MediaQuery.of(context).size.width;
    final phoneWidth = (viewportWidth - 18).clamp(0.0, 360.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFEAEFEA),
      body: SafeArea(
        child: Center(
          child: Container(
            width: phoneWidth,
            decoration: const BoxDecoration(
              color: Color(0xFFF5F7F5),
              borderRadius: BorderRadius.all(Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x1A0C2B23),
                  blurRadius: 22,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Column(
                children: [
                  Expanded(child: content),
                  _buildBottomNavigationBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF55706A), fontSize: 10),
        ),
      ],
    );
  }
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? const Color(0xFF0C5A4A) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: active ? Colors.white : const Color(0xFF7A8D89),
                size: 18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active
                    ? const Color(0xFF0C5A4A)
                    : const Color(0xFF6D7B7A),
                fontSize: 8,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionVideoPlayer extends StatefulWidget {
  const SectionVideoPlayer({required this.videoUrl, super.key});

  final String videoUrl;

  @override
  State<SectionVideoPlayer> createState() => _SectionVideoPlayerState();
}

class _SectionVideoPlayerState extends State<SectionVideoPlayer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialized;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.addListener(_onControllerChanged);
    _initialized = _controller.initialize();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialized,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Text(
            'No se pudo cargar el video.',
            textAlign: TextAlign.center,
          );
        }
        final aspectRatio = _controller.value.aspectRatio;
        return Column(
          children: [
            AspectRatio(
              aspectRatio: aspectRatio == 0 ? 16 / 9 : aspectRatio,
              child: VideoPlayer(_controller),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: _controller.value.isPlaying
                      ? 'Pausar video'
                      : 'Reproducir video',
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_circle_outline
                        : Icons.play_circle_outline,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                    });
                  },
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    colors: VideoProgressColors(
                      playedColor: Theme.of(context).colorScheme.primary,
                      bufferedColor: Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.3),
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .outlineVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
