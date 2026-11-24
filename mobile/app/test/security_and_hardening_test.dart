import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/notification_service.dart';
import 'package:yala_flood_app/services/snapshot_service.dart';

Map<String, dynamic> _validSnapshotMap({
  String hash = 'abc123def456',
  double stationLat = 6.54,
  double stationLon = 101.28,
}) {
  return {
    'schema_version': 2,
    'formula_version': 2,
    'province': {'code': '95', 'name': 'ยะลา', 'name_en': 'Yala'},
    'content_hash': hash,
    'amphoes': [
      for (final amp in AppConfig.riskAmphoeTh)
        {
          'amphoe': amp,
          'assessment': {'level': 1, 'score': 10.0, 'should_push': false},
        },
    ],
    'stations': [
      {
        'code': 'PAT002',
        'name': 'สะพานท่าสาป',
        'lat': stationLat,
        'lon': stationLon,
      },
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Security & Fail-Closed Hardening', () {
    test('SnapshotService ปฏิเสธพิกัดนอกเขตจังหวัดยะลาแบบ Fail-Closed', () {
      expect(
        SnapshotService.isValidYalaSnapshot(_validSnapshotMap()),
        isTrue,
      );
      expect(
        SnapshotService.isValidYalaSnapshot(
          _validSnapshotMap(stationLat: 13.75, stationLon: 100.50),
        ),
        isFalse,
      );
      expect(
        SnapshotService.isValidYalaSnapshot(
          _validSnapshotMap(stationLat: 6.54, stationLon: 99.10),
        ),
        isFalse,
      );
      // Malformed string coordinate must fail closed (return false, never throw TypeError)
      final badTypeMap = _validSnapshotMap();
      (badTypeMap['stations'] as List).first['lat'] = '6.54';
      expect(SnapshotService.isValidYalaSnapshot(badTypeMap), isFalse);
    });

    test('SnapshotService ปฏิเสธ CDN ที่ไม่ใช่ HTTPS (http://) ไม่เรียกเครือข่าย', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var networkCalls = 0;
      final client = MockClient((request) async {
        networkCalls++;
        return http.Response('{}', 200);
      });
      final service = SnapshotService(
        client: client,
        preferences: prefs,
        cdnBaseUrlOverride: 'http://insecure.example.com/snapshots',
      );
      final snap = await service.loadSnapshot();
      expect(networkCalls, 0);
      expect(snap, isNotNull); // falls back cleanly to bundled offline snapshot
      service.close();
    });

    test('SnapshotService ตรวจ manifest.json + latest.json แบบขนานและ Fail-Closed เมื่อแฮชไม่ตรง', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final validBody = jsonEncode(_validSnapshotMap(hash: 'goodhash999'));
      final badManifest = jsonEncode({'content_hash': 'tampered_hash'});
      final goodManifest = jsonEncode({'content_hash': 'goodhash999'});

      // Case 1: hash mismatch → fail-closed (does not overwrite cache)
      final tamperedClient = MockClient((request) async {
        final body = request.url.path.endsWith('manifest.json')
            ? badManifest
            : validBody;
        return http.Response.bytes(
          utf8.encode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final tamperedSvc = SnapshotService(
        client: tamperedClient,
        preferences: prefs,
        cdnBaseUrlOverride: 'https://cdn.example.com/snapshots',
      );
      await tamperedSvc.loadSnapshot();
      expect(prefs.getString(AppConfig.cacheSnapshotKey), isNull);
      tamperedSvc.close();

      // Case 2: hash matches → accepted & cached
      final okClient = MockClient((request) async {
        final body = request.url.path.endsWith('manifest.json')
            ? goodManifest
            : validBody;
        return http.Response.bytes(
          utf8.encode(body),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final okSvc = SnapshotService(
        client: okClient,
        preferences: prefs,
        cdnBaseUrlOverride: 'https://cdn.example.com/snapshots',
      );
      final snap = await okSvc.loadSnapshot();
      expect(snap, isNotNull);
      expect(snap!.sourceLabel, 'Supabase CDN (5 Sources)');
      expect(prefs.getString(AppConfig.cacheSnapshotKey), isNotNull);
      okSvc.close();
    });

    test('LocalStore.deleteAllUserData ลบข้อมูลส่วนบุคคล PDPA ครบทุกคีย์รวม Topic ที่บันทึกไว้', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.alertsPrefsKey: '[]',
        AppConfig.settingsPrefsKey: '{}',
        AppConfig.sosLogPrefsKey: '[]',
        AppConfig.gpsConsentPrefsKey: true,
        AppConfig.subscribedTopicPrefsKey: 'yala_flood_mueang_yala',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStore(prefs);

      await store.deleteAllUserData();

      expect(prefs.getString(AppConfig.alertsPrefsKey), isNull);
      expect(prefs.getString(AppConfig.settingsPrefsKey), isNull);
      expect(prefs.getString(AppConfig.sosLogPrefsKey), isNull);
      expect(prefs.getBool(AppConfig.gpsConsentPrefsKey), isNull);
      expect(prefs.getString(AppConfig.subscribedTopicPrefsKey), isNull);
    });

    test('NotificationService มี FCM Topic ASCII ครบทั้ง 8 อำเภอของยะลา', () {
      final validFcmPattern = RegExp(r'^[a-zA-Z0-9\-_.~%]+$');
      expect(NotificationService.topicForAmphoe(null), 'yala_flood_all');
      for (final amphoe in AppConfig.riskAmphoeTh) {
        final topic = NotificationService.topicForAmphoe(amphoe);
        expect(topic, isNot('yala_flood_all'));
        expect(validFcmPattern.hasMatch(topic), isTrue);
      }
    });
  });
}
