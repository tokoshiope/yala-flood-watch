import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/rain_forecast.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/services/alert_engine.dart';
import 'package:yala_flood_app/services/notification_service.dart';
import 'package:yala_flood_app/services/snapshot_service.dart';

Station _station({
  required String code,
  int? situation,
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

  group('Hysteresis (3h per research §5ง) & Cooldown (30m)', () {
    test('คงระดับสูงไว้ 3 ชม. เมื่อคะแนนลดลง', () {
      final t0 = DateTime(2026, 11, 24, 10, 0);
      final memory = StationAlertMemory(
        level: AlertLevel.danger,
        updatedAt: t0,
        lastNotifiedAt: t0,
      );
      // 150 นาทีต่อมา -> ยังคงระดับ 5
      expect(
        engine.applyHysteresis(
          current: AlertLevel.watch,
          memory: memory,
          now: t0.add(const Duration(minutes: 150)),
        ),
        AlertLevel.danger,
      );
      // 190 นาทีต่อมา -> ลดระดับลงได้
      expect(
        engine.applyHysteresis(
          current: AlertLevel.watch,
          memory: memory,
          now: t0.add(const Duration(minutes: 190)),
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

  group('AlertEngine.assessV4 (100% Parity กับ Python backend/pipeline.py formula_version = 4)', () {
    test('TV4-1: ต่ำกว่าเส้นเฝ้าระวัง + ThaiWater sit=3 (น้ำปกติ) -> ปกติ Lv 1', () {
      final r = engine.assessV4(
        levelMsl: 12.59,
        previousMsl: 12.64,
        bankM: 17.29,
        watchM: 15.80,
        criticalM: 17.29,
        situationLevel: 3,
        rain24hMm: 15.0,
      );
      expect(r.score, 1.8);
      expect(r.waterStageLevel, AlertLevel.normal);
      expect(r.level, AlertLevel.normal);
      expect(r.alertBasis, 'monitoring');
      expect(r.waterTrend, 'sideway');
      expect(r.shouldPush, isFalse);
    });

    test('TV4-2: ต่ำกว่าเส้นเฝ้าระวัง + ThaiWater sit=4 (น้ำมาก) ไม่หลอนเป็นเตือนภัยสูง -> ปกติ Lv 1', () {
      final r = engine.assessV4(
        levelMsl: 36.01,
        previousMsl: 36.00,
        bankM: 38.678,
        watchM: 36.80,
        criticalM: 38.678,
        situationLevel: 4,
        rain24hMm: 20.0,
      );
      expect(r.score, 2.4);
      expect(r.waterStageLevel, AlertLevel.normal);
      expect(r.level, AlertLevel.normal);
      expect(r.alertBasis, 'monitoring');
      expect(r.waterTrend, 'sideway');
      expect(r.shouldPush, isFalse);
    });

    test('TV4-3: PAT002 แตะเส้นเฝ้าระวัง + side way -> เฝ้าระวัง Lv 2', () {
      final r = engine.assessV4(
        levelMsl: 12.43,
        previousMsl: 12.43,
        bankM: 13.85,
        watchM: 12.35,
        criticalM: 13.85,
        situationLevel: 4,
      );
      expect(r.score, 18.8);
      expect(r.waterStageLevel, AlertLevel.watch);
      expect(r.level, AlertLevel.watch);
      expect(r.alertBasis, 'water_stage');
      expect(r.waterTrend, 'sideway');
      expect(r.shouldPush, isTrue);
    });

    test('TV4-4: แตะเส้นเฝ้าระวัง + ขึ้นเร็ว dH=+0.20 -> เตือนภัย Lv 3', () {
      final r = engine.assessV4(
        levelMsl: 15.70,
        previousMsl: 15.50,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
      );
      expect(r.score, 25.0);
      expect(r.waterStageLevel, AlertLevel.warning);
      expect(r.level, AlertLevel.warning);
      expect(r.alertBasis, 'water_stage');
      expect(r.waterTrend, 'rising');
      expect(r.shouldPush, isTrue);
    });

    test('TV4-5: แตะเส้นกึ่งกลาง (mid=16.00) + แนวโน้มสูงขึ้น -> เตือนภัย Lv 3', () {
      final r = engine.assessV4(
        levelMsl: 16.05,
        previousMsl: 15.95,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
      );
      expect(r.score, 32.0);
      expect(r.waterStageLevel, AlertLevel.warning);
      expect(r.level, AlertLevel.warning);
      expect(r.alertBasis, 'water_stage');
      expect(r.waterTrend, 'rising');
      expect(r.shouldPush, isTrue);
    });

    test('TV4-6: เหนือเส้นกึ่งกลางเกือบถึงตลิ่ง (high=16.25 <= 16.35 < 16.50) -> เตือนภัยสูง Lv 4', () {
      final r = engine.assessV4(
        levelMsl: 16.35,
        previousMsl: 16.30,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
      );
      expect(r.score, 44.0);
      expect(r.waterStageLevel, AlertLevel.high);
      expect(r.level, AlertLevel.high);
      expect(r.alertBasis, 'water_stage');
      expect(r.waterTrend, 'sideway');
      expect(r.shouldPush, isTrue);
    });

    test('TV4-7: เลยเส้นตลิ่ง (>= 16.50) แม้ situation_level=null -> อันตราย Lv 5', () {
      final r = engine.assessV4(
        levelMsl: 16.52,
        previousMsl: 16.40,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
      );
      expect(r.score, 50.0);
      expect(r.waterStageLevel, AlertLevel.danger);
      expect(r.level, AlertLevel.danger);
      expect(r.alertBasis, 'water_stage');
      expect(r.waterTrend, 'rising');
      expect(r.shouldPush, isTrue);
    });

    test('TV4-8: X.77 เกณฑ์วิกฤต สทภ.8 (39.70 ม.) -> อันตราย Lv 5', () {
      final r = engine.assessV4(
        levelMsl: 39.75,
        previousMsl: 39.60,
        bankM: 40.30,
        watchM: 38.00,
        criticalM: 39.70,
      );
      expect(r.score, 50.0);
      expect(r.waterStageLevel, AlertLevel.danger);
      expect(r.level, AlertLevel.danger);
      expect(r.alertBasis, 'water_stage');
      expect(r.waterTrend, 'rising');
      expect(r.shouldPush, isTrue);
    });

    test('TV4-9: เตือนภัยล่วงหน้าฝนท่วมขังเขตเมือง (Option 1 สูงสุด Lv 3) พร้อมป้ายเหตุผล', () {
      final r = engine.assessV4(
        levelMsl: 14.20,
        previousMsl: 14.15,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
        rain24hMm: 155.0,
        rain72hMm: 333.8,
        api7dMm: 120.0,
        isUrbanBasin: true,
      );
      expect(r.score, 23.3);
      expect(r.waterStageLevel, AlertLevel.normal);
      expect(r.level, AlertLevel.warning);
      expect(r.alertBasis, 'rain_dam_early_warning');
      expect(r.waterTrend, 'sideway');
      expect(r.shouldPush, isTrue);
    });

    test('TV4-10: เขื่อนบางลางเปิด Spillway (Option 1 สูงสุด Lv 3) แม้ระดับน้ำยังต่ำกว่าเฝ้าระวัง', () {
      final r = engine.assessV4(
        levelMsl: 13.50,
        previousMsl: 13.50,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
        situationLevel: 3,
        damSignal: 1.0,
        damSpillwayActive: true,
        leadTimeHours: '6–12 ชม.',
      );
      expect(r.score, 8.0);
      expect(r.waterStageLevel, AlertLevel.normal);
      expect(r.level, AlertLevel.warning);
      expect(r.alertBasis, 'rain_dam_early_warning');
      expect(r.waterTrend, 'sideway');
      expect(r.shouldPush, isTrue);
    });

    test('TV4-11: อ.กาบัง (0 สถานีวัดน้ำ) ฝนหนักน้ำป่า (Option 1 สูงสุด Lv 3)', () {
      final r = engine.assessV4(
        rain1hMm: 51.0,
        api7dMm: 110.0,
        forecast24hMm: 72.0,
        isFlashFlood: true,
        hasWaterGauge: false,
      );
      expect(r.score, 26.7);
      expect(r.waterStageLevel, AlertLevel.normal);
      expect(r.level, AlertLevel.warning);
      expect(r.alertBasis, 'rain_dam_early_warning');
      expect(r.waterTrend, 'unknown');
      expect(r.shouldPush, isTrue);
    });

    test('TV4-12: ThaiWater situation_level=5 ยืนยันล้นตลิ่ง -> อันตราย Lv 5', () {
      final r = engine.assessV4(situationLevel: 5);
      expect(r.score, 50.0);
      expect(r.waterStageLevel, AlertLevel.normal);
      expect(r.level, AlertLevel.danger);
      expect(r.alertBasis, 'agency_overflow');
      expect(r.waterTrend, 'unknown');
      expect(r.shouldPush, isTrue);
    });

    test('TV4-13: เส้นกึ่งกลางพร้อมพุ่งขึ้นรุนแรง dH>=0.30 -> เตือนภัยสูง Lv 4', () {
      final r = engine.assessV4(
        levelMsl: 16.10,
        previousMsl: 15.75,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
      );
      expect(r.score, 39.0);
      expect(r.waterStageLevel, AlertLevel.high);
      expect(r.level, AlertLevel.high);
      expect(r.alertBasis, 'water_stage');
      expect(r.waterTrend, 'rising');
      expect(r.shouldPush, isTrue);
    });

    test('TV4-14: สถานีไร้ตลิ่ง + ThaiWater situation_level=4 -> Fallback เฝ้าระวัง Lv 2', () {
      final r = engine.assessV4(
        levelMsl: 101.0,
        previousMsl: 101.0,
        situationLevel: 4,
      );
      expect(r.score, 17.5);
      expect(r.waterStageLevel, AlertLevel.watch);
      expect(r.level, AlertLevel.watch);
      expect(r.alertBasis, 'water_stage');
      expect(r.waterTrend, 'sideway');
      expect(r.shouldPush, isTrue);
    });
  });

  group('AlertEngine.effectiveRisk & evaluate (Formula v4 Water-Stage 5 Levels)', () {
    test('ThaiWater situation_level 5=อันตราย, 4=เฝ้าระวัง(ไร้ตลิ่ง), 1-3=ปกติ', () {
      expect(
        engine.effectiveRisk(_station(code: 'A', situation: 5), const AlertSettings()),
        RiskLevel.danger,
      );
      expect(
        engine.effectiveRisk(_station(code: 'B', situation: 4), const AlertSettings()),
        RiskLevel.watch,
      );
      expect(
        engine.effectiveRisk(_station(code: 'C', situation: 3), const AlertSettings()),
        RiskLevel.normal,
      );
    });

    test('ระดับน้ำเทียบเส้นเฝ้าระวัง/กึ่งกลาง/ตลิ่ง ครบ 5 ระดับ', () {
      // bank=16.50, watch=15.00 (default crit-1.5), mid=15.75, high=16.125
      expect(
        engine.effectiveRisk(_station(code: 'S1', wl: 14.50, bank: 16.50), const AlertSettings()),
        RiskLevel.normal,
      );
      expect(
        engine.effectiveRisk(_station(code: 'S2', wl: 15.20, bank: 16.50), const AlertSettings()),
        RiskLevel.watch,
      );
      expect(
        engine.effectiveRisk(_station(code: 'S3', wl: 15.80, bank: 16.50), const AlertSettings()),
        RiskLevel.warning,
      );
      expect(
        engine.effectiveRisk(_station(code: 'S4', wl: 16.20, bank: 16.50), const AlertSettings()),
        RiskLevel.high,
      );
      expect(
        engine.effectiveRisk(_station(code: 'S5', wl: 16.55, bank: 16.50), const AlertSettings()),
        RiskLevel.danger,
      );
    });

    test('คะแนนฝนสูงยกระดับได้สูงสุด Lv 3 (Option 1 cap) เมื่อมีหลักฐานน้ำ และไม่ดันเกิน Lv 3', () {
      const rain = RainForecast(score: 90, source: 'ThaiWater', summaryTh: 'ฝนตกหนัก');
      final watchBase = engine.effectiveRisk(
        _station(code: 'A', wl: 15.20, bank: 16.50),
        const AlertSettings(),
      );
      final watchWithRain = engine.effectiveRisk(
        _station(code: 'A', wl: 15.20, bank: 16.50),
        const AlertSettings(),
        rain: rain,
      );
      expect(watchBase, RiskLevel.watch);
      expect(watchWithRain, RiskLevel.warning);

      final warnWithRain = engine.effectiveRisk(
        _station(code: 'B', wl: 15.80, bank: 16.50),
        const AlertSettings(),
        rain: rain,
      );
      expect(warnWithRain, RiskLevel.warning);
    });

    test('QA MEDIUM-2 regression: evaluate() คงระดับผ่าน Hysteresis 3 ชม. แม้น้ำลดลงต่ำกว่าเส้นเฝ้าระวังชั่วคราว', () {
      final t0 = DateTime(2026, 11, 27, 10, 0);
      final memory = {
        'X.40A': StationAlertMemory(
          level: AlertLevel.high,
          updatedAt: t0,
          lastNotifiedAt: t0,
        ),
      };
      // น้ำลดลงต่ำกว่าเส้นเฝ้าระวังชั่วคราวภายใน 1 ชม. (< 3 ชม.) -> ยังต้องคงระดับเตือนภัยสูงไว้
      final held = engine.evaluate(
        stations: [
          _station(code: 'X.40A', wl: 14.80, prev: 15.20, bank: 16.50),
        ],
        memoryByStation: memory,
        now: t0.add(const Duration(hours: 1)),
      );
      expect(held, isNotEmpty);
      expect(held.first.level, RiskLevel.high);
      expect(held.first.alertLevel, AlertLevel.high);

      // หลังครบ 3 ชม. แล้ว -> ปล่อยให้กลับสู่ปกติได้
      final released = engine.evaluate(
        stations: [
          _station(code: 'X.40A', wl: 14.80, prev: 15.20, bank: 16.50),
        ],
        memoryByStation: memory,
        now: t0.add(const Duration(hours: 3, minutes: 5)),
      );
      expect(released, isEmpty);
    });

    test('ปิดการใช้คะแนนฝนแล้วระดับไม่เปลี่ยน', () {
      const rain = RainForecast(score: 95, source: 'ThaiWater', summaryTh: '');
      final level = engine.effectiveRisk(
        _station(code: 'A', wl: 15.20, bank: 16.50),
        const AlertSettings(rainScoreEnabled: false),
        rain: rain,
      );
      expect(level, RiskLevel.watch);
    });

    test('สร้างแจ้งเตือนเฉพาะสถานีที่ถึงเกณฑ์ และไม่ซ้ำใน Cooldown 30 นาที', () {
      final stations = [
        _station(code: 'DANGER', wl: 16.60, bank: 16.50),
        _station(code: 'HIGH', wl: 16.25, bank: 16.50),
        _station(code: 'WARN', wl: 15.80, bank: 16.50),
        _station(code: 'WATCH', wl: 15.20, bank: 16.50),
        _station(code: 'NORMAL', wl: 14.00, bank: 16.50),
      ];
      final now = DateTime(2026, 11, 24, 12, 0);
      final first = engine.evaluate(stations: stations, now: now);
      expect(first.map((a) => a.stationCode).toSet(), {'DANGER', 'HIGH', 'WARN'});
      expect(first.first.level, RiskLevel.danger);
      expect(first.first.message, contains('16.60'));
      expect(first.first.message, isNot(contains('คะแนนความเสี่ยง')));

      final withinCooldown = engine.evaluate(
        stations: stations,
        now: now.add(const Duration(minutes: 10)),
        previous: first,
      );
      expect(withinCooldown, isEmpty);
    });

    test('กรองตามอำเภอที่เลือกได้ถูกต้อง', () {
      final stations = [
        _station(code: 'A', wl: 16.60, bank: 16.50, amphoe: 'เมืองยะลา'),
        _station(code: 'B', wl: 16.60, bank: 16.50, amphoe: 'เบตง'),
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

    test('GeoJSON ขอบเขต 8 อำเภอ, 58 ตำบล และ 449 หมู่บ้าน จ.ยะลา parse ได้ครบพร้อมความสูง MSL', () {
      final raw = File('assets/geo/yala_amphoes.geojson').readAsStringSync();
      final bounds = SnapshotService.parseGeoJsonBoundaries(raw);
      expect(bounds.length, 8);
      expect(bounds.map((b) => b.amphoeTh).toSet(), containsAll(AppConfig.riskAmphoeTh));

      final subRaw = File('assets/geo/yala_subdistricts.geojson').readAsStringSync();
      final subs = SnapshotService.parseGeoJsonSubdistricts(subRaw);
      expect(subs.length, 58);
      expect(subs.every((s) => s.elevationMsl != null), isTrue);

      final vilRaw = File('assets/geo/yala_villages.json').readAsStringSync();
      final vils = SnapshotService.parseVillagesJson(vilRaw);
      expect(vils.length, 449);
      expect(vils.every((v) => v.elevationMsl != null), isTrue);

      // ตรวจสอบชื่อแอปและแท็บใหม่ + ลิงก์ LINE/FB ที่ตรวจสอบแล้ว
      expect(const AppStrings('th').get('app_title'), 'แจ้งเตือนน้ำท่วมยะลา');
      expect(const AppStrings('th').get('tab_home'), 'แผนที่');
      expect(const AppStrings('th').get('tab_alerts'), 'ข้อมูล');
      expect(AppConfig.lineDdpmUrl, 'https://line.me/R/ti/p/@1784DDPM');
      expect(AppConfig.lineYalaCityUrl, 'https://line.me/R/ti/p/@yalacity');
      expect(AppConfig.fbDdpmUrl, 'https://www.facebook.com/DDPMNews');

      // ตรวจสอบความตรงกันของ FCM Topic ASCII ทั้ง 8 อำเภอ + largeTextMode persistence
      final asciiTopicRegex = RegExp(r'^[a-zA-Z0-9\-_.~%]+$');
      expect(asciiTopicRegex.hasMatch(NotificationService.topicAllYala), isTrue);
      for (final amp in AppConfig.riskAmphoeTh) {
        final topic = NotificationService.topicForAmphoe(amp);
        expect(topic, isNot(NotificationService.topicAllYala));
        expect(asciiTopicRegex.hasMatch(topic), isTrue);
      }
      final large = const AlertSettings().copyWith(largeTextMode: true);
      expect(AlertSettings.fromJson(large.toJson()).largeTextMode, isTrue);

      // MEDIUM-1 regression: SnapshotService fail-closed validation (province 95 + 8 amphoes + manifest hash)
      final validSnap = <String, dynamic>{
        'province': {'code': '95', 'name': 'ยะลา'},
        'amphoes': List.generate(8, (i) => {'amphoe': AppConfig.riskAmphoeTh[i]}),
        'content_hash': 'abc123',
      };
      expect(SnapshotService.isValidYalaSnapshot(validSnap, expectedManifestHash: 'abc123'), isTrue);
      expect(SnapshotService.isValidYalaSnapshot(validSnap, expectedManifestHash: 'tampered'), isFalse);
      expect(
        SnapshotService.isValidYalaSnapshot(
          {...validSnap, 'province': {'code': '10'}},
          expectedManifestHash: 'abc123',
        ),
        isFalse,
      );
    });
  });
}
