import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/screens/guide_screen.dart';
import 'package:yala_flood_app/screens/sos_screen.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/thai_water_service.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SosScreen — Emergency Channels Only (Zero SOS Messaging & Zero UGC)', () {
    testWidgets('หน้าฉุกเฉินคงเฉพาะเบอร์โทร LINE และ Facebook โดยไม่มีฟอร์มส่ง SOS หรือโพสต์ชุมชน', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AlertProvider(
        waterService: ThaiWaterService(client: MockClient((_) async => http.Response('{"data":[]}', 200))),
        localStorage: LocalStore(prefs),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: const SosScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ช่องทางฉุกเฉิน'), findsOneWidget);
      expect(find.text('1784'), findsOneWidget);
      expect(find.text('073-203559'), findsOneWidget);
      expect(find.text('073-212345'), findsOneWidget);
      expect(find.text('LINE @1784DDPM'), findsWidgets);
      expect(find.text('Facebook DDPM'), findsWidgets);

      // 0% UGC & 0% SOS messaging form
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('หน้าฉุกเฉินในโหมด English ไม่มีข้อความภาษาไทยรั่วและไม่มี UGC', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AlertProvider(
        waterService: ThaiWaterService(client: MockClient((_) async => http.Response('{"data":[]}', 200))),
        localStorage: LocalStore(prefs),
      );
      provider.updateSettings(const AlertSettings(languageCode: 'en'));

      await tester.pumpWidget(
        ChangeNotifierProvider<AlertProvider>.value(
          value: provider,
          child: const MaterialApp(home: SosScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency Contacts'), findsOneWidget);
      expect(find.text('1784'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('GuideScreen — Offline App User Guide & Official DDPM Evacuation Guide', () {
    testWidgets('แสดงครบทั้ง 2 แท็บ (คู่มือใช้แอป + คู่มืออพยพ) พร้อมแหล่งอ้างอิง ปภ. และไม่ล้นที่ 375pt/1.35x', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AlertProvider(
        waterService: ThaiWaterService(client: MockClient((_) async => http.Response('{"data":[]}', 200))),
        localStorage: LocalStore(prefs),
      );

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
            theme: ThemeData.dark(useMaterial3: true),
            builder: (ctx, child) => MediaQuery(
              data: MediaQuery.of(ctx).copyWith(
                textScaler: const TextScaler.linear(1.35),
              ),
              child: child!,
            ),
            home: const GuideScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('คู่มือใช้แอป'), findsOneWidget);
      expect(find.text('คู่มืออพยพ'), findsOneWidget);
      expect(find.textContaining('ใช้งานได้ 100%'), findsOneWidget);

      // สลับไปแท็บคู่มืออพยพ
      await tester.tap(find.text('คู่มืออพยพ'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.textContaining('ระยะที่ 1'), findsOneWidget);
    });

    testWidgets('MEDIUM-2 regression: GuideScreen ในภาษา en/zh/ms ไม่มีข้อความภาษาไทยรั่ว (รวมปุ่มโทรด่วน)', (tester) async {
      final thaiRegex = RegExp(r'[\u0E00-\u0E7F]');
      for (final lang in ['en', 'zh', 'ms']) {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final provider = AlertProvider(
          waterService: ThaiWaterService(client: MockClient((_) async => http.Response('{"data":[]}', 200))),
          localStorage: LocalStore(prefs),
        );
        provider.updateSettings(AlertSettings(languageCode: lang));

        await tester.pumpWidget(
          ChangeNotifierProvider<AlertProvider>.value(
            value: provider,
            child: const MaterialApp(home: GuideScreen(initialTab: 1)),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (final element in find.byType(Text).evaluate()) {
          final textWidget = element.widget as Text;
          final data = textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
          expect(
            thaiRegex.hasMatch(data),
            isFalse,
            reason: 'Thai text leaked in GuideScreen($lang): "$data"',
          );
        }
      }
    });
  });
}
