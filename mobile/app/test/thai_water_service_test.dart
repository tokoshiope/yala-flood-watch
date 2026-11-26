import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/thai_water_service.dart';

String _fixture() =>
    File('test/fixtures/yala_water_sample.json').readAsStringSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThaiWaterService (ข้อมูลจริงจาก API)', () {
    test('เรียก API จริงของจ.ยะลา และได้ 14 สถานี', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(_fixture()),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final service = ThaiWaterService(client: client, preferences: prefs);

      final result = await service.fetch();

      expect(result.source, WaterSource.network);
      expect(result.stations.length, 14);
      // ใน fixture น้ำปกติ PAT002 แตะเส้นเฝ้าระวังแบบ side way (13.00 vs watch 12.35 / mid 13.10) -> RiskLevel.watch
      expect(result.stations.first.riskLevel, RiskLevel.watch);
      // ต้องเก็บแคชไว้ด้วย
      expect(prefs.getString(AppConfig.cacheStationsKey), isNotNull);
      expect(prefs.getInt(AppConfig.cacheUpdatedAtKey), isNotNull);
    });

    test('กรองเฉพาะข้อมูลจังหวัดยะลา (province_code 95)', () async {
      final body = jsonEncode({
        'result': 'OK',
        'data': [
          {
            'id': 1,
            'waterlevel_msl': '13.00',
            'situation_level': 2,
            'station': {
              'tele_station_oldcode': 'PAT002',
              'tele_station_name': {'th': 'เมืองยะลา'},
              'tele_station_lat': 6.5,
              'tele_station_long': 101.28,
            },
            'geocode': {
              'province_code': '95',
              'amphoe_name': {'th': 'เมืองยะลา'},
            },
          },
          {
            'id': 2,
            'waterlevel_msl': '99.00',
            'situation_level': 4,
            'station': {
              'tele_station_oldcode': 'BKK001',
              'tele_station_name': {'th': 'กรุงเทพฯ'},
              'tele_station_lat': 13.7,
              'tele_station_long': 100.5,
            },
            'geocode': {
              'province_code': '10',
              'amphoe_name': {'th': 'พระนคร'},
            },
          },
        ],
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final client = MockClient((request) async => http.Response.bytes(utf8.encode(body), 200));
      final service = ThaiWaterService(client: client, preferences: prefs);

      final result = await service.fetch();

      expect(result.stations.length, 1);
      expect(result.stations.single.code, 'PAT002');
    });

    test('เน็ตขาด → ใช้แคชล่าสุดที่บันทึกไว้', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final okClient = MockClient(
        (request) async => http.Response.bytes(utf8.encode(_fixture()), 200),
      );
      await ThaiWaterService(client: okClient, preferences: prefs).fetch();

      final offlineClient = MockClient(
        (request) async => throw http.ClientException('offline'),
      );
      final service = ThaiWaterService(
        client: offlineClient,
        preferences: prefs,
      );

      final result = await service.fetch();

      expect(result.source, WaterSource.cache);
      expect(result.isOffline, isTrue);
      expect(result.stations.length, 14);
      expect(result.updatedAt, isNotNull);
      expect(result.messageTh, contains('ไม่มีสัญญาณ'));
    });

    test('เน็ตขาดและไม่มีแคช → โยนข้อผิดพลาดภาษาไทย', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final offlineClient = MockClient(
        (request) async => throw http.ClientException('offline'),
      );
      final service = ThaiWaterService(
        client: offlineClient,
        preferences: prefs,
      );

      expect(
        () => service.fetch(),
        throwsA(
          isA<ThaiWaterException>().having(
            (e) => e.messageTh,
            'messageTh',
            contains('โปรดลองอีกครั้ง'),
          ),
        ),
      );
    });

    test('ลองใหม่ 3 ครั้งเมื่อเน็ตขาดแล้วค่อยยอมแพ้', () async {
      var calls = 0;
      final offlineClient = MockClient((request) async {
        calls++;
        throw http.ClientException('offline');
      });
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = ThaiWaterService(
        client: offlineClient,
        preferences: prefs,
      );

      await expectLater(service.fetch(), throwsA(isA<ThaiWaterException>()));
      // 1 ครั้งแรก + 2 ครั้ง retry = 3
      expect(calls, AppConfig.maxRetries + 1);
    });

    test('ข้อมูลไม่ใช่ JSON → คืนข้อผิดพลาด ไม่ล่ม', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final badClient = MockClient(
        (request) async => http.Response('<html>', 200),
      );
      final service = ThaiWaterService(client: badClient, preferences: prefs);

      expect(() => service.fetch(), throwsA(isA<ThaiWaterException>()));
    });
  });

  group('LocalStore', () {
    test('ค่า default เมื่อยังไม่เคยบันทึก', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStore(prefs);

      expect(store.loadAlerts(), isEmpty);
      expect(store.loadSettings().quietMode, isFalse);
      expect(store.loadSosRequests(), isEmpty);
    });

    test('บันทึก/อ่าน แจ้งเตือน', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStore(prefs);
      final alert = AlertItem(
        id: 'PAT002-warning-2026-11-23T12',
        stationCode: 'PAT002',
        stationName: 'เมืองยะลา',
        level: RiskLevel.warning,
        title: 'เตือนภัย: เมืองยะลา',
        message: 'ระดับน้ำ 13.00 ม.',
        createdAt: DateTime(2026, 11, 23, 12),
      );

      await store.saveAlerts([alert]);
      final loaded = store.loadAlerts();

      expect(loaded.single.id, alert.id);
      expect(loaded.single.level, RiskLevel.warning);
      expect(loaded.single.stationName, 'เมืองยะลา');
    });

    test('บันทึก/อ่าน การตั้งค่า', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStore(prefs);

      await store.saveSettings(
        const AlertSettings(selectedAmphoeTh: 'เบตง', quietMode: true),
      );
      final settings = store.loadSettings();

      expect(settings.selectedAmphoeTh, 'เบตง');
      expect(settings.quietMode, isTrue);
      expect(settings.warningLevel, AppConfig.defaultWarningLevel);
    });
  });
}
