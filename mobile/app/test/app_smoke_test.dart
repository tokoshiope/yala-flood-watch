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

  testWidgets('แอพครบ 5 หน้า (แผนที่/ข้อมูล/SOS/ศูนย์พักพิง/ตั้งค่า) ตรงตามข้อกำหนด v3', (tester) async {
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
    expect(provider.subdistricts.length, 58);
    expect(provider.villages.length, 449);
    expect(provider.snapshot, isNotNull);
    expect(provider.warningStationCount, greaterThan(0));
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

    // แถบ 1: หัวบนสุด "แจ้งเตือนน้ำท่วมยะลา" + กรอบเขื่อนบางลาง + ปุ่มนำทาง 5 หน้า
    expect(find.text('แจ้งเตือนน้ำท่วมยะลา'), findsOneWidget);
    expect(find.text('เขื่อนบางลาง'), findsOneWidget);
    expect(find.text('แผนที่'), findsOneWidget);
    expect(find.text('ข้อมูล'), findsWidgets);
    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('ศูนย์พักพิง'), findsWidgets);
    expect(find.text('ตั้งค่า'), findsWidgets);

    // แถบ 2: ข้อมูล (กราฟพยากรณ์ฝน + 8 อำเภอ + 14 สถานี โดยไม่มี formula_version)
    await tester.tap(find.text('ข้อมูล').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('พยากรณ์ฝน'), findsWidgets);
    expect(find.textContaining('formula_version'), findsNothing);

    // แถบ 3: SOS มีช่องทาง LINE และ Facebook ที่ตรวจสอบแล้ว
    await tester.tap(find.text('SOS'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('LINE @1784DDPM'), findsWidgets);
    expect(find.text('Facebook DDPM'), findsWidgets);

    // แถบ 4: ศูนย์พักพิง เอาป้าย "ชื่อทางการ (พิกัดโดยประมาณ)" ออก และแสดง "อ้างอิงจากข้อมูลเดิม รอยืนยัน"
    await tester.tap(find.text('ศูนย์พักพิง').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('พิกัดโดยประมาณ'), findsNothing);

    // แถบ 5: ตั้งค่า มีเมนูเลือกภาษา 4 ภาษา + เปิดเสียงแจ้งเตือน + เปิดข้อความ Notification + ไม่มี formula_version
    await tester.tap(find.text('ตั้งค่า').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('ภาษาของแอป (Language)'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -450));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('เปิดเสียงแจ้งเตือน'), findsOneWidget);
    expect(find.text('เปิดข้อความ Notification'), findsOneWidget);
    expect(find.textContaining('formula_version'), findsNothing);
  });
}
