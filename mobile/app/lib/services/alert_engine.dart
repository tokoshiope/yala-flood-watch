import 'dart:math' as math;

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/rain_forecast.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';

/// ผลลัพธ์การคำนวณ Alert Score formula_version = 4 (100% Parity กับ backend/pipeline.py compute_alert_v4)
class AssessmentV4 {
  const AssessmentV4({
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
  final String? leadTimeHours;
  final List<String> reasonCodes;
  final List<String> flags;
}

/// ผลลัพธ์การคำนวณ Alert Score formula_version = 3 (คงไว้เพื่อชุดทดสอบย้อนหลัง)
class AssessmentV3 {
  const AssessmentV3({
    required this.score,
    required this.scoreLevel,
    required this.floorLevel,
    required this.flashBonus,
    required this.level,
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
    this.leadTimeHours,
    this.reasonCodes = const <String>[],
    this.flags = const <String>[],
  });

  final double score;
  final AlertLevel scoreLevel;
  final AlertLevel floorLevel;
  final int flashBonus;
  final AlertLevel level;
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
  final String? leadTimeHours;
  final List<String> reasonCodes;
  final List<String> flags;
}

/// ผลลัพธ์การคำนวณ Alert Score formula_version = 2 (คงไว้เพื่อความเข้ากันย้อนหลัง)
class AssessmentV2 {
  const AssessmentV2({
    required this.score,
    required this.scoreLevel,
    required this.floorLevel,
    required this.flashBonus,
    required this.level,
    required this.shouldPush,
    required this.hasPrimarySignal,
    required this.w,
    required this.r,
    required this.f,
    required this.d,
    required this.c,
    required this.dH,
    this.leadTimeHours,
    this.flags = const <String>[],
  });

  final double score;
  final AlertLevel scoreLevel;
  final AlertLevel floorLevel;
  final int flashBonus;
  final AlertLevel level;
  final bool shouldPush;
  final bool hasPrimarySignal;
  final double w;
  final double r;
  final double f;
  final double d;
  final double c;
  final double dH;
  final String? leadTimeHours;
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

/// ตรรกะหลักในการประเมินความเสี่ยงและสร้างแจ้งเตือนภัยน้ำท่วมล่วงหน้า
///
/// รองรับทั้ง:
/// 1) [assessV4] — สูตร `formula_version = 4` (เกณฑ์ระดับน้ำ 5 ขั้น + แนวโน้ม side way/สูงขึ้น + เตือนฝน/เขื่อนสูงสุด Lv 3) ตรงกับ Python 100%
/// 2) [effectiveRisk] และ [evaluate] — แปลงระดับ + กรองอำเภอ + Hysteresis 3 ชม. + Cooldown 30 นาที
class AlertEngine {
  const AlertEngine();

  /// ปัดเศษแบบ half-up ทศนิยม 1 ตำแหน่งให้ตรงกับ Python 100% (กัน NaN/Infinity แบบ Fail-Closed)
  static double _roundHalfUp1(double value) =>
      value.isFinite ? (value * 10.0 + 0.5 + 1e-9).floor() / 10.0 : 0.0;

  /// สูตรแจ้งเตือนหลัก `formula_version = 4` (ตรงกับ backend/pipeline.py compute_alert_v4 100%)
  AssessmentV4 assessV4({
    double? levelMsl,
    double? previousMsl,
    double? bankM,
    double? watchM,
    double? criticalM,
    int? situationLevel,
    bool stale = false,
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
    int communityReports60m = 0,
    bool isFlashFlood = false,
    bool isUrbanBasin = false,
    bool hasWaterGauge = true,
    bool rainSensorGap = false,
    double? hNormal30d,
    String? leadTimeHours,
  }) {
    final flags = <String>[];
    final reasonCodes = <String>[];

    if (rainSensorGap) {
      flags.add('rain_sensor_gap');
    }

    // 1. Physical Water-Stage Thresholds (watch, mid, high, crit) & Trend (dH)
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
    final watch = crit != null
        ? ((watchM != null && watchM > 0 && watchM < crit) ? watchM : (crit - 1.5))
        : null;
    final midM = (crit != null && watch != null) ? (watch + crit) / 2.0 : null;
    final highM = (crit != null && midM != null) ? (midM + crit) / 2.0 : null;

    var waterStageLevel = AlertLevel.normal;
    var wVal = 0.0;
    if (stale) {
      flags.add('water_stale');
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
        if (dH >= 0.30) {
          waterStageLevel = AlertLevel.high;
          flags.add('mid_rapid_surge');
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
        if (dH >= 0.15) {
          waterStageLevel = AlertLevel.warning;
          flags.add('watch_rapid_rise');
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

    // 2. ThaiWater situation_level (1-5 capacity scale; ONLY >=5 = overflow, 4 = fallback when unbanked)
    var agencyOverflowLevel = AlertLevel.normal;
    if (situationLevel != null && situationLevel >= 5) {
      agencyOverflowLevel = AlertLevel.danger;
      flags.add('thaiwater_overflow_sit5');
      reasonCodes.add('bank_overflow');
      if (crit == null || stale || levelMsl == null) {
        wVal = 1.0;
      }
    } else if (situationLevel == 4 && (crit == null || levelMsl == null) && !stale) {
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

    // 7. C (Verified community reports, trust >= 3)
    final cVal = (math.max(0, communityReports60m) / 5.0).clamp(0.0, 1.0);
    if (cVal >= 0.60) reasonCodes.add('community_reports');

    // 8. Diagnostic Multi-Signal Score (0..100, half-up 1 decimal)
    final raw =
        0.50 * wVal + 0.18 * rVal + 0.08 * aVal + 0.10 * fVal + 0.08 * dVal + 0.06 * cVal;
    final score = _roundHalfUp1(100.0 * raw).clamp(0.0, 100.0);
    final scoreLevel = AlertLevel.fromScore(score);

    // 9. Option 1 Non-Water Early Warning (Urban Pluvial / Flash Flood / Bang Lang Dam — CAPPED at Lv 3)
    var earlyWarningLevel = AlertLevel.normal;
    var urbanPluvialTriggered = false;
    var flashEarlyTriggered = false;
    var damEarlyTriggered = false;

    if (damSpillwayActive) {
      earlyWarningLevel = earlyWarningLevel.maxWith(AlertLevel.warning);
      damEarlyTriggered = true;
      flags.add('dam_spillway_floor_lv3');
    } else if (dVal >= 0.75) {
      earlyWarningLevel = earlyWarningLevel.maxWith(AlertLevel.watch);
      damEarlyTriggered = true;
      flags.add('dam_high_flow_watch');
    }

    if (isUrbanBasin) {
      final urbanRain = (rain1hMm >= 45.0) || (rain24hMm >= 140.0) || (rain72hMm >= 240.0);
      final urbanConfirm = (aVal >= 0.50) || (forecast6hMm >= 30.0) || (rain1hMm >= 55.0);
      if (urbanRain && urbanConfirm) {
        urbanPluvialTriggered = true;
        earlyWarningLevel = earlyWarningLevel.maxWith(AlertLevel.warning);
        flags.add('urban_pluvial_override');
        reasonCodes.add('urban_flood_risk');
      }
    }

    if (isFlashFlood) {
      if ((rVal >= 0.65 && (aVal >= 0.50 || fVal >= 0.50 || cVal >= 0.60)) || rVal >= 0.85) {
        flashEarlyTriggered = true;
        earlyWarningLevel = earlyWarningLevel.maxWith(AlertLevel.warning);
        flags.add('flash_flood_early_warning');
        reasonCodes.add('flash_flood_risk');
      } else if (rVal >= 0.65 || cVal >= 0.60 || (aVal >= 0.70 && rVal >= 0.45)) {
        flashEarlyTriggered = true;
        earlyWarningLevel = earlyWarningLevel.maxWith(AlertLevel.watch);
        flags.add('flash_flood_watch');
        reasonCodes.add('flash_flood_risk');
      }
    }

    if (earlyWarningLevel.value > 3) {
      earlyWarningLevel = AlertLevel.warning;
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
    } else if (rainSensorGap || !hasWaterGauge || (crit == null && situationLevel == null)) {
      confidence = 'medium';
    } else {
      confidence = 'high';
    }

    // 12. Push eligibility
    final hasPrimarySignal = waterStageLevel.value >= 2 ||
        agencyOverflowLevel.value >= 5 ||
        damSpillwayActive ||
        dVal >= 0.75 ||
        urbanPluvialTriggered ||
        cVal >= 0.60 ||
        (flashEarlyTriggered &&
            ((!hasWaterGauge && rVal >= 0.65 && (aVal >= 0.50 || fVal >= 0.50)) ||
                rVal >= 0.85));
    final shouldPush = level.value >= 2 && hasPrimarySignal;

    final uniqueReasons = <String>[];
    for (final rc in reasonCodes) {
      if (!uniqueReasons.contains(rc)) uniqueReasons.add(rc);
    }

    return AssessmentV4(
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
      leadTimeHours: (damSpillwayActive || dVal >= 0.45) ? leadTimeHours : null,
      reasonCodes: uniqueReasons,
      flags: flags,
    );
  }

  /// สูตรแจ้งเตือนล่วงหน้า `formula_version = 3` (ตรงกับ backend/pipeline.py compute_alert_v3 100%)
  AssessmentV3 assessV3({
    double? levelMsl,
    double? previousMsl,
    double? bankM,
    double? watchM,
    double? criticalM,
    int? situationLevel,
    bool stale = false,
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
    int communityReports60m = 0,
    bool isFlashFlood = false,
    bool isUrbanBasin = false,
    bool hasWaterGauge = true,
    bool rainSensorGap = false,
    double? hNormal30d,
    String? leadTimeHours,
  }) {
    final flags = <String>[];
    final reasonCodes = <String>[];

    if (rainSensorGap) {
      flags.add('rain_sensor_gap');
    }

    // 1. W (Impact-Based River Stage vs watch_m/critical_m + dH/dt)
    var dH = 0.0;
    if (levelMsl != null && previousMsl != null && !stale) {
      dH = ((levelMsl - previousMsl) * 10000).round() / 10000.0;
    }

    final crit = (criticalM != null && criticalM > 0)
        ? criticalM
        : ((bankM != null && bankM > 0) ? bankM : null);
    final watch = crit != null
        ? ((watchM != null && watchM > 0 && watchM < crit) ? watchM : (crit - 1.5))
        : null;

    var wVal = 0.0;
    if (stale) {
      flags.add('water_stale');
    } else if (crit != null && watch != null && levelMsl != null) {
      double baseLow;
      if (hNormal30d != null && hNormal30d < watch) {
        baseLow = hNormal30d;
      } else {
        baseLow = watch - 1.5;
        flags.add('h_normal_bootstrap');
      }
      double wBase;
      if (levelMsl <= baseLow) {
        wBase = 0.0;
      } else if (levelMsl < watch) {
        wBase = 0.55 * (levelMsl - baseLow) / (watch - baseLow);
      } else if (levelMsl < crit) {
        wBase = 0.55 + 0.45 * (levelMsl - watch) / (crit - watch);
      } else {
        wBase = 1.0;
      }

      var riseBonus = 0.0;
      if (dH >= 0.30) {
        riseBonus = 0.15;
        flags.add('rapid_rise');
        reasonCodes.add('rapid_rise');
      } else if (dH >= 0.15) {
        riseBonus = 0.08;
        flags.add('rising_watch');
        reasonCodes.add('rising_water');
      }
      wVal = (wBase + riseBonus).clamp(0.0, 1.0);
    } else if (situationLevel != null && situationLevel >= 1 && situationLevel <= 4) {
      wVal = (situationLevel / 4.0).clamp(0.0, 1.0);
      flags.add('w_from_situation_fallback');
    } else {
      flags.add('no_water_signal');
    }

    // 2. R (Multi-Window Observed Rain: 1h / 24h / 72h)
    final rVal = math
        .max(
          math.max(math.max(0.0, rain1hMm) / 60.0, math.max(0.0, rain24hMm) / 150.0),
          math.max(0.0, rain72hMm) / 260.0,
        )
        .clamp(0.0, 1.0);
    if (rVal >= 0.65) reasonCodes.add('heavy_rain');

    // 3. A (Antecedent Wetness API 7-day)
    final aVal = (math.max(0.0, api7dMm) / 180.0).clamp(0.0, 1.0);
    if (aVal >= 0.65) reasonCodes.add('saturated_soil');

    // 4. F (Multi-Window Forecast Rain + GloFAS Ratio)
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

    // 5. D (Bang Lang Dam downstream risk)
    final dVal = damSignal.clamp(0.0, 1.0);
    if (damSpillwayActive) {
      flags.add('dam_spillway_active');
      reasonCodes.add('dam_spillway');
    } else if (dVal >= 0.45) {
      reasonCodes.add('dam_high_flow');
    }

    // 6. C (Verified community reports)
    final cVal = (math.max(0, communityReports60m) / 5.0).clamp(0.0, 1.0);
    if (cVal >= 0.60) reasonCodes.add('community_reports');

    // 7. Weighted Multi-Signal Risk Score
    final raw =
        0.38 * wVal + 0.22 * rVal + 0.10 * aVal + 0.12 * fVal + 0.10 * dVal + 0.08 * cVal;
    final score = _roundHalfUp1(100.0 * raw).clamp(0.0, 100.0);

    // 8. Base level + Agency Floor (legacy v3)
    final scoreLevel = AlertLevel.fromScore(score);
    final floorLevel = situationLevel != null
        ? AlertLevel.fromValue(situationLevel.clamp(1, 4))
        : AlertLevel.normal;
    if (situationLevel != null && situationLevel >= 3 && scoreLevel.value <= 2) {
      flags.add('situation_score_mismatch');
    }
    var level = scoreLevel.maxWith(floorLevel);

    // 9. Physical Bank-Overflow Override
    var bankOverride = false;
    if (!stale && crit != null && watch != null && levelMsl != null) {
      if (levelMsl >= crit + 0.50) {
        if (level.value < 5) level = AlertLevel.danger;
        bankOverride = true;
        flags.add('bank_overflow_severe');
        reasonCodes.add('bank_overflow');
      } else if (levelMsl >= crit) {
        if (level.value < 4) level = AlertLevel.high;
        bankOverride = true;
        flags.add('bank_overflow');
        reasonCodes.add('bank_overflow');
      } else if (levelMsl >= watch && dH >= 0.15) {
        if (level.value < 3) level = AlertLevel.warning;
        bankOverride = true;
        flags.add('watch_rapid_rise');
        reasonCodes.add('near_bank');
      } else if (levelMsl >= watch) {
        reasonCodes.add('near_bank');
      }
    }

    // 10. Flash flood override
    var flashBonus = 0;
    if (isFlashFlood) {
      if (rVal >= 0.65) flashBonus += 1;
      if (cVal >= 0.60) flashBonus += 1;
      if (dH >= 0.30) flashBonus += 1;
      if (aVal >= 0.70 && rVal >= 0.45) flashBonus += 1;
      flashBonus = math.min(flashBonus, 2);
      if (flashBonus > 0) {
        level = level.plusLevels(flashBonus);
        flags.add('flash_override_+$flashBonus');
        reasonCodes.add('flash_flood_risk');
      }
    }

    // 11. Urban Pluvial Override
    var urbanPluvialTriggered = false;
    if (isUrbanBasin) {
      final urbanRain = (rain1hMm >= 45.0) || (rain24hMm >= 140.0) || (rain72hMm >= 240.0);
      final urbanConfirm = (aVal >= 0.50) || (forecast6hMm >= 30.0) || (rain1hMm >= 55.0);
      if (urbanRain && urbanConfirm) {
        urbanPluvialTriggered = true;
        if (level.value < 3) level = AlertLevel.warning;
        flags.add('urban_pluvial_override');
        reasonCodes.add('urban_flood_risk');
      }
    }

    // 12. Dam Spillway Override
    if (damSpillwayActive && level.value < 3) {
      level = AlertLevel.warning;
      flags.add('dam_spillway_floor_lv3');
    }

    // 13. Mechanism & Confidence
    final String floodMechanism;
    if (damSpillwayActive || dVal >= 0.75) {
      floodMechanism = 'dam_release';
    } else if (urbanPluvialTriggered) {
      floodMechanism = 'urban_pluvial';
    } else if (isFlashFlood && (flashBonus > 0 || rVal >= 0.55)) {
      floodMechanism = 'flash_flood';
    } else if (bankOverride || wVal >= 0.55) {
      floodMechanism = 'riverine_overflow';
    } else {
      floodMechanism = 'monitoring';
    }

    final String confidence;
    if (stale || (!hasWaterGauge && rainSensorGap)) {
      confidence = 'low';
    } else if (rainSensorGap || !hasWaterGauge || (crit == null && situationLevel == null)) {
      confidence = 'medium';
    } else {
      confidence = 'high';
    }

    // 14. Push eligibility
    final hasPrimarySignal = wVal > 0.0 ||
        bankOverride ||
        (situationLevel != null && situationLevel >= 2) ||
        dVal >= 0.45 ||
        cVal >= 0.60 ||
        urbanPluvialTriggered ||
        (isFlashFlood && !hasWaterGauge && rVal >= 0.70 && (aVal >= 0.50 || fVal >= 0.50));
    final shouldPush = level.value >= 2 && hasPrimarySignal;

    final uniqueReasons = <String>[];
    for (final rc in reasonCodes) {
      if (!uniqueReasons.contains(rc)) uniqueReasons.add(rc);
    }

    return AssessmentV3(
      score: score,
      scoreLevel: scoreLevel,
      floorLevel: floorLevel,
      flashBonus: flashBonus,
      level: level,
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
      leadTimeHours: (damSpillwayActive || dVal >= 0.45) ? leadTimeHours : null,
      reasonCodes: uniqueReasons,
      flags: flags,
    );
  }

  /// สูตรแจ้งเตือนล่วงหน้า `formula_version = 2` (คงไว้เพื่อชุดทดสอบย้อนหลัง)
  AssessmentV2 assessV2({
    double? levelMsl,
    double? previousMsl,
    double? bankM,
    int? situationLevel,
    bool stale = false,
    double rain1hMm = 0.0,
    double rain24hMm = 0.0,
    double forecast24hMm = 0.0,
    double damSignal = 0.0,
    bool damSpillwayActive = false,
    int communityReports60m = 0,
    bool isFlashFlood = false,
    bool hasWaterGauge = true,
    double? hNormal30d,
    String? leadTimeHours,
  }) {
    final flags = <String>[];

    // 1. W (ระดับน้ำ + โบนัสอัตราการขึ้น dH/dt)
    var dH = 0.0;
    if (levelMsl != null && previousMsl != null && !stale) {
      dH = ((levelMsl - previousMsl) * 10000).round() / 10000.0;
    }

    var wVal = 0.0;
    if (stale) {
      flags.add('water_stale');
    } else if (bankM != null && bankM > 0 && levelMsl != null) {
      final hNormal = hNormal30d ?? (bankM - 2.0);
      if (hNormal30d == null) {
        flags.add('h_normal_bootstrap');
      }
      final span = bankM - hNormal;
      final wBase = span > 0 ? ((levelMsl - hNormal) / span).clamp(0.0, 1.0) : 0.0;
      var riseBonus = 0.0;
      if (dH >= 0.30) {
        riseBonus = 0.15;
        flags.add('rapid_rise');
      } else if (dH >= 0.15) {
        riseBonus = 0.08;
        flags.add('rising_watch');
      }
      wVal = (wBase + riseBonus).clamp(0.0, 1.0);
    } else if (situationLevel != null && situationLevel >= 1 && situationLevel <= 4) {
      wVal = (situationLevel / 4.0).clamp(0.0, 1.0);
      flags.add('w_from_situation_fallback');
    } else {
      flags.add('no_water_signal');
    }

    // 2. R (ฝนจริงจาก 87 สถานี ThaiWater)
    final rVal = math
        .max(math.max(0.0, rain1hMm) / 60.0, math.max(0.0, rain24hMm) / 150.0)
        .clamp(0.0, 1.0);

    // 3. F (พยากรณ์ฝน 24 ชม. Open-Meteo)
    final fVal = (math.max(0.0, forecast24hMm) / 120.0).clamp(0.0, 1.0);

    // 4. D (เขื่อนบางลางท้ายน้ำ)
    final dVal = damSignal.clamp(0.0, 1.0);
    if (damSpillwayActive) {
      flags.add('dam_spillway_active');
    }

    // 5. C (รายงานชุมชน trust >= 3)
    final cVal = (math.max(0, communityReports60m) / 5.0).clamp(0.0, 1.0);

    // 6. Score รวม (0..100, half-up 1 decimal)
    final raw = 0.45 * wVal + 0.22 * rVal + 0.13 * fVal + 0.10 * dVal + 0.10 * cVal;
    final score = _roundHalfUp1(100.0 * raw).clamp(0.0, 100.0);

    // 7. ระดับจากคะแนน (1..5)
    final scoreLevel = AlertLevel.fromScore(score);

    // 8. Agency Floor (legacy v2: ห้ามลดระดับต่ำกว่า situation_level)
    final floorLevel = situationLevel != null
        ? AlertLevel.fromValue(situationLevel.clamp(1, 4))
        : AlertLevel.normal;
    if (situationLevel != null && situationLevel >= 3 && scoreLevel.value <= 2) {
      flags.add('situation_score_mismatch');
    }
    var level = scoreLevel.maxWith(floorLevel);

    // 9. Flash flood override
    var flashBonus = 0;
    if (isFlashFlood) {
      if (rVal >= 0.70) flashBonus += 1;
      if (cVal >= 0.60) flashBonus += 1;
      if (dH >= 0.30) flashBonus += 1;
      flashBonus = math.min(flashBonus, 2);
      if (flashBonus > 0) {
        level = level.plusLevels(flashBonus);
        flags.add('flash_override_+$flashBonus');
      }
    }

    // 10. Dam Spillway Early Warning Override (ขั้นต่ำระดับ 3 ล่วงหน้า 2–12 ชม.)
    if (damSpillwayActive && level.value < 3) {
      level = AlertLevel.warning;
      flags.add('dam_spillway_floor_lv3');
    }

    // 11. กฎกัน False Alarm ("ฝนอย่างเดียวไม่ Push")
    final hasPrimarySignal = wVal > 0.0 ||
        (situationLevel != null && situationLevel >= 2) ||
        dVal >= 0.45 ||
        cVal >= 0.60 ||
        (isFlashFlood && !hasWaterGauge && rVal >= 0.80 && fVal >= 0.50);
    final shouldPush = level.value >= 2 && hasPrimarySignal;

    return AssessmentV2(
      score: score,
      scoreLevel: scoreLevel,
      floorLevel: floorLevel,
      flashBonus: flashBonus,
      level: level,
      shouldPush: shouldPush,
      hasPrimarySignal: hasPrimarySignal,
      w: wVal,
      r: rVal,
      f: fVal,
      d: dVal,
      c: cVal,
      dH: dH,
      leadTimeHours: (damSpillwayActive || dVal >= 0.45) ? leadTimeHours : null,
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

  /// ประเมินระดับสุทธิของสถานีตามเกณฑ์ระดับน้ำ 5 ขั้น (`formula_version = 4`) + ฝน (Option 1 สูงสุดระดับ 3)
  RiskLevel effectiveRisk(
    Station station,
    AlertSettings settings, {
    RainForecast? rain,
  }) {
    var base = station.riskLevel;

    if (settings.rainScoreEnabled && rain != null && rain.hasData) {
      final hasWaterEvidence = base.severity >= RiskLevel.watch.severity ||
          (station.hasBank &&
              station.displayLevel != null &&
              station.watchLevel != null &&
              station.displayLevel! >= station.watchLevel!);
      // Option 1: non-water rain escalation is strictly capped at RiskLevel.warning (Lv 3)
      if (hasWaterEvidence &&
          rain.score >= AppConfig.rainScoreWarn &&
          base.severity < RiskLevel.warning.severity) {
        base = RiskLevel.warning;
      }
    }
    return base;
  }

  /// ประเมินทุกสถานีและสร้างรายการแจ้งเตือนที่ผ่านเกณฑ์ + ไม่ซ้ำใน cooldown
  List<AlertItem> evaluate({
    required List<Station> stations,
    AlertSettings settings = const AlertSettings(),
    RainForecast? rain,
    List<AlertItem> previous = const <AlertItem>[],
    Map<String, StationAlertMemory>? memoryByStation,
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final seenIds = {for (final a in previous) a.id};

    // สร้างประวัติล่าสุดรายสถานีเพื่อตรวจ Cooldown 30 นาที
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

      final assessment = assessV4(
        levelMsl: station.displayLevel,
        previousMsl: station.waterLevelMslPrev,
        bankM: station.hasBank ? station.bankLevel : null,
        watchM: AppConfig.stationWatchMsl[station.code],
        criticalM: AppConfig.stationCriticalMsl[station.code],
        situationLevel: station.situationLevel,
        rain1hMm: (settings.rainScoreEnabled && rain != null && rain.hasData)
            ? rain.score * 0.6
            : 0.0,
        isFlashFlood: AppConfig.flashFloodAmphoes.contains(station.amphoeTh ?? ''),
        isUrbanBasin: AppConfig.urbanBasinAmphoes.contains(station.amphoeTh ?? ''),
        leadTimeHours: AppConfig.bangLangDownstreamLeadTime[station.amphoeTh ?? ''],
      );

      final effectiveAlertLevel = applyHysteresis(
        current: assessment.level,
        memory: memoryByStation?[station.code],
        now: timestamp,
      );

      final baseRisk = effectiveRisk(station, settings, rain: rain);
      final heldByHysteresis = effectiveAlertLevel.value > assessment.level.value;
      final v4Triggered = (assessment.shouldPush || heldByHysteresis) &&
          effectiveAlertLevel.value >= settings.warningLevel;
      final RiskLevel risk;
      if (v4Triggered && effectiveAlertLevel.risk.severity >= baseRisk.severity) {
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
          rainScore: (settings.rainScoreEnabled && rain != null && rain.hasData)
              ? rain.score
              : null,
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
      RiskLevel.danger => 'อันตราย',
      RiskLevel.high => 'เตือนภัยสูง',
      RiskLevel.warning => 'เตือนภัย',
      RiskLevel.watch => 'เฝ้าระวัง',
      _ => 'สถานะน้ำ',
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
            ? ' (เหลือ ${rem.toStringAsFixed(2)} ม. ถึงตลิ่ง)'
            : ' (ล้นตลิ่ง ${(-rem).toStringAsFixed(2)} ม.)',
      );
    }
    if (leadTimeHours != null && leadTimeHours.isNotEmpty) {
      buf.write(' · คาดน้ำเดินทางถึงใน $leadTimeHours');
    }
    return buf.toString();
  }

  /// คำแนะนำการปฏิบัติตัวภาษาไทยสำหรับหน้าจอรายละเอียดสถานี
  String guidanceTh(RiskLevel level, String amphoe) {
    final lead = AppConfig.bangLangDownstreamLeadTime[amphoe];
    final leadSuffix = lead != null ? ' (พื้นที่ท้ายเขื่อนบางลาง ระยะเวลาน้ำเดินทาง $lead)' : '';
    switch (level) {
      case RiskLevel.danger:
        return 'ระดับน้ำเลยเส้นตลิ่ง อพยพทันทีไปยังศูนย์พักพิงปลอดภัย หากต้องการความช่วยเหลือโทร 1784 (ปภ.), 073-203559 (ปภ.ยะลา) หรือ 1669$leadSuffix';
      case RiskLevel.high:
        return 'ระดับน้ำสูงกว่าเส้นกึ่งกลางเกือบถึงเส้นตลิ่ง พร้อมอพยพทันที ติดตามประกาศ ปภ.ยะลา (073-203559) และตัดไฟชั้นล่างหากน้ำเข้า$leadSuffix';
      case RiskLevel.warning:
        return 'ระดับน้ำมีแนวโน้มสูงขึ้นถึงเส้นกึ่งกลาง ยกของมีค่าขึ้นที่สูง เตรียมถุงยังชีพและแผนอพยพ$leadSuffix';
      case RiskLevel.watch:
        return 'ระดับน้ำแตะเส้นเฝ้าระวังและทรงตัว (side way) ติดตามค่าระดับน้ำและฝนสะสมเป็นระยะ$leadSuffix';
      case RiskLevel.normal:
        return 'ระดับน้ำต่ำกว่าเส้นเฝ้าระวัง (ปกติ) ยังควรติดตามพยากรณ์อากาศในช่วงฤดูมรสุม$leadSuffix';
      case RiskLevel.unknown:
        return 'ยังไม่มีเกณฑ์ระดับน้ำของสถานีนี้ โปรดตรวจสอบควบคู่กับฝนสะสมและประกาศ ปภ.ยะลา (073-203559)';
    }
  }
}
