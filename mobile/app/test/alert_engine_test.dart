import 'package:flutter_test/flutter_test.dart';

import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/rain_forecast.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/services/alert_engine.dart';

Station _station({
  required String code,
  required int? situation,
  double? wl,
  double? bank,
  String amphoe = 'เมืองยะลา',
}) {
  return Station(
    id: 1,
    code: code,
    nameTh: 'สถานี $code',
    lat: 6.5,
    lng: 101.28,
    waterLevelMsl: wl,
    leftBank: bank,
    situationLevel: situation,
    amphoeTh: amphoe,
    datetime: '2026-11-23 20:10',
  );
}

void main() {
  const engine = AlertEngine();

  group('AlertEngine.effectiveRisk', () {
    test('situation 4 = อันตราย, 3 = เตือนภัย, 2 = เฝ้าระวัง', () {
      expect(
        engine.effectiveRisk(_station(code: 'A', situation: 4), const AlertSettings()),
        RiskLevel.danger,
      );
      expect(
        engine.effectiveRisk(_station(code: 'B', situation: 3), const AlertSettings()),
        RiskLevel.warning,
      );
      expect(
        engine.effectiveRisk(_station(code: 'C', situation: 2), const AlertSettings()),
        RiskLevel.watch,
      );
    });

    test('ปรับเกณฑ์จากการตั้งค่าได้ (เตือนที่ระดับ 2)', () {
      const settings = AlertSettings(warningLevel: 2, dangerLevel: 3);
      expect(
        engine.effectiveRisk(_station(code: 'A', situation: 2), settings),
        RiskLevel.warning,
      );
      expect(
        engine.effectiveRisk(_station(code: 'B', situation: 3), settings),
        RiskLevel.danger,
      );
    });

    test('คะแนนฝนสูงปรับระดับขึ้นได้', () {
      const rain = RainForecast(
        score: 90,
        source: 'TMD',
        summaryTh: 'ฝนตกหนัก',
      );
      final base = engine.effectiveRisk(
        _station(code: 'A', situation: 3),
        const AlertSettings(),
      );
      final withRain = engine.effectiveRisk(
        _station(code: 'A', situation: 3),
        const AlertSettings(),
        rain: rain,
      );
      expect(base, RiskLevel.warning);
      expect(withRain, RiskLevel.danger);
    });

    test('ปิดการใช้คะแนนฝนแล้วระดับไม่เปลี่ยน', () {
      const rain = RainForecast(score: 95, source: 'TMD', summaryTh: '');
      final level = engine.effectiveRisk(
        _station(code: 'A', situation: 2),
        const AlertSettings(rainScoreEnabled: false),
        rain: rain,
      );
      expect(level, RiskLevel.watch);
    });
  });

  group('AlertEngine.evaluate', () {
    test('สร้างแจ้งเตือนเฉพาะสถานีที่ถึงเกณฑ์', () {
      final stations = [
        _station(code: 'DANGER', situation: 4),
        _station(code: 'WARN', situation: 3),
        _station(code: 'WATCH', situation: 2),
        _station(code: 'NORMAL', situation: 1),
      ];
      final alerts = engine.evaluate(
        stations: stations,
        settings: const AlertSettings(),
        now: DateTime(2026, 11, 23, 12),
      );
      expect(alerts.map((a) => a.stationCode).toSet(), {'DANGER', 'WARN'});
      expect(
        alerts.first.level,
        RiskLevel.danger,
        reason: 'เรียงตามความรุนแรงก่อน',
      );
    });

    test('ไม่ซ้ำเมื่อเดิมอยู่ในประวัติแล้ว', () {
      final stations = [_station(code: 'WARN', situation: 3)];
      final now = DateTime(2026, 11, 23, 12);
      final first = engine.evaluate(stations: stations, now: now);
      final second = engine.evaluate(
        stations: stations,
        now: now,
        previous: first,
      );
      expect(first.length, 1);
      expect(second, isEmpty);
    });

    test('กรองตามอำเภอที่เลือก', () {
      final stations = [
        _station(code: 'A', situation: 4, amphoe: 'เมืองยะลา'),
        _station(code: 'B', situation: 4, amphoe: 'เบตง'),
      ];
      final alerts = engine.evaluate(
        stations: stations,
        settings: const AlertSettings(selectedAmphoeTh: 'เบตง'),
      );
      expect(alerts.length, 1);
      expect(alerts.first.stationCode, 'B');
    });

    test('ข้อความแจ้งเตือนมีระดับน้ำและระยะถึงตลิ่ง', () {
      final alerts = engine.evaluate(
        stations: [_station(code: 'A', situation: 4, wl: 13.0, bank: 13.85)],
        settings: const AlertSettings(),
      );
      expect(alerts.single.message, contains('13.00'));
      expect(alerts.single.message, contains('0.85'));
    });
  });
}
