import 'dart:math' as math;

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';

/// ผลลัพธ์การคำนวณ Alert Engine `formula_version = 5` (100% Parity กับ `backend/pipeline.py compute_alert_v5`)
class AssessmentV5 {
  const AssessmentV5({
    required this.score,
    required this.scoreLevel,
    required this.waterStageLevel,
    required this.earlyWarningLevel,
    required this.floorLevel,
    required this.flashBonus,
    required this.level,
    required this.alertBasis,
    required this.waterTrend,
    required this.shouldPush,
    required this.hasPrimarySignal,
    required this.floodMechanism,
    required this.confidence,
    required this.w,
    required this.r,
    required this.a,
    required this.f,
    required this.d,
    required this.c,
    required this.dH,
    this.timeToBankH,
    this.leadTimeHours,
    this.reasonCodes = const <String>[],
    this.flags = const <String>[],
  });

  final double score;
  final AlertLevel scoreLevel;
  final AlertLevel waterStageLevel;
  final AlertLevel earlyWarningLevel;
  final AlertLevel floorLevel;
  final int flashBonus;
  final AlertLevel level;
  final String alertBasis;
  final String waterTrend;
  final bool shouldPush;
  final bool hasPrimarySignal;
  final String floodMechanism;
  final String confidence;
  final double w;
  final double r;
  final double a;
  final double f;
  final double d;
  final double c;
  final double dH;
  final double? timeToBankH;
  final String? leadTimeHours;
  final List<String> reasonCodes;
  final List<String> flags;
}

/// สถานะอ้างอิงสำหรับ Hysteresis (3 ชม.) และ Cooldown (30 นาที)
class StationAlertMemory {
  const StationAlertMemory({
    required this.level,
    required this.updatedAt,
    required this.lastNotifiedAt,
  });

  final AlertLevel level;
  final DateTime updatedAt;
  final DateTime lastNotifiedAt;
}

/// ตรรกะหลักในการประเมินความเสี่ยงและสร้างแจ้งเตือนภัยน้ำท่วมล่วงหน้า (`formula_version = 5`)
///
/// 1) [assessV5] — Layer 1 Basin & Station Hazard (100% Parity กับ Python `compute_alert_v5`)
/// 2) [evaluateTerrainExposureLevel] — Layer 2 Basin Hazard × Terrain Exposure Matrix (Zone A/B/C)
/// 3) [evaluate] — ประเมินสถานี + กรองพื้นที่ + Hysteresis 3 ชม. + Cooldown 30 นาที
class AlertEngine {
  const AlertEngine();

  /// ปัดเศษแบบ half-up ทศนิยม 1 ตำแหน่งให้ตรงกับ Python 100% (กัน NaN/Infinity แบบ Fail-Closed)
  static double _roundHalfUp1(double value) =>
      value.isFinite ? (value * 10.0 + 0.5 + 1e-9).floor() / 10.0 : 0.0;

  static double _round2(double value) =>
      value.isFinite ? (value * 100.0).round() / 100.0 : 0.0;

  /// Layer 2 Unified Basin Hazard × Terrain Exposure Matrix (ตรงกับ Python `evaluate_terrain_exposure_level` 100%)
  static int evaluateTerrainExposureLevel({
    required int basinLevel,
    required String exposureZone,
    double overflowDepthM = 0.0,
    double? relHeightM,
  }) {
    final lv = basinLevel.clamp(1, 5);
    final zone = exposureZone.trim().toUpperCase();
    if (zone == 'C') return 1;
    if (zone == 'B') {
      if (lv <= 2) return 1;
      if (lv == 3) return 2;
      if (lv == 4) return 3;
      if (relHeightM != null && overflowDepthM > 0 && overflowDepthM >= relHeightM) {
        return 5;
      }
      return 4;
    }
    return lv;
  }

  /// สูตรแจ้งเตือนหลัก `formula_version = 5` (ตรงกับ `backend/pipeline.py compute_alert_v5` 100%)
  AssessmentV5 assessV5({
    double? levelMsl,
    double? previousMsl,
    double? bankM,
    double? watchM,
    double? criticalM,
    int? situationLevel,
    bool stale = false,
    bool datumUnverified = false,
    double rain1hMm = 0.0,
    double rain24hMm = 0.0,
    double rain72hMm = 0.0,
    double api7dMm = 0.0,
    double forecast6hMm = 0.0,
    double forecast24hMm = 0.0,
    double forecast72hMm = 0.0,
    double? glofasPeakRatio,
    double damSignal = 0.0,
    bool damSpillwayActive = false,
    double damInflowDailyMcm = 0.0,
    int communityReports60m = 0,
    bool isFlashFlood = false,
    bool isUrbanBasin = false,
    bool hasWaterGauge = true,
    bool rainSensorGap = false,
    String? leadTimeHours,
  }) {
    final flags = <String>[];
    final reasonCodes = <String>[];

    if (rainSensorGap) flags.add('rain_sensor_gap');
    if (datumUnverified) flags.add('datum_unverified');

    // 1. Physical Water-Stage Thresholds (watch, mid, high, crit), dH, & time_to_bank_h
    var dH = 0.0;
    if (levelMsl != null && previousMsl != null && !stale) {
      dH = ((levelMsl - previousMsl) * 10000).round() / 10000.0;
    }

    final String waterTrend;
    if (stale || levelMsl == null) {
      waterTrend = 'unknown';
    } else if (previousMsl == null) {
      waterTrend = 'sideway';
    } else if (dH > AppConfig.steadyBandMeters) {
      waterTrend = 'rising';
    } else if (dH < -AppConfig.steadyBandMeters) {
      waterTrend = 'falling';
    } else {
      waterTrend = 'sideway';
    }

    final crit = (criticalM != null && criticalM > 0)
        ? criticalM
        : ((bankM != null && bankM > 0) ? bankM : null);
    final watch = (crit != null && !datumUnverified)
        ? ((watchM != null && watchM > 0 && watchM < crit) ? watchM : (crit - 1.5))
        : null;
    final midM = (crit != null && watch != null) ? (watch + crit) / 2.0 : null;
    final highM = (crit != null && midM != null) ? (midM + crit) / 2.0 : null;

    double? timeToBankH;
    if (!datumUnverified &&
        !stale &&
        crit != null &&
        levelMsl != null &&
        levelMsl < crit &&
        dH >= 0.05) {
      timeToBankH = _round2((crit - levelMsl) / dH);
    }

    var waterStageLevel = AlertLevel.normal;
    var wVal = 0.0;
    if (stale) {
      flags.add('water_stale');
    } else if (datumUnverified) {
      // สถานีฐานตลิ่งยังไม่ยืนยัน (เช่น FOP045): ใช้ dH/dt แทน bank - level
      if (levelMsl != null && dH >= 0.30) {
        waterStageLevel = AlertLevel.warning;
        wVal = 0.65;
        flags.add('datum_unverified_rapid_surge');
        reasonCodes.add('rapid_rise');
      } else if (levelMsl != null && dH >= 0.15) {
        waterStageLevel = AlertLevel.watch;
        wVal = 0.40;
        flags.add('datum_unverified_rising');
        reasonCodes.add('rising_water');
      }
    } else if (crit != null &&
        watch != null &&
        midM != null &&
        highM != null &&
        levelMsl != null) {
      double wBase;
      if (levelMsl >= crit) {
        waterStageLevel = AlertLevel.danger;
        wBase = 1.0;
        flags.add('bank_overflow');
        reasonCodes.add('bank_overflow');
      } else if (levelMsl >= highM) {
        waterStageLevel = AlertLevel.high;
        wBase = 0.80 + 0.20 * (levelMsl - highM) / (crit - highM);
        flags.add('near_bank_high');
        reasonCodes.add('near_bank_high');
      } else if (levelMsl >= midM) {
        wBase = 0.60 + 0.20 * (levelMsl - midM) / (highM - midM);
        if (dH >= 0.30 || (timeToBankH != null && timeToBankH <= 6.0)) {
          waterStageLevel = AlertLevel.high;
          flags.add(dH >= 0.30 ? 'mid_rapid_surge' : 'projected_overflow_6h');
          reasonCodes.add('rapid_rise');
          reasonCodes.add('mid_bank_level');
        } else {
          waterStageLevel = AlertLevel.warning;
          flags.add('mid_bank_warning');
          reasonCodes.add('mid_bank_level');
          if (dH > AppConfig.steadyBandMeters) {
            reasonCodes.add('rising_water');
          }
        }
      } else if (levelMsl >= watch) {
        wBase = 0.35 + 0.25 * (levelMsl - watch) / (midM - watch);
        if (timeToBankH != null && timeToBankH <= 6.0) {
          waterStageLevel = AlertLevel.high;
          flags.add('projected_overflow_6h');
          reasonCodes.add('rapid_rise');
          reasonCodes.add('near_watch');
        } else if (dH >= 0.15 || (timeToBankH != null && timeToBankH <= 24.0)) {
          waterStageLevel = AlertLevel.warning;
          flags.add(dH >= 0.15 ? 'watch_rapid_rise' : 'projected_overflow_24h');
          reasonCodes.add('rising_water');
          reasonCodes.add('near_watch');
        } else {
          waterStageLevel = AlertLevel.watch;
          flags.add(dH.abs() <= AppConfig.steadyBandMeters ? 'watch_sideway' : 'watch_level');
          reasonCodes.add('near_watch');
        }
      } else {
        waterStageLevel = AlertLevel.normal;
        wBase = 0.0;
      }

      var riseBonus = 0.0;
      if (levelMsl >= watch) {
        if (dH >= 0.30) {
          riseBonus = 0.10;
          if (!flags.contains('rapid_rise')) flags.add('rapid_rise');
          if (!reasonCodes.contains('rapid_rise')) reasonCodes.add('rapid_rise');
        } else if (dH >= 0.15) {
          riseBonus = 0.05;
          if (!flags.contains('rising_watch')) flags.add('rising_watch');
          if (!reasonCodes.contains('rising_water')) reasonCodes.add('rising_water');
        }
      }
      wVal = (wBase + riseBonus).clamp(0.0, 1.0);
    } else {
      flags.add('no_water_signal');
    }

    // 2. ThaiWater situation_level (1-5 capacity scale; ONLY >=5 = overflow, 4 = fallback when unbanked/unverified)
    var agencyOverflowLevel = AlertLevel.normal;
    if (situationLevel != null && situationLevel >= 5) {
      agencyOverflowLevel = AlertLevel.danger;
      flags.add('thaiwater_overflow_sit5');
      reasonCodes.add('bank_overflow');
      if (crit == null || datumUnverified || stale || levelMsl == null) {
        wVal = 1.0;
      }
    } else if (situationLevel == 4 &&
        (crit == null || datumUnverified || levelMsl == null) &&
        !stale) {
      waterStageLevel = waterStageLevel.maxWith(AlertLevel.watch);
      wVal = math.max(wVal, 0.35);
      flags.add('w_from_situation_high_fallback');
    }

    // 3. R (Multi-Window Observed Rain: 1h / 24h / 72h)
    final rVal = math
        .max(
          math.max(math.max(0.0, rain1hMm) / 60.0, math.max(0.0, rain24hMm) / 150.0),
          math.max(0.0, rain72hMm) / 260.0,
        )
        .clamp(0.0, 1.0);
    if (rVal >= 0.65) reasonCodes.add('heavy_rain');

    // 4. A (Antecedent Wetness API 7-day)
    final aVal = (math.max(0.0, api7dMm) / 180.0).clamp(0.0, 1.0);
    if (aVal >= 0.65) reasonCodes.add('saturated_soil');

    // 5. F (Multi-Window Forecast Rain + GloFAS Ratio)
    final fRain = math.max(
      math.max(math.max(0.0, forecast6hMm) / 50.0, math.max(0.0, forecast24hMm) / 110.0),
      math.max(0.0, forecast72hMm) / 200.0,
    );
    var glofasBonus = 0.0;
    if (glofasPeakRatio != null) {
      if (glofasPeakRatio >= 3.0) {
        glofasBonus = 0.25;
        flags.add('glofas_high_surge');
        reasonCodes.add('river_surge_forecast');
      } else if (glofasPeakRatio >= 2.0) {
        glofasBonus = 0.15;
        flags.add('glofas_elevated');
        reasonCodes.add('river_surge_forecast');
      }
    }
    final fVal = (fRain + glofasBonus).clamp(0.0, 1.0);
    if (fRain >= 0.60) reasonCodes.add('heavy_forecast');

    // 6. D (Bang Lang Dam downstream risk)
    final dVal = damSignal.clamp(0.0, 1.0);
    if (damSpillwayActive) {
      flags.add('dam_spillway_active');
      reasonCodes.add('dam_spillway');
    } else if (dVal >= 0.45) {
      reasonCodes.add('dam_high_flow');
    }

    // 7. C (Verified external signals, default 0)
    final cVal = (math.max(0, communityReports60m) / 5.0).clamp(0.0, 1.0);
    if (cVal >= 0.60) reasonCodes.add('community_reports');

    // 8. Diagnostic Multi-Signal Score (0..100, half-up 1 decimal)
    final raw =
        0.50 * wVal + 0.18 * rVal + 0.08 * aVal + 0.10 * fVal + 0.08 * dVal + 0.06 * cVal;
    final score = _roundHalfUp1(100.0 * raw).clamp(0.0, 100.0);
    final scoreLevel = AlertLevel.fromScore(score);

    // 9. Non-Water Early Warning (Proactive Gate up to Lv 4 — Lv 5 strictly reserved for confirmed overflow)
    var earlyWarningLevel = AlertLevel.normal;
    var urbanPluvialTriggered = false;
    var flashEarlyTriggered = false;
    var damEarlyTriggered = false;

    if (damSpillwayActive) {
      damEarlyTriggered = true;
      if (waterStageLevel.value >= 2 || damInflowDailyMcm >= 90.0) {
        earlyWarningLevel = earlyWarningLevel.maxWith(AlertLevel.high);
        flags.add('dam_critical_compound_lv4');
      } else {
        earlyWarningLevel = earlyWarningLevel.maxWith(AlertLevel.warning);
        flags.add('dam_spillway_floor_lv3');
      }
    } else if (dVal >= 0.45) {
      damEarlyTriggered = true;
      earlyWarningLevel = earlyWarningLevel.maxWith(AlertLevel.watch);
      flags.add('dam_elevated_watch');
    }

    final extremeRain =
        (rain1hMm >= 75.0) || (rain24hMm >= 200.0) || (rain72hMm >= 300.0);

    if (isUrbanBasin) {
      if (extremeRain && api7dMm >= 120.0 && (rain1hMm >= 25.0 || forecast6hMm >= 30.0)) {
        urbanPluvialTriggered = true;
        earlyWarningLevel = earlyWarningLevel.maxWith(AlertLevel.high);
        flags.add('extreme_urban_pluvial_lv4');
        reasonCodes.add('urban_flood_risk');
      } else {
        final urbanRain =
            (rain1hMm >= 45.0) || (rain24hMm >= 140.0) || (rain72hMm >= 240.0);
        final urbanConfirm =
            (api7dMm >= 90.0) || (forecast6hMm >= 30.0) || (rain1hMm >= 55.0);
        if (urbanRain && urbanConfirm) {
          urbanPluvialTriggered = true;
          earlyWarningLevel = earlyWarningLevel.maxWith(AlertLevel.warning);
          flags.add('urban_pluvial_override');
          reasonCodes.add('urban_flood_risk');
        }
      }
    }

    if (isFlashFlood) {
      if (extremeRain && api7dMm >= 120.0 && (rain1hMm >= 30.0 || forecast6hMm >= 25.0)) {
        flashEarlyTriggered = true;
        earlyWarningLevel = earlyWarningLevel.maxWith(AlertLevel.high);
        flags.add('extreme_flash_flood_lv4');
        reasonCodes.add('flash_flood_risk');
      } else if ((rVal >= 0.65 && (api7dMm >= 90.0 || fVal >= 0.50 || cVal >= 0.60)) ||
          rVal >= 0.85) {
        flashEarlyTriggered = true;
        earlyWarningLevel = earlyWarningLevel.maxWith(AlertLevel.warning);
        flags.add('flash_flood_early_warning');
        reasonCodes.add('flash_flood_risk');
      } else if (rVal >= 0.65 || cVal >= 0.60 || (api7dMm >= 126.0 && rVal >= 0.45)) {
        flashEarlyTriggered = true;
        earlyWarningLevel = earlyWarningLevel.maxWith(AlertLevel.watch);
        flags.add('flash_flood_watch');
        reasonCodes.add('flash_flood_risk');
      }
    }

    if (earlyWarningLevel.value > 4) {
      earlyWarningLevel = AlertLevel.high;
    }

    // 10. Final Level & Transparent Alert Basis
    final level = waterStageLevel.maxWith(agencyOverflowLevel).maxWith(earlyWarningLevel);

    final String alertBasis;
    if (agencyOverflowLevel.value >= 5 && waterStageLevel.value < 5) {
      alertBasis = 'agency_overflow';
    } else if (level.value > waterStageLevel.value && level == earlyWarningLevel) {
      alertBasis = 'rain_dam_early_warning';
      flags.add('early_warning_non_water');
    } else if (waterStageLevel.value >= 2) {
      alertBasis = 'water_stage';
    } else {
      alertBasis = 'monitoring';
    }

    // 11. Mechanism & Confidence
    final String floodMechanism;
    if (damSpillwayActive || damEarlyTriggered) {
      floodMechanism = 'dam_release';
    } else if (urbanPluvialTriggered && waterStageLevel.value < 3) {
      floodMechanism = 'urban_pluvial';
    } else if (flashEarlyTriggered && waterStageLevel.value < 3) {
      floodMechanism = 'flash_flood';
    } else if (waterStageLevel.value >= 2 || agencyOverflowLevel.value >= 5) {
      floodMechanism = 'riverine_overflow';
    } else {
      floodMechanism = 'monitoring';
    }

    final String confidence;
    if (stale || (!hasWaterGauge && rainSensorGap)) {
      confidence = 'low';
    } else if (datumUnverified ||
        rainSensorGap ||
        !hasWaterGauge ||
        (crit == null && situationLevel == null)) {
      confidence = 'medium';
    } else {
      confidence = 'high';
    }

    // 12. Push eligibility
    final hasPrimarySignal = waterStageLevel.value >= 2 ||
        agencyOverflowLevel.value >= 5 ||
        damSpillwayActive ||
        dVal >= 0.45 ||
        urbanPluvialTriggered ||
        cVal >= 0.60 ||
        (flashEarlyTriggered &&
            (earlyWarningLevel.value >= 4 ||
                (!hasWaterGauge && rVal >= 0.65 && (api7dMm >= 90.0 || fVal >= 0.50)) ||
                rVal >= 0.85));
    final shouldPush = level.value >= 2 && hasPrimarySignal;

    final uniqueReasons = <String>[];
    for (final rc in reasonCodes) {
      if (!uniqueReasons.contains(rc)) uniqueReasons.add(rc);
    }

    return AssessmentV5(
      score: score,
      scoreLevel: scoreLevel,
      waterStageLevel: waterStageLevel,
      earlyWarningLevel: earlyWarningLevel,
      floorLevel: agencyOverflowLevel,
      flashBonus: flashEarlyTriggered ? 1 : 0,
      level: level,
      alertBasis: alertBasis,
      waterTrend: waterTrend,
      shouldPush: shouldPush,
      hasPrimarySignal: hasPrimarySignal,
      floodMechanism: floodMechanism,
      confidence: confidence,
      w: wVal,
      r: rVal,
      a: aVal,
      f: fVal,
      d: dVal,
      c: cVal,
      dH: dH,
      timeToBankH: timeToBankH,
      leadTimeHours: (damSpillwayActive || dVal >= 0.45) ? leadTimeHours : null,
      reasonCodes: uniqueReasons,
      flags: flags,
    );
  }

  /// ใช้ Hysteresis 3 ชั่วโมง (คงระดับสูงไว้หากคะแนนลดลงยังไม่ครบ 3 ชม. ตามบทวิจัย §5ง)
  AlertLevel applyHysteresis({
    required AlertLevel current,
    StationAlertMemory? memory,
    required DateTime now,
  }) {
    if (memory == null) return current;
    if (current.value >= memory.level.value) return current;
    final elapsed = now.difference(memory.updatedAt);
    if (memory.level.value >= 2 && elapsed < AppConfig.hysteresisWindow) {
      return memory.level;
    }
    return current;
  }

  /// ตรวจ Cooldown 30 นาที (ส่งทันทีหากระดับสูงขึ้น, นอกนั้นรอครบ 30 นาที)
  bool shouldNotifyWithCooldown({
    required AlertLevel effective,
    StationAlertMemory? memory,
    required DateTime now,
  }) {
    if (memory == null) return true;
    if (effective.value > memory.level.value) return true;
    if (effective.value < memory.level.value) return false;
    return now.difference(memory.lastNotifiedAt) >= AppConfig.alertCooldownWindow;
  }

  /// ประเมินระดับสุทธิของสถานีตามเกณฑ์ระดับน้ำ 5 ขั้น (`formula_version = 5`)
  RiskLevel effectiveRisk(Station station, AlertSettings settings) =>
      station.riskLevel;

  /// ประเมินทุกสถานีและสร้างรายการแจ้งเตือนที่ผ่านเกณฑ์ + ไม่ซ้ำใน cooldown
  List<AlertItem> evaluate({
    required List<Station> stations,
    AlertSettings settings = const AlertSettings(),
    List<AlertItem> previous = const <AlertItem>[],
    Map<String, StationAlertMemory>? memoryByStation,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final seenIds = {for (final a in previous) a.id};

    final lastByStation = <String, AlertItem>{};
    for (final a in previous) {
      final existing = lastByStation[a.stationCode];
      if (existing == null || a.createdAt.isAfter(existing.createdAt)) {
        lastByStation[a.stationCode] = a;
      }
    }

    final result = <AlertItem>[];
    for (final station in stations) {
      if (!_matchesLocationFilter(station, settings)) continue;

      final assessment = assessV5(
        levelMsl: station.displayLevel,
        previousMsl: station.waterLevelMslPrev,
        bankM: station.hasBank ? station.bankLevel : null,
        watchM: AppConfig.stationWatchMsl[station.code],
        criticalM: AppConfig.stationCriticalMsl[station.code],
        situationLevel: station.situationLevel,
        datumUnverified: station.isDatumUnverified,
        isFlashFlood: AppConfig.flashFloodAmphoes.contains(station.amphoeTh ?? ''),
        isUrbanBasin: AppConfig.urbanBasinAmphoes.contains(station.amphoeTh ?? ''),
        leadTimeHours: AppConfig.bangLangDownstreamLeadTime[station.amphoeTh ?? ''],
      );

      final effectiveAlertLevel = applyHysteresis(
        current: assessment.level,
        memory: memoryByStation?[station.code],
        now: timestamp,
      );

      final baseRisk = effectiveRisk(station, settings);
      final heldByHysteresis = effectiveAlertLevel.value > assessment.level.value;
      final v5Triggered = (assessment.shouldPush || heldByHysteresis) &&
          effectiveAlertLevel.value >= settings.warningLevel;
      final RiskLevel risk;
      if (v5Triggered && effectiveAlertLevel.risk.severity >= baseRisk.severity) {
        risk = effectiveAlertLevel.risk;
      } else {
        risk = baseRisk;
      }
      if (risk.severity < settings.warningLevel) continue;

      final prevItem = lastByStation[station.code];
      if (prevItem != null) {
        final withinCooldown =
            timestamp.difference(prevItem.createdAt).abs() < AppConfig.alertCooldownWindow;
        if (withinCooldown && risk.severity <= prevItem.level.severity) {
          continue;
        }
      }

      final id = AlertItem.buildId(station.code, risk, timestamp);
      if (seenIds.contains(id)) continue;

      result.add(
        AlertItem(
          id: id,
          stationCode: station.code,
          stationName: station.nameTh,
          level: risk,
          title: _buildTitle(station, risk),
          message: _buildMessage(station, risk, assessment.leadTimeHours),
          createdAt: timestamp,
          waterLevelMsl: station.displayLevel,
          amphoeTh: station.amphoeTh,
          score: assessment.score,
          alertLevel: effectiveAlertLevel,
          waterSignal: assessment.hasPrimarySignal,
          pushed: assessment.shouldPush,
          leadTimeHours: assessment.leadTimeHours,
        ),
      );
      seenIds.add(id);
    }

    result.sort((a, b) {
      final byLevel = b.level.severity.compareTo(a.level.severity);
      if (byLevel != 0) return byLevel;
      return b.createdAt.compareTo(a.createdAt);
    });
    return result;
  }

  bool _matchesLocationFilter(Station station, AlertSettings settings) {
    if (settings.selectedAmphoeTh != null &&
        settings.selectedAmphoeTh!.isNotEmpty &&
        station.amphoeTh != settings.selectedAmphoeTh) {
      return false;
    }
    if (settings.selectedTumbonTh != null &&
        settings.selectedTumbonTh!.isNotEmpty &&
        station.tumbonTh != settings.selectedTumbonTh) {
      return false;
    }
    return true;
  }

  String _buildTitle(Station station, RiskLevel level) {
    final prefix = switch (level) {
      RiskLevel.danger => 'ประกาศภาวะอันตราย',
      RiskLevel.high => 'ประกาศเตือนภัยระดับสูง',
      RiskLevel.warning => 'ประกาศเตือนภัย',
      RiskLevel.watch => 'ประกาศเฝ้าระวัง',
      _ => 'รายงานสถานการณ์น้ำ',
    };
    return '$prefix: ${station.nameTh}';
  }

  String _buildMessage(Station station, RiskLevel level, String? leadTimeHours) {
    final buf = StringBuffer();
    final wl = station.displayLevel;
    if (wl != null) {
      buf.write('ระดับน้ำ ${wl.toStringAsFixed(2)} ม.รทก.');
    } else {
      buf.write(level.messageTh);
    }
    final rem = station.remainingToBank;
    if (rem != null) {
      buf.write(
        rem >= 0
            ? ' (ต่ำกว่าตลิ่ง ${rem.toStringAsFixed(2)} ม.)'
            : ' (ล้นตลิ่ง ${(-rem).toStringAsFixed(2)} ม.)',
      );
    }
    if (leadTimeHours != null && leadTimeHours.isNotEmpty) {
      buf.write(' · คาดว่ามวลน้ำจะเดินทางถึงภายใน $leadTimeHours');
    }
    return buf.toString();
  }

  /// คำแนะนำการปฏิบัติตนภาษาราชการที่กระชับเข้าใจง่ายสำหรับหน้าจอรายละเอียดสถานี
  String guidanceTh(RiskLevel level, String amphoe) {
    final lead = AppConfig.bangLangDownstreamLeadTime[amphoe];
    final leadSuffix = lead != null
        ? ' (พื้นที่ท้ายเขื่อนบางลาง ระยะเวลามวลน้ำเดินทาง $lead)'
        : '';
    switch (level) {
      case RiskLevel.danger:
        return 'เกิดอุทกภัยในพื้นที่แล้ว โปรดอพยพทันทีไปยังศูนย์พักพิงชั่วคราวที่ปลอดภัย หากต้องการความช่วยเหลือเร่งด่วน โทร. 1784, 073-203559 หรือ 1669$leadSuffix';
      case RiskLevel.high:
        return 'ระดับน้ำเข้าใกล้ระดับวิกฤต เตรียมพร้อมอพยพทันที ตัดกระแสไฟฟ้าชั้นล่างหากน้ำเริ่มเข้าพื้นที่ และติดตามประกาศ ปภ.ยะลา (073-203559)$leadSuffix';
      case RiskLevel.warning:
        return 'มีแนวโน้มเกิดอุทกภัยภายใน 24 ชั่วโมง ขนย้ายทรัพย์สินขึ้นที่สูง ตรวจสอบเส้นทางปลอดภัย และเตรียมแผนอพยพกลุ่มเปราะบาง$leadSuffix';
      case RiskLevel.watch:
        return 'ระดับน้ำเริ่มสูงขึ้นเข้าใกล้เกณฑ์เฝ้าระวัง โปรดติดตามประกาศอย่างใกล้ชิด เตรียมสิ่งของจำเป็นและสำรองพลังงานอุปกรณ์สื่อสาร$leadSuffix';
      case RiskLevel.normal:
        return 'ระดับน้ำต่ำกว่าเกณฑ์เฝ้าระวัง สถานการณ์อยู่ในภาวะปกติ โปรดติดตามพยากรณ์อากาศตามปกติ$leadSuffix';
      case RiskLevel.unknown:
        return 'ยังไม่มีเกณฑ์ระดับน้ำอ้างอิงของสถานีนี้ โปรดตรวจสอบควบคู่กับปริมาณฝนสะสมและประกาศ ปภ.ยะลา (073-203559)';
    }
  }
}
