import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/services/alert_engine.dart';
import 'package:yala_flood_app/services/notification_service.dart';
import 'package:yala_flood_app/services/snapshot_service.dart';

Station _station({
  required String code,
  String name = 'สถานีทดสอบ',
  double? wl,
  double? prev,
  double? bank,
  int? situation,
  String amphoe = 'เมืองยะลา',
  String tumbon = 'สะเตง',
}) {
  return Station(
    id: code.hashCode,
    code: code,
    nameTh: name,
    waterLevelMsl: wl,
    waterLevelMslPrev: prev,
    leftBank: bank,
    situationLevel: situation,
    amphoeTh: amphoe,
    tumbonTh: tumbon,
  );
}

void main() {
  const engine = AlertEngine();

  group('AlertEngine.assessV5 (100% Parity กับ Python backend/pipeline.py formula_version = 5)', () {
    test('TV5-1: ต่ำกว่าเส้นเฝ้าระวัง + ThaiWater sit=3 -> ปกติ Lv 1', () {
      final r = engine.assessV5(
        levelMsl: 14.00,
        previousMsl: 14.00,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
        situationLevel: 3,
      );
      expect(r.level, AlertLevel.normal);
      expect(r.alertBasis, 'monitoring');
      expect(r.shouldPush, isFalse);
    });

    test('TV5-2: PAT002 watch=13.30 — ระดับควบคุมปกติ 12.85 ม. คง Lv 1 ไม่แจ้งเตือนลวง', () {
      final r = engine.assessV5(
        levelMsl: 12.85,
        previousMsl: 12.85,
        bankM: 13.85,
        watchM: AppConfig.stationWatchMsl['PAT002'],
        criticalM: 13.85,
        situationLevel: 4,
      );
      expect(AppConfig.stationWatchMsl['PAT002'], 13.30);
      expect(r.level, AlertLevel.normal);
      expect(r.alertBasis, 'monitoring');
      expect(r.shouldPush, isFalse);
    });

    test('TV5-3: แตะเส้นเฝ้าระวังแบบทรงตัว -> Lv 2 เฝ้าระวัง', () {
      final r = engine.assessV5(
        levelMsl: 15.70,
        previousMsl: 15.68,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
        situationLevel: 4,
      );
      expect(r.level, AlertLevel.watch);
      expect(r.alertBasis, 'water_stage');
      expect(r.shouldPush, isTrue);
    });

    test('TV5-4: อยู่ในช่วงเฝ้าระวังแต่ขึ้นเร็วจนคาดล้นตลิ่ง <= 6 ชม. -> Lv 4 เตือนภัยสูงล่วงหน้า', () {
      final r = engine.assessV5(
        levelMsl: 15.70,
        previousMsl: 15.54,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
        situationLevel: 4,
      );
      expect(r.timeToBankH, 5.0);
      expect(r.level, AlertLevel.high);
      expect(r.alertBasis, 'water_stage');
      expect(r.shouldPush, isTrue);
    });

    test('TV5-5: อยู่ในช่วงเฝ้าระวังและคาดล้นตลิ่ง <= 24 ชม. -> Lv 3 เตือนภัยล่วงหน้า', () {
      final r = engine.assessV5(
        levelMsl: 15.70,
        previousMsl: 15.64,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
        situationLevel: 4,
      );
      expect(r.level, AlertLevel.warning);
      expect(r.alertBasis, 'water_stage');
      expect(r.shouldPush, isTrue);
    });

    test('TV5-6: แตะเส้นกึ่งกลางทรงตัว -> Lv 3 เตือนภัย', () {
      final r = engine.assessV5(
        levelMsl: 16.10,
        previousMsl: 16.10,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
      );
      expect(r.level, AlertLevel.warning);
      expect(r.alertBasis, 'water_stage');
      expect(r.shouldPush, isTrue);
    });

    test('TV5-7: เส้นกึ่งกลาง + พุ่งขึ้นรุนแรง dH >= 0.30 -> Lv 4 เตือนภัยสูง', () {
      final r = engine.assessV5(
        levelMsl: 16.05,
        previousMsl: 15.73,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
      );
      expect(r.level, AlertLevel.high);
      expect(r.alertBasis, 'water_stage');
      expect(r.shouldPush, isTrue);
    });

    test('TV5-8: สูงกว่า 75% เข้าใกล้ตลิ่ง -> Lv 4 เตือนภัยสูง', () {
      final r = engine.assessV5(
        levelMsl: 16.35,
        previousMsl: 16.35,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
      );
      expect(r.level, AlertLevel.high);
      expect(r.alertBasis, 'water_stage');
      expect(r.shouldPush, isTrue);
    });

    test('TV5-9 & TV5-10: ล้นตลิ่ง (H >= crit หรือ sit == 5) -> Lv 5 อันตราย', () {
      final r1 = engine.assessV5(
        levelMsl: 16.55,
        previousMsl: 16.40,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
      );
      expect(r1.level, AlertLevel.danger);
      expect(r1.alertBasis, 'water_stage');

      final r2 = engine.assessV5(
        levelMsl: 14.00,
        previousMsl: 14.00,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
        situationLevel: 5,
      );
      expect(r2.level, AlertLevel.danger);
      expect(r2.alertBasis, 'agency_overflow');
    });

    test('TV5-11: FOP045 datum_unverified=true ขึ้นเร็ว dH=+0.32 -> Lv 3 ไม่ถูกช่องว่างตลิ่ง 19.3 ม. กดทับ', () {
      final r = engine.assessV5(
        levelMsl: 6.12,
        previousMsl: 5.80,
        bankM: 25.128,
        watchM: 23.20,
        criticalM: 25.128,
        datumUnverified: true,
        isFlashFlood: true,
      );
      expect(r.level, AlertLevel.warning);
      expect(r.confidence, 'medium');
      expect(r.flags, contains('datum_unverified'));
      expect(r.shouldPush, isTrue);
    });

    test('TV5-12 & TV5-13 & TV5-14: เขื่อนบางลาง Elevated Lv 2 / Spillway Lv 3 / Critical Compound Lv 4', () {
      final lv2 = engine.assessV5(
        levelMsl: 12.00,
        previousMsl: 12.00,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
        damSignal: 0.45,
        leadTimeHours: '6–12 ชม.',
      );
      expect(lv2.level, AlertLevel.watch);
      expect(lv2.shouldPush, isTrue);

      final lv3 = engine.assessV5(
        levelMsl: 12.00,
        previousMsl: 12.00,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
        damSignal: 1.0,
        damSpillwayActive: true,
        damInflowDailyMcm: 40.0,
        leadTimeHours: '6–12 ชม.',
      );
      expect(lv3.level, AlertLevel.warning);
      expect(lv3.alertBasis, 'rain_dam_early_warning');

      final lv4 = engine.assessV5(
        levelMsl: 12.00,
        previousMsl: 12.00,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
        damSignal: 1.0,
        damSpillwayActive: true,
        damInflowDailyMcm: 110.0,
        leadTimeHours: '6–12 ชม.',
      );
      expect(lv4.level, AlertLevel.high);
      expect(lv4.alertBasis, 'rain_dam_early_warning');
      expect(lv4.shouldPush, isTrue);
    });

    test('TV5-15 & TV5-16: ฝนเมืองวิกฤต พ.ย.2568 -> Lv 4 ล่วงหน้า (ไม่ข้ามไป Lv 5), ฝนเมืองหนัก -> Lv 3', () {
      final extreme = engine.assessV5(
        levelMsl: 13.00,
        previousMsl: 13.00,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
        rain1hMm: 30.0,
        rain24hMm: 160.0,
        rain72hMm: 334.0,
        api7dMm: 150.0,
        forecast6hMm: 35.0,
        isUrbanBasin: true,
      );
      expect(extreme.level, AlertLevel.high);
      expect(extreme.alertBasis, 'rain_dam_early_warning');
      expect(extreme.shouldPush, isTrue);

      final heavy = engine.assessV5(
        levelMsl: 13.00,
        previousMsl: 13.00,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
        rain1hMm: 50.0,
        rain24hMm: 145.0,
        api7dMm: 95.0,
        isUrbanBasin: true,
      );
      expect(heavy.level, AlertLevel.warning);
      expect(heavy.shouldPush, isTrue);
    });

    test('TV5-17 & TV5-18: อ.กาบัง 0 สถานีน้ำฝนวิกฤต -> Lv 4 ล่วงหน้า, ฝนปานกลางวันปกติ -> Lv 1 ไม่ Push', () {
      final kabang = engine.assessV5(
        rain1hMm: 35.0,
        rain24hMm: 220.0,
        api7dMm: 135.0,
        forecast6hMm: 30.0,
        isFlashFlood: true,
        hasWaterGauge: false,
      );
      expect(kabang.level, AlertLevel.high);
      expect(kabang.alertBasis, 'rain_dam_early_warning');
      expect(kabang.shouldPush, isTrue);

      final dry = engine.assessV5(
        levelMsl: 12.00,
        previousMsl: 12.00,
        bankM: 16.50,
        watchM: 15.50,
        criticalM: 16.50,
        rain1hMm: 20.0,
        rain24hMm: 45.0,
        api7dMm: 30.0,
        isUrbanBasin: true,
      );
      expect(dry.level, AlertLevel.normal);
      expect(dry.shouldPush, isFalse);
    });

    test('Layer 2 Unified Basin Hazard × Terrain Exposure Matrix (Zone A/B/C) ตรง Python 100%', () {
      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 1, exposureZone: 'A'), 1);
      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 1, exposureZone: 'B'), 1);
      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 1, exposureZone: 'C'), 1);

      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 2, exposureZone: 'A'), 2);
      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 2, exposureZone: 'B'), 1);
      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 2, exposureZone: 'C'), 1);

      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 3, exposureZone: 'A'), 3);
      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 3, exposureZone: 'B'), 2);
      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 3, exposureZone: 'C'), 1);

      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 4, exposureZone: 'A'), 4);
      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 4, exposureZone: 'B'), 3);
      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 4, exposureZone: 'C'), 1);

      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 5, exposureZone: 'A'), 5);
      expect(
        AlertEngine.evaluateTerrainExposureLevel(
          basinLevel: 5,
          exposureZone: 'B',
          overflowDepthM: 0.8,
          relHeightM: 2.5,
        ),
        4,
      );
      expect(
        AlertEngine.evaluateTerrainExposureLevel(
          basinLevel: 5,
          exposureZone: 'B',
          overflowDepthM: 2.6,
          relHeightM: 2.5,
        ),
        5,
      );
      expect(AlertEngine.evaluateTerrainExposureLevel(basinLevel: 5, exposureZone: 'C'), 1);
    });
  });

  group('QA Regression Tests (clearTumbon, bankLevel & FOP045 datum_unverified)', () {
    test('AlertSettings.copyWith(clearTumbon: true) ล้างตำบลได้จริงเมื่อเปลี่ยนอำเภอ', () {
      const s = AlertSettings(selectedAmphoeTh: 'เมืองยะลา', selectedTumbonTh: 'ตาเซะ');
      final switched = s.copyWith(selectedAmphoeTh: 'เบตง', clearTumbon: true);
      expect(switched.selectedAmphoeTh, 'เบตง');
      expect(switched.selectedTumbonTh, isNull);
    });

    test('Station.bankLevel ข้าม leftBank=0 ไปใช้ rightBank และ FOP045 ซ่อน remainingToBank', () {
      const st = Station(
        id: 1,
        code: 'T1',
        nameTh: 'ทดสอบ',
        leftBank: 0.0,
        rightBank: 15.5,
      );
      expect(st.bankLevel, 15.5);
      expect(st.hasBank, isTrue);

      final fop = _station(code: 'FOP045', wl: 6.15, prev: 5.80, bank: 25.128, amphoe: 'กรงปินัง');
      expect(fop.isDatumUnverified, isTrue);
      expect(fop.remainingToBank, isNull);
      expect(fop.riskLevel, RiskLevel.warning);
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
      expect(
        engine.applyHysteresis(
          current: AlertLevel.watch,
          memory: memory,
          now: t0.add(const Duration(minutes: 150)),
        ),
        AlertLevel.danger,
      );
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

  group('AlertEngine.evaluate & effectiveRisk (formula_version = 5)', () {
    test('สถานีไม่มีตลิ่งใช้ ThaiWater situation_level 1–5 ถูกต้อง', () {
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

    test('evaluate() คงระดับผ่าน Hysteresis 3 ชม. แม้น้ำลดลงต่ำกว่าเส้นเฝ้าระวังชั่วคราว', () {
      final t0 = DateTime(2026, 11, 27, 10, 0);
      final memory = {
        'X.40A': StationAlertMemory(
          level: AlertLevel.high,
          updatedAt: t0,
          lastNotifiedAt: t0,
        ),
      };
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

      final released = engine.evaluate(
        stations: [
          _station(code: 'X.40A', wl: 14.80, prev: 15.20, bank: 16.50),
        ],
        memoryByStation: memory,
        now: t0.add(const Duration(hours: 3, minutes: 5)),
      );
      expect(released, isEmpty);
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

  group('Zero-Hallucination Emergency Contacts, Curved GeoJSON & Snapshot Integrity', () {
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
      expect(
        AppStrings.formatThailandTime(DateTime.utc(2026, 11, 24, 9, 30)),
        contains('16:30 น. (เวลาไทย UTC+7)'),
      );
    });

    test('GeoJSON ขอบเขต 8 อำเภอ, 58 ตำบล และ 449 หมู่บ้าน จ.ยะลา parse ได้ครบพร้อม Zone A/B/C และ MultiPolygon', () {
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
      expect(vils.map((v) => v.exposureZone).toSet(), {'A', 'B', 'C'});

      final vzRaw = File('assets/geo/yala_village_zones.geojson').readAsStringSync();
      final vz = SnapshotService.parseVillageZones(vzRaw);
      expect(vz.length, greaterThanOrEqualTo(430));
      expect(vz.any((z) => z.rings.length > 1), isTrue); // MultiPolygon supported!

      expect(const AppStrings('th').get('app_title'), 'แจ้งเตือนน้ำท่วมยะลา');
      expect(const AppStrings('th').get('tab_home'), 'แผนที่');
      expect(const AppStrings('th').get('tab_alerts'), 'ข้อมูล');
      expect(AppConfig.lineDdpmUrl, 'https://line.me/R/ti/p/@1784DDPM');
      expect(AppConfig.lineYalaCityUrl, 'https://line.me/R/ti/p/@yalacity');
      expect(AppConfig.fbDdpmUrl, 'https://www.facebook.com/DDPMNews');

      final asciiTopicRegex = RegExp(r'^[a-zA-Z0-9\-_.~%]+$');
      expect(asciiTopicRegex.hasMatch(NotificationService.topicAllYala), isTrue);
      for (final amp in AppConfig.riskAmphoeTh) {
        final topic = NotificationService.topicForAmphoe(amp);
        expect(topic, isNot(NotificationService.topicAllYala));
        expect(asciiTopicRegex.hasMatch(topic), isTrue);
      }
      final large = const AlertSettings().copyWith(largeTextMode: true);
      expect(AlertSettings.fromJson(large.toJson()).largeTextMode, isTrue);

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
