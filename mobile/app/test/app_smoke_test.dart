import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/screens/app_shell.dart';
import 'package:yala_flood_app/screens/settings_screen.dart';
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
    // ใน fixture วันแดดออกปกติ (formula_version = 5, PAT002 watch=13.30) ไม่มี false alarm ทุกสถานีปกติ
    expect(provider.warningStationCount, 0);
    expect(provider.stations.every((s) => s.riskLevel.severity <= 1), isTrue);

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

    // แถบ 1: หัวบนสุด "แจ้งเตือนน้ำท่วมยะลา" + กรอบเขื่อนบางลาง + ป้ายสถานีชื่อจริง (บ้านปายอยือนิ ไม่ใช่ X.273)
    expect(find.text('แจ้งเตือนน้ำท่วมยะลา'), findsOneWidget);
    expect(find.text('เขื่อนบางลาง'), findsWidgets);
    expect(find.text('บ้านปายอยือนิ'), findsOneWidget);
    expect(find.text('X.273'), findsNothing);
    expect(find.text('แผนที่'), findsOneWidget);
    expect(find.text('ข้อมูล'), findsWidgets);
    expect(find.text('ฉุกเฉิน'), findsOneWidget);
    expect(find.text('ศูนย์พักพิง'), findsWidgets);
    expect(find.text('ตั้งค่า'), findsWidgets);

    // แถบ 2: ข้อมูล (กราฟแท่งพยากรณ์ฝน + 14 สถานีเน้นระยะเหลือถึงตลิ่ง + 8 อำเภอระบุหมู่บ้าน/ตำบล)
    await tester.tap(find.text('ข้อมูล').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('พยากรณ์ฝน'), findsWidgets);
    expect(find.textContaining('formula_version'), findsNothing);

    // แถบ 3: ช่องทางฉุกเฉิน คงเฉพาะเบอร์โทร LINE และ Facebook (ไม่มีฟอร์ม SOS)
    await tester.tap(find.text('ฉุกเฉิน'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('LINE @1784DDPM'), findsWidgets);
    expect(find.text('Facebook DDPM'), findsWidgets);
    expect(find.text('ส่งคำขอ SOS พร้อมพิกัดจริง'), findsNothing);

    // แถบ 4: ศูนย์พักพิง แสดงเบอร์โทรในปุ่มโทร และไม่มีป้าย "พิกัดโดยประมาณ"
    await tester.tap(find.text('ศูนย์พักพิง').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('พิกัดโดยประมาณ'), findsNothing);
    expect(find.text('กดโทร 073-212345'), findsWidgets);

    // แถบ 5: ตั้งค่า มีเมนูเลือกภาษา 4 ภาษา + คำอธิบายระดับแจ้งเตือน 1-5 + เปิดเสียง + Notification
    await tester.tap(find.text('ตั้งค่า').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('ภาษาของแอป (Language)'), findsOneWidget);
    expect(find.text('คำอธิบายระดับการแจ้งเตือน (1–5)'), findsOneWidget);
    final settingsScrollable = find.descendant(
      of: find.byType(SettingsScreen),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('เปิดเสียงแจ้งเตือน'),
      150,
      scrollable: settingsScrollable,
    );
    expect(find.text('เปิดเสียงแจ้งเตือน'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('เปิดข้อความ Notification'),
      100,
      scrollable: settingsScrollable,
    );
    expect(find.text('เปิดข้อความ Notification'), findsOneWidget);
    expect(find.textContaining('formula_version'), findsNothing);
  });
}
