import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/screens/alerts_screen.dart';
import 'package:yala_flood_app/screens/shelters_screen.dart';
import 'package:yala_flood_app/screens/station_detail_screen.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/thai_water_service.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

Future<AlertProvider> _buildLoadedProvider({String lang = 'th'}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final client = MockClient((request) async {
    if (request.url.path.contains('waterlevel_graph')) {
      return http.Response(
        jsonEncode({
          'result': 'OK',
          'data': {
            'graph_data': [
              {'datetime': '2026-11-20 00:00', 'value': 12.10, 'discharge': 42.0},
              {'datetime': '2026-11-22 12:00', 'value': 12.65, 'discharge': 58.0},
              {'datetime': '2026-11-24 12:00', 'value': 13.05, 'discharge': 75.5},
              {'datetime': '2026-11-26 23:00', 'value': 12.58, 'discharge': 63.6},
              {'datetime': '2026-11-26 23:50', 'value': null, 'discharge': null},
            ],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response.bytes(
      utf8.encode(File('test/fixtures/yala_water_sample.json').readAsStringSync()),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  final provider = AlertProvider(
    waterService: ThaiWaterService(client: client, preferences: prefs),
    localStorage: LocalStore(prefs),
  );
  if (lang != 'th') {
    provider.updateSettings(AlertSettings(languageCode: lang));
  }
  await provider.refresh();
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.0.1 Improvements — Unit Tests', () {
    test('AppStrings.callShelterWithNumber แสดงเบอร์โทรจัดรูปแบบครบ 4 ภาษา', () {
      expect(const AppStrings('th').callShelterWithNumber('073212345'), 'กดโทร 073-212345');
      expect(const AppStrings('th').callShelterWithNumber('073203559'), 'กดโทร 073-203559');
      expect(const AppStrings('en').callShelterWithNumber('073212345'), 'Call 073-212345');
      expect(const AppStrings('zh').callShelterWithNumber('073212345'), '致电 073-212345');
      expect(const AppStrings('ms').callShelterWithNumber('073212345'), 'Hubungi 073-212345');
    });

    test('Station.inferUpdateIntervalMinutes ระบุความถี่จริง สสน./พพภ.=10 นาที, กฟผ./ชป.=60 นาที', () {
      expect(Station.inferUpdateIntervalMinutes('สสน.'), 10);
      expect(Station.inferUpdateIntervalMinutes('พพภ'), 10);
      expect(Station.inferUpdateIntervalMinutes('กฟผ.'), 60);
      expect(Station.inferUpdateIntervalMinutes('ชป.'), 60);
    });

    test('ThaiWaterService.parseHistoryGraph กรองค่า null และแปลงจุดข้อมูล 7 วันถูกต้อง', () {
      final raw = jsonEncode({
        'result': 'OK',
        'data': {
          'graph_data': [
            {'datetime': '2026-11-20 00:00', 'value': 12.77, 'discharge': null},
            {'datetime': '2026-11-26 23:00', 'value': 12.43, 'discharge': 61.2},
            {'datetime': '2026-11-26 23:50', 'value': null, 'discharge': null},
          ],
        },
      });
      final pts = ThaiWaterService.parseHistoryGraph(raw);
      expect(pts.length, 2);
      expect(pts.first.timestamp, '2026-11-20 00:00');
      expect(pts.first.valueMsl, 12.77);
      expect(pts.last.valueMsl, 12.43);
      expect(pts.last.discharge, 61.2);
    });
  });

  group('v1.0.1 Improvements — Widget Tests', () {
    testWidgets('SheltersScreen แสดงปุ่มกดโทรพร้อมเบอร์จริงครบ (ไทย & อังกฤษ)', (tester) async {
      final provider = await tester.runAsync(() => _buildLoadedProvider());
      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: provider!,
          child: const MaterialApp(home: SheltersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('กดโทร 073-212345'), findsWidgets);
      expect(find.text('โทรสอบถาม'), findsNothing);

      provider.updateSettings(const AlertSettings(languageCode: 'en'));
      await tester.pumpAndSettle();
      expect(find.text('Call 073-212345'), findsWidgets);
    });

    testWidgets('AlertsScreen แสดงกราฟแท่งฝน iOS Weather, ระยะเหลือถึงตลิ่ง และหมู่บ้าน/ตำบลเฝ้าระวัง', (tester) async {
      final provider = await tester.runAsync(() => _buildLoadedProvider());
      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: provider!,
          child: const MaterialApp(home: AlertsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // 1. กราฟแท่งพยากรณ์ฝนแนว iOS Weather
      expect(find.textContaining('โอกาสฝนตก'), findsOneWidget);

      // 2. รายการสถานีวัดระดับน้ำ เน้นแสดงระยะเหลือถึงตลิ่ง + ความถี่อัปเดตจริง
      final listScroll = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
      ).first;
      await tester.scrollUntilVisible(
        find.text('สถานีวัดระดับน้ำ จ.ยะลา (14 แห่ง)'),
        250,
        scrollable: listScroll,
      );
      await tester.drag(listScroll, const Offset(0, -140));
      await tester.pumpAndSettle();
      expect(find.text('เหลือถึงตลิ่ง'), findsWidgets);
      expect(find.text('อัปเดตทุก 10 นาที'), findsWidgets);

      // 3. สถานการณ์รายอำเภอ ระบุพื้นที่หมู่บ้าน/ตำบลเฝ้าระวังชัดเจน
      await tester.scrollUntilVisible(
        find.text('สถานการณ์รายอำเภอ (8 อำเภอ)'),
        400,
        scrollable: listScroll,
      );
      await tester.drag(listScroll, const Offset(0, -280));
      await tester.pumpAndSettle();
      expect(find.text('พื้นที่หมู่บ้าน/ตำบลที่ต้องเฝ้าระวัง'), findsWidgets);
    });

    testWidgets('StationDetailScreen เน้นระยะเหลือถึงตลิ่ง + กราฟย้อนหลัง 7 วัน + สลับช่วง 24 ชม./3 วัน/7 วัน + หมู่บ้านรอบสถานี', (tester) async {
      final provider = await tester.runAsync(() => _buildLoadedProvider());
      final station = provider!.stations.firstWhere((s) => s.remainingToBank != null);

      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: provider,
          child: MaterialApp(home: StationDetailScreen(stationCode: station.code)),
        ),
      );
      await tester.pumpAndSettle();

      // เน้นแสดงระยะเหลือถึงตลิ่งเป็นตัวเลขหลัก
      expect(find.text('ระยะเหลือถึงตลิ่ง'), findsOneWidget);

      // กราฟแนวโน้มย้อนหลัง 7 วัน + ปุ่มสลับช่วงเวลา 24 ชม. / 3 วัน / 7 วัน
      await tester.scrollUntilVisible(
        find.text('แนวโน้มระดับน้ำย้อนหลัง 7 วัน'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('แนวโน้มระดับน้ำย้อนหลัง 7 วัน'), findsOneWidget);
      expect(find.text('24 ชม.'), findsOneWidget);
      expect(find.text('3 วัน'), findsOneWidget);
      expect(find.text('7 วัน'), findsOneWidget);

      // สลับไป 3 วันแล้วกลับมา 7 วัน
      await tester.tap(find.text('3 วัน'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7 วัน'));
      await tester.pumpAndSettle();

      // ระบุหมู่บ้านและตำบลในพื้นที่รอบสถานี
      await tester.scrollUntilVisible(
        find.text('หมู่บ้านและตำบลในพื้นที่รอบสถานี'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('หมู่บ้านและตำบลในพื้นที่รอบสถานี'), findsOneWidget);
    });

    testWidgets('HIGH-1 & HIGH-2 regression: จอแคบ 375pt + โหมดตัวอักษรใหญ่ 1.35x ไม่มี RenderFlex overflow', (tester) async {
      final provider = await tester.runAsync(() => _buildLoadedProvider());
      final station = provider!.stations.firstWhere((s) => s.remainingToBank != null);

      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: provider,
          child: MaterialApp(
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(
                textScaler: const TextScaler.linear(1.35),
              ),
              child: child!,
            ),
            home: const AlertsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: provider,
          child: MaterialApp(
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(
                textScaler: const TextScaler.linear(1.35),
              ),
              child: child!,
            ),
            home: StationDetailScreen(stationCode: station.code),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
