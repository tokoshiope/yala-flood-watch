import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/rain_forecast.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/services/alert_engine.dart';
import 'package:yala_flood_app/services/snapshot_service.dart';

Station _station({
  required String code,
  required int? situation,
  double? wl,
  double? prev,
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
    waterLevelMslPrev: prev,
    leftBank: bank,
    situationLevel: situation,
    amphoeTh: amphoe,
    datetime: '2026-11-24 15:00',
  );
}

void main() {
  const engine = AlertEngine();

  group('Formula v2 Python <-> Dart 100% Parity Test Vectors (TV2-1..TV2-9)', () {
    test('TV2-1: ปกติ (W=0.1, R=0.1, F=0.1 -> score 8.0, level 1, no push)', () {
      final res = engine.assessV2(
        levelMsl: 12.05,
        previousMsl: 12.05,
        bankM: 13.85,
        hNormal30d: 11.85,
        situationLevel: 1,
        rain1hMm: 6.0,
        forecast24hMm: 12.0,
      );
      expect(res.score, 8.0);
      expect(res.level, AlertLevel.normal);
      expect(res.shouldPush, isFalse);
    });

    test('TV2-2: น้ำถึงตลิ่ง (W=1.0 -> score 45.0, level 3, push)', () {
      final res = engine.assessV2(
        levelMsl: 13.85,
        previousMsl: 13.85,
        bankM: 13.85,
        situationLevel: 3,
      );
      expect(res.score, 45.0);
      expect(res.level, AlertLevel.warning);
      expect(res.shouldPush, isTrue);
    });

    test('TV2-3: วิกฤตสูงสุดทุกสัญญาณ -> score 100.0, level 5, push', () {
      final res = engine.assessV2(
        levelMsl: 14.0,
        previousMsl: 13.65,
        bankM: 13.85,
        situationLevel: 4,
        rain1hMm: 70.0,
        forecast24hMm: 140.0,
        damSignal: 1.0,
        damSpillwayActive: true,
        communityReports60m: 6,
        isFlashFlood: true,
      );
      expect(res.score, 100.0);
      expect(res.level, AlertLevel.danger);
      expect(res.shouldPush, isTrue);
    });

    test('TV2-4: ฝนอย่างเดียวไม่มีหลักฐานน้ำ -> score 23.7, level 2, NO PUSH', () {
      final res = engine.assessV2(
        levelMsl: 10.0,
        previousMsl: 10.0,
        bankM: 13.85,
        rain1hMm: 54.0,
        forecast24hMm: 36.0,
      );
      expect(res.score, 23.7);
      expect(res.level, AlertLevel.watch);
      expect(res.shouldPush, isFalse);
    });

    test('TV2-5: เขื่อนบางลางล้น Spillway -> score 26.0, override level 3, push + lead time', () {
      final res = engine.assessV2(
        levelMsl: 12.25,
        previousMsl: 12.25,
        bankM: 13.85,
        situationLevel: 1,
        rain1hMm: 12.0,
        forecast24hMm: 24.0,
        damSignal: 1.0,
        damSpillwayActive: true,
        leadTimeHours: '6–12 ชม.',
      );
      expect(res.score, 26.0);
      expect(res.level, AlertLevel.warning);
      expect(res.shouldPush, isTrue);
      expect(res.leadTimeHours, '6–12 ชม.');
    });

    test('TV2-6: อ.กาบัง (0 สถานีน้ำ) ฝนหนัก+พยากรณ์หนัก -> score 26.5, level 3, push', () {
      final res = engine.assessV2(
        rain1hMm: 51.0,
        forecast24hMm: 72.0,
        isFlashFlood: true,
        hasWaterGauge: false,
      );
      expect(res.score, 26.5);
      expect(res.level, AlertLevel.warning);
      expect(res.shouldPush, isTrue);
    });

    test('TV2-7: Flash flood ฝนหนัก + รายงานชุมชนหนาแน่น -> score 22.5, level 4 (+2), push', () {
      final res = engine.assessV2(
        levelMsl: 10.0,
        previousMsl: 10.0,
        bankM: 13.85,
        rain1hMm: 45.0,
        communityReports60m: 3,
        isFlashFlood: true,
      );
      expect(res.score, 22.5);
      expect(res.level, AlertLevel.high);
      expect(res.shouldPush, isTrue);
    });

    test('TV2-8: น้ำขึ้นเร็ว dH=0.35 ม. -> score 29.3 (half-up parity), level 3, push', () {
      final res = engine.assessV2(
        levelMsl: 12.85,
        previousMsl: 12.50,
        bankM: 13.85,
        situationLevel: 2,
        isFlashFlood: true,
      );
      expect(res.score, 29.3);
      expect(res.level, AlertLevel.warning);
      expect(res.shouldPush, isTrue);
    });

    test('TV2-9: ไม่มีตลิ่งแต่ situation_level=4 -> score 45.0, floor level 4, push', () {
      final res = engine.assessV2(
        levelMsl: 100.5,
        previousMsl: 100.5,
        situationLevel: 4,
      );
      expect(res.score, 45.0);
      expect(res.level, AlertLevel.high);
      expect(res.shouldPush, isTrue);
    });

    test('TV2-10: IEEE-754 boundary 39.95 -> 40.0 (level 3) Python <-> Dart parity', () {
      final res = engine.assessV2(
        levelMsl: 10.0,
        previousMsl: 10.0,
        bankM: 13.85,
        rain1hMm: 42.0,
        forecast24hMm: 42.0,
        damSignal: 1.0,
        communityReports60m: 5,
      );
      expect(res.score, 40.0);
      expect(res.level, AlertLevel.warning);
      expect(res.shouldPush, isTrue);
    });
  });

  group('QA Regression Tests (HIGH-1 clearTumbon & MEDIUM-5 bankLevel)', () {
    test('AlertSettings.copyWith(clearTumbon: true) ล้างตำบลได้จริงเมื่อเปลี่ยนอำเภอ', () {
      const s = AlertSettings(selectedAmphoeTh: 'เมืองยะลา', selectedTumbonTh: 'ตาเซะ');
      final switched = s.copyWith(selectedAmphoeTh: 'เบตง', clearTumbon: true);
      expect(switched.selectedAmphoeTh, 'เบตง');
      expect(switched.selectedTumbonTh, isNull);
    });

    test('Station.bankLevel ข้าม leftBank=0 ไปใช้ rightBank ที่เป็นบวก', () {
      const st = Station(
        id: 1,
        code: 'T1',
        nameTh: 'ทดสอบ',
        leftBank: 0.0,
        rightBank: 15.5,
      );
      expect(st.bankLevel, 15.5);
      expect(st.hasBank, isTrue);
    });
  });

  group('Hysteresis (2h) & Cooldown (30m)', () {
    test('คงระดับสูงไว้ 2 ชม. เมื่อคะแนนลดลง', () {
      final t0 = DateTime(2026, 11, 24, 10, 0);
      final memory = StationAlertMemory(
        level: AlertLevel.danger,
        updatedAt: t0,
        lastNotifiedAt: t0,
      );
      // 90 นาทีต่อมา -> ยังคงระดับ 5
      expect(
        engine.applyHysteresis(
          current: AlertLevel.watch,
          memory: memory,
          now: t0.add(const Duration(minutes: 90)),
        ),
        AlertLevel.danger,
      );
      // 130 นาทีต่อมา -> ลดระดับลงได้
      expect(
        engine.applyHysteresis(
          current: AlertLevel.watch,
          memory: memory,
          now: t0.add(const Duration(minutes: 130)),
        ),
        AlertLevel.watch,
      );
    });

    test('Cooldown 30 นาที: ไม่ส่งซ้ำระดับเดิมก่อนครบ 30 นาที แต่ระดับสูงขึ้นส่งทันที', () {
      final t0 = DateTime(2026, 11, 24, 10, 0);
      final memory = StationAlertMemory(
        level: AlertLevel.warning,
        updatedAt: t0,
        lastNotifiedAt: t0,
      );
      expect(
        engine.shouldNotifyWithCooldown(
          effective: AlertLevel.warning,
          memory: memory,
          now: t0.add(const Duration(minutes: 15)),
        ),
        isFalse,
      );
      expect(
        engine.shouldNotifyWithCooldown(
          effective: AlertLevel.warning,
          memory: memory,
          now: t0.add(const Duration(minutes: 31)),
        ),
        isTrue,
      );
      expect(
        engine.shouldNotifyWithCooldown(
          effective: AlertLevel.high,
          memory: memory,
          now: t0.add(const Duration(minutes: 5)),
        ),
        isTrue,
      );
    });
  });

  group('AlertEngine.effectiveRisk & evaluate (Backward Compatibility)', () {
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

    test('คะแนนฝนสูงปรับระดับขึ้นได้เมื่อมีหลักฐานน้ำ', () {
      const rain = RainForecast(score: 90, source: 'ThaiWater', summaryTh: 'ฝนตกหนัก');
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
      const rain = RainForecast(score: 95, source: 'ThaiWater', summaryTh: '');
      final level = engine.effectiveRisk(
        _station(code: 'A', situation: 2),
        const AlertSettings(rainScoreEnabled: false),
        rain: rain,
      );
      expect(level, RiskLevel.watch);
    });

    test('สร้างแจ้งเตือนเฉพาะสถานีที่ถึงเกณฑ์ และไม่ซ้ำใน Cooldown 30 นาที', () {
      final stations = [
        _station(code: 'DANGER', situation: 4, wl: 13.0, bank: 13.85),
        _station(code: 'WARN', situation: 3),
        _station(code: 'WATCH', situation: 2),
        _station(code: 'NORMAL', situation: 1),
      ];
      final now = DateTime(2026, 11, 24, 12, 0);
      final first = engine.evaluate(stations: stations, now: now);
      expect(first.map((a) => a.stationCode).toSet(), {'DANGER', 'WARN'});
      expect(first.first.level, RiskLevel.danger);
      expect(first.first.message, contains('13.00'));
      expect(first.first.message, contains('0.85'));

      final withinCooldown = engine.evaluate(
        stations: stations,
        now: now.add(const Duration(minutes: 10)),
        previous: first,
      );
      expect(withinCooldown, isEmpty);
    });

    test('กรองตามอำเภอที่เลือกได้ถูกต้อง', () {
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
  });

  group('Zero-Hallucination Emergency Contacts Verification (DEC-013)', () {
    test('เบอร์ฉุกเฉินต้องถูกต้องตาม ปภ. (1784 / 073203559 / 073212345 / 1669)', () {
      expect(AppConfig.emergencyDDPM, '1784');
      expect(AppConfig.emergencyYalaCenter, '073203559');
      expect(AppConfig.emergencyYalaMunicipality, '073212345');
      expect(AppConfig.emergencyMedical, '1669');
      expect(AppConfig.emergencyVolunteer, '1677');
    });

    test('Google Maps Directions URL และ 4 ภาษา (th/en/zh/ms) ทำงานถูกต้อง', () {
      expect(
        AppConfig.googleMapsDirectionsUrl(6.5415, 101.2812),
        'https://www.google.com/maps/dir/?api=1&destination=6.5415,101.2812&travelmode=driving',
      );
      expect(AppConfig.googleMapsTileUrl('zh'), contains('hl=zh-CN'));
      final s = const AlertSettings().copyWith(languageCode: 'ms');
      expect(AlertSettings.fromJson(s.toJson()).languageCode, 'ms');
      expect(const AppStrings('th').get('tab_shelters'), 'ศูนย์พักพิง');
      expect(const AppStrings('en').get('tab_shelters'), 'Shelters');
      expect(const AppStrings('zh').get('tab_shelters'), '避难中心');
      expect(const AppStrings('ms').get('tab_shelters'), 'Pusat Pemindahan');
      // UTC 09:30 -> Thailand UTC+7 16:30
      expect(
        AppStrings.formatThailandTime(DateTime.utc(2026, 11, 24, 9, 30)),
        contains('16:30 น. (เวลาไทย UTC+7)'),
      );
    });

    test('GeoJSON ขอบเขต 8 อำเภอ จ.ยะลา parse ได้ครบทั้ง 8 อำเภอ', () {
      final raw = File('assets/geo/yala_amphoes.geojson').readAsStringSync();
      final bounds = SnapshotService.parseGeoJsonBoundaries(raw);
      expect(bounds.length, 8);
      expect(bounds.map((b) => b.amphoeTh).toSet(), containsAll(AppConfig.riskAmphoeTh));
    });
  });
}
