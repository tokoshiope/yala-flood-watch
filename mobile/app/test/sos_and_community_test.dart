import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';
import 'package:yala_flood_app/models/sos_request.dart';
import 'package:yala_flood_app/screens/sos_screen.dart';
import 'package:yala_flood_app/services/community_report_service.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/sos_dispatch_service.dart';
import 'package:yala_flood_app/services/thai_water_service.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SosDispatchService — Smart Real SOS & Pure-Dart SHA-256', () {
    test('Pure-Dart SHA-256 ตรงตาม NIST RFC 6234 test vectors', () {
      expect(
        SosDispatchService.sha256Hex(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
      expect(
        SosDispatchService.sha256Hex('abc'),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
      // RFC 6234 multi-block 56-byte boundary vector
      expect(
        SosDispatchService.sha256Hex(
          'abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq',
        ),
        '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
      );
      // Exact 64-byte boundary (`yala-flood-c-v1:` + 48 hex chars) & UTF-8 Thai text
      expect(
        SosDispatchService.sha256Hex(
          'yala-flood-c-v1:0123456789abcdef0123456789abcdef0123456789abcdef',
        ),
        '6d316ac9d23f7d6587521c8265619aa7dfa8ebcf6185bda2272fb46b133d9522',
      );
      expect(
        SosDispatchService.sha256Hex('น้ำท่วมยะลา'),
        '013780de89a06657b60f735e32113ed3b6ed4eb1b24947c5f064ae37e5438185',
      );
      final h = SosDispatchService.sha256Hex('yala-flood-c-v1:test-salt');
      expect(h.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(h), isTrue);
    });

    test('buildSmsUri ใช้ %20 แทน + เพื่อแก้บั๊ก iOS Messages และ sanitize เบอร์ปลายทาง', () {
      final uri = SosDispatchService.buildSmsUri(
        'SOS Yala flood help',
        recipient: '073-203 559abc',
      );
      expect(uri.scheme, 'sms');
      expect(uri.path, '073203559');
      expect(uri.toString().contains('+'), isFalse);
      expect(uri.toString().contains('SOS%20Yala%20flood%20help'), isTrue);

      final openRecipient = SosDispatchService.buildSmsUri('Need rescue');
      expect(openRecipient.scheme, 'sms');
      expect(openRecipient.path, isEmpty);
      expect(openRecipient.toString(), 'sms:?body=Need%20rescue');
    });

    test('buildLineShareUri บังคับ HTTPS และ encode ข้อความถูกต้อง', () {
      final uri = SosDispatchService.buildLineShareUri('SOS น้ำท่วมยะลา');
      expect(uri.scheme, 'https');
      expect(uri.host, 'line.me');
      expect(uri.path, '/R/share');
      expect(uri.queryParameters['text'], 'SOS น้ำท่วมยะลา');
    });

    test('buildSosMessage ครบ 4 ภาษา ไม่มีอักษรไทยรั่วในโหมด EN/ZH/MS และมีลิงก์ Google Maps', () {
      final thaiRegex = RegExp(r'[\u0E00-\u0E7F]');
      const pin = UserPinAssessment(
        lat: 6.541234,
        lng: 101.281234,
        isGps: true,
        level: 4,
        amphoeTh: 'เมืองยะลา',
        tumbonTh: 'สะเตง',
        tumbonEn: 'Sateng',
        elevationMsl: 16.4,
        refWaterMsl: 15.8,
        marginMeters: 0.6,
      );
      final ts = DateTime.utc(2026, 11, 24, 12, 30);

      for (final lang in ['th', 'en', 'zh', 'ms']) {
        final msg = SosDispatchService.buildSosMessage(
          strings: AppStrings(lang),
          typeTh: kSosTypes[1],
          lat: 6.541234,
          lng: 101.281234,
          timestamp: ts,
          accuracyMeters: 10,
          phone: '0812345678',
          note: '2 elderly',
          pinAssessment: pin,
        );
        expect(msg.contains('6.541234, 101.281234'), isTrue);
        expect(msg.contains('https://maps.google.com/?q=6.541234,101.281234'), isTrue);
        expect(msg.contains('0812345678'), isTrue);
        expect(msg.contains('2 elderly'), isTrue);
        if (lang != 'th') {
          expect(thaiRegex.hasMatch(msg), isFalse, reason: 'Thai leaked in $lang: $msg');
        }
      }
    });

    test('AppConfig.resolveSupabaseBaseUrl ดึง HTTPS origin จาก Supabase CDN URL อัตโนมัติและปฏิเสธ http', () {
      expect(
        AppConfig.resolveSupabaseBaseUrl(
          explicitUrl: '',
          snapshotCdnUrl: 'https://ibrdiroqzgqykxpttafj.supabase.co/storage/v1/object/public/snapshots',
        ),
        'https://ibrdiroqzgqykxpttafj.supabase.co',
      );
      expect(
        AppConfig.resolveSupabaseBaseUrl(
          explicitUrl: 'http://insecure.supabase.co',
          snapshotCdnUrl: '',
        ),
        isEmpty,
      );
    });
  });

  group('CommunityReportService — Tier C PDPA & Fail-Closed Security', () {
    test('ปัดเศษพิกัด ~110 ม. (3 ทศนิยม), ส่ง device_hash 64 ตัวอักษร, ไม่ส่ง PII ใด ๆ', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStore(prefs);
      Map<String, dynamic>? sentBody;

      final client = MockClient((request) async {
        expect(request.url.scheme, 'https');
        expect(request.url.path, '/rest/v1/rpc/submit_community_report');
        expect(request.headers['apikey'], 'public-anon-key');
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response('"11111111-2222-3333-4444-555555555555"', 200);
      });

      final svc = CommunityReportService(
        client: client,
        supabaseBaseUrlOverride: 'https://demo.supabase.co',
        anonKeyOverride: 'public-anon-key',
      );

      final result = await svc.submitReport(
        amphoeTh: 'เมืองยะลา',
        reportType: 'road_flooded',
        lat: 6.541876,
        lng: 101.281432,
        store: store,
        waterDepthCm: 45,
        noteTh: 'หน้าตลาดรถเล็กผ่านไม่ได้',
      );

      expect(result.ok, isTrue);
      expect(result.reportId, '11111111-2222-3333-4444-555555555555');
      expect(sentBody, isNotNull);
      expect(sentBody!['p_lat'], 6.542); // rounded to 3 decimals (~110m)
      expect(sentBody!['p_lon'], 101.281);
      expect((sentBody!['p_device_hash'] as String).length, 64);
      expect(sentBody!.containsKey('phone'), isFalse);
      expect(sentBody!.containsKey('p_phone'), isFalse);
      expect(store.loadCommunityLastReportAt(), isNotNull);
      svc.close();
    });

    test('ปฏิเสธพิกัดนอก จ.ยะลา, http://, และจัดการ Rate Limit 60 นาที', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          '{"message":"Rate limit exceeded: max 1 report per device per hour"}',
          400,
        );
      });

      // Unconfigured / HTTP rejected fail-closed
      final insecureSvc = CommunityReportService(
        client: client,
        supabaseBaseUrlOverride: 'http://demo.supabase.co',
        anonKeyOverride: 'anon',
      );
      expect(insecureSvc.isConfigured, isFalse);
      final notCfg = await insecureSvc.submitReport(
        amphoeTh: 'เมืองยะลา',
        reportType: 'water_rising',
        lat: 6.54,
        lng: 101.28,
        store: null,
      );
      expect(notCfg.status, CommunitySubmitStatus.notConfigured);
      expect(calls, 0);

      // Outside Yala bbox rejected before network call
      final svc = CommunityReportService(
        client: client,
        supabaseBaseUrlOverride: 'https://demo.supabase.co',
        anonKeyOverride: 'anon',
      );
      final outBbox = await svc.submitReport(
        amphoeTh: 'เมืองยะลา',
        reportType: 'water_rising',
        lat: 13.75,
        lng: 100.50,
        store: null,
      );
      expect(outBbox.status, CommunitySubmitStatus.outsideYala);
      expect(calls, 0);

      // Rate-limited server error mapped cleanly
      final rateLim = await svc.submitReport(
        amphoeTh: 'เมืองยะลา',
        reportType: 'water_rising',
        lat: 6.54,
        lng: 101.28,
        store: null,
      );
      expect(rateLim.status, CommunitySubmitStatus.rateLimited);
      expect(calls, 1);
      svc.close();
    });

    test('fetchRecentReports อ่านเฉพาะวิว public_community_reports และกรองพิกัดนอกยะลาออก', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/rest/v1/public_community_reports');
        return http.Response(
          jsonEncode([
            {
              'id': 'r1',
              'created_at': '2026-11-24T12:00:00Z',
              'amphoe_th': 'รามัน',
              'report_type': 'water_rising',
              'lat': 6.48,
              'lon': 101.42,
              'water_depth_cm': 60,
              'note_th': 'น้ำขึ้นเร็ว',
              'trust_score': 3,
            },
            {
              'id': 'bad-outside',
              'created_at': '2026-11-24T12:00:00Z',
              'amphoe_th': 'รามัน',
              'report_type': 'water_rising',
              'lat': 13.75,
              'lon': 100.50,
              'trust_score': 3,
            },
          ]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final svc = CommunityReportService(
        client: client,
        supabaseBaseUrlOverride: 'https://demo.supabase.co',
        anonKeyOverride: 'anon',
      );
      final reports = await svc.fetchRecentReports();
      expect(reports.length, 1);
      expect(reports.first.amphoeTh, 'รามัน');
      expect(reports.first.waterDepthCm, 60);
      svc.close();
    });
  });

  group('SosScreen Widget Tests — Emergency Channels Only (Zero SOS Messaging & Zero UGC)', () {
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

      // ต้องมีช่องทางฉุกเฉินครบ (เบอร์โทร + LINE + Facebook)
      expect(find.text('ช่องทางฉุกเฉิน'), findsOneWidget);
      expect(find.text('1784'), findsOneWidget);
      expect(find.text('073-203559'), findsOneWidget);
      expect(find.text('073-212345'), findsOneWidget);
      expect(find.text('LINE @1784DDPM'), findsWidgets);
      expect(find.text('Facebook DDPM'), findsWidgets);

      // ต้องตัดฟีเจอร์ส่งข้อความ SOS และรายงานชุมชน (UGC) ออกทั้งหมด
      expect(find.text('ส่งคำขอ SOS พร้อมพิกัดจริง'), findsNothing);
      expect(find.text('ส่ง SMS ฉุกเฉิน (ใช้ได้แม้เน็ตล่ม)'), findsNothing);
      expect(find.text('ค้นหาพิกัด GPS'), findsNothing);
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
          child: const MaterialApp(
            home: SosScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency Contacts'), findsOneWidget);
      expect(find.text('Emergency Channels (Call · LINE · Facebook)'), findsOneWidget);
      expect(find.text('Community Flood Report (Anonymous)'), findsNothing);
      expect(find.text('Send Real SOS with GPS'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    test('SosRequest JSON serialization รองรับ amphoeTh & dispatchedVia แบบ backward-compatible', () {
      final legacy = SosRequest.fromJson({
        'id': 'sos-1',
        'typeTh': kSosTypes.first,
        'createdAt': '2026-11-24T12:00:00Z',
        'lat': 6.54,
        'lng': 101.28,
        'phone': '0812345678',
      });
      expect(legacy.amphoeTh, isNull);
      expect(legacy.dispatchedVia, isNull);

      final modern = legacy.copyWith(amphoeTh: 'เมืองยะลา', dispatchedVia: 'sms');
      final roundtrip = SosRequest.fromJson(modern.toJson());
      expect(roundtrip.amphoeTh, 'เมืองยะลา');
      expect(roundtrip.dispatchedVia, 'sms');
    });
  });
}
