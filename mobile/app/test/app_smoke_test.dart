import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/screens/app_shell.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/thai_water_service.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('แอพครบ 5 หน้า เปิดผ่านได้ด้วยข้อมูลจริง (14 สถานี)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final client = MockClient(
      (request) async => http.Response.bytes(
        utf8.encode(
          File('test/fixtures/yala_water_sample.json').readAsStringSync(),
        ),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final provider = AlertProvider(
      waterService: ThaiWaterService(client: client, preferences: prefs),
      localStorage: LocalStore(prefs),
    );
    await tester.runAsync(() => provider.refresh());

    expect(provider.stations.length, 14);
    expect(provider.boundaries.length, 8);
    expect(provider.snapshot, isNotNull);
    expect(provider.warningStationCount, greaterThan(0));
    // BLOCKER-2 regression: activeAlerts ต้องไม่ว่างหลัง refresh เพื่อป้องกันแบนเนอร์สีเขียว "สถานการณ์ดีขึ้นแล้ว" ระหว่างน้ำท่วม
    expect(provider.activeAlerts, isNotEmpty);

    await tester.pumpWidget(
      ChangeNotifierProvider<AlertProvider>.value(
        value: provider,
        child: MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('th', 'TH')],
          locale: const Locale('th', 'TH'),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    // หน้าหลัก: แผนที่ + สถานีล่าสุด
    expect(find.text('น้ำท่วมยะลา'), findsOneWidget);
    expect(find.text('สถานีอัปเดตล่าสุด'), findsOneWidget);
    expect(find.text('เมืองยะลา'), findsWidgets);

    // ปุ่มนำทางครบ 5 หน้า (ใช้คำว่า ศูนย์พักพิง)
    expect(find.text('หน้าหลัก'), findsOneWidget);
    expect(find.text('แจ้งเตือน'), findsWidgets);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('ศูนย์พักพิง'), findsOneWidget);
    expect(find.text('ตั้งค่า'), findsOneWidget);

    // เปิดหน้าตั้งค่าจากแถบล่างได้จริง และมีเมนูเลือกภาษา 4 ภาษา
    await tester.tap(find.text('ตั้งค่า'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ภาษาของแอป (Language)'), findsOneWidget);
    expect(find.text('พื้นที่ที่ติดตาม'), findsOneWidget);
    expect(find.text('เกณฑ์การแจ้งเตือน'), findsOneWidget);
  });
}
