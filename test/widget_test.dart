// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:flutterloginmysql/app.dart';
import 'package:flutterloginmysql/controllers/auth_controller.dart';
import 'package:flutterloginmysql/models/user_model.dart';
import 'package:flutterloginmysql/services/auth_service.dart';
import 'package:flutterloginmysql/views/home/home_screen.dart';

void main() {
  testWidgets('app loads without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const App());

    expect(find.byType(App), findsOneWidget);
  });

  testWidgets('home screen shows the agenda structure', (tester) async {
    final controller = AuthController();
    controller.currentUser = UserModel(
      name: 'Ana',
      email: 'ana@test.com',
      role: 'teacher',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthController>.value(
        value: controller,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    final clockFinder = find.byKey(const ValueKey('device_clock'));
    final displayedTime = tester.widget<Text>(clockFinder).data;
    final clockContext = tester.element(clockFinder);
    final now = DateTime.now();
    expect(
      displayedTime,
      anyOf(
        TimeOfDay.fromDateTime(now).format(clockContext),
        TimeOfDay.fromDateTime(now.subtract(const Duration(minutes: 1)))
            .format(clockContext),
      ),
    );

    expect(find.text('Actividades'), findsOneWidget);
    expect(find.text('Conferencias'), findsOneWidget);
    expect(find.text('UNESUM INNOVA 20...'), findsNothing);
    expect(find.byKey(const ValueKey('tab_inicio_active')), findsOneWidget);
    expect(find.byKey(const ValueKey('tab_agenda_active')), findsNothing);

    await tester.tap(find.text('AGENDA'));
    await tester.pump();

    expect(find.byKey(const ValueKey('tab_agenda_active')), findsOneWidget);
    expect(find.text('Agenda de conferencias'), findsOneWidget);
    expect(find.text('Calendario'), findsOneWidget);
    final monthName = [
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
    ][DateTime.now().month - 1];
    expect(find.text('$monthName ${now.year}'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('month_next_button')));
    await tester.pump();

    final nextMonth = DateTime(now.year, now.month + 1);
    final nextMonthName = [
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
    ][nextMonth.month - 1];
    expect(find.text('$nextMonthName ${nextMonth.year}'), findsOneWidget);
  });

  test('seminar date range follows the saved activity dates', () {
    final activities = [
      ActivityItem(
        id: 1,
        activity: 'Clausura',
        date: '2027-03-12',
        time: '10:00',
        endTime: '',
        modality: '',
        fileName: '',
        filePath: '',
      ),
      ActivityItem(
        id: 2,
        activity: 'Apertura',
        date: '2027-03-10',
        time: '09:00',
        endTime: '',
        modality: '',
        fileName: '',
        filePath: '',
      ),
    ];

    expect(
      seminarDateRangeLabel(activities),
      'Del 10 al 12 mar 2027 · Jipijapa, EC',
    );
  });
}
