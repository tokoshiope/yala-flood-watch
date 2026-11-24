import 'dart:math' as math;

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/rain_forecast.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';

/// ผลลัพธ์การคำนวณ Alert Score formula_version = 2 (100% Parity กับ backend/pipeline.py)
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

/// สถานะอ้างอิงสำหรับ Hysteresis (2 ชม.) และ Cooldown (30 นาที)
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
/// 1) [assessV2] — สูตร `formula_version = 2` (W+dH/dt, R, F, D เขื่อนบางลาง, C) ตรงกับ Python 100%
/// 2) [effectiveRisk] และ [evaluate] — แปลงระดับ + กรองอำเภอ + Hysteresis 2 ชม. + Cooldown 30 นาที
class AlertEngine {
  const AlertEngine();

  /// ปัดเศษแบบ half-up ทศนิยม 1 ตำแหน่งให้ตรงกับ Python Decimal(ROUND_HALF_UP) 100%
  static double _roundHalfUp1(double value) =>
      (value * 10.0 + 0.5 + 1e-9).floor() / 10.0;

  /// สูตรแจ้งเตือนล่วงหน้า `formula_version = 2` (ตรงกับ backend/pipeline.py compute_alert_v2)
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

    // 8. Agency Floor (ห้ามลดระดับต่ำกว่า situation_level)
    final floorLevel =
        situationLevel != null ? AlertLevel.fromSituation(situationLevel) : AlertLevel.normal;
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

  /// ใช้ Hysteresis 2 ชั่วโมง (คงระดับสูงไว้หากคะแนนลดลงยังไม่ครบ 2 ชม.)
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

  /// ประเมินระดับสุทธิของสถานีตาม settings ของผู้ใช้ + ฝน (รักษาความเข้ากันกับ UI และ tests เดิม)
  RiskLevel effectiveRisk(
    Station station,
    AlertSettings settings, {
    RainForecast? rain,
  }) {
    final sit = station.situationLevel;
    RiskLevel base;
    if (sit != null) {
      if (sit >= settings.dangerLevel) {
        base = RiskLevel.danger;
      } else if (sit >= settings.warningLevel) {
        base = RiskLevel.warning;
      } else if (sit >= 2) {
        base = RiskLevel.watch;
      } else {
        base = RiskLevel.normal;
      }
    } else {
      base = station.riskLevel;
    }

    if (settings.rainScoreEnabled && rain != null && rain.hasData) {
      final hasWaterEvidence =
          (sit != null && sit >= 2) ||
          (station.hasBank &&
              station.displayLevel != null &&
              station.remainingToBank != null &&
              station.remainingToBank! <= 2.0);
      if (hasWaterEvidence) {
        if (rain.score >= AppConfig.rainScoreDanger) {
          base = base.escalate();
        } else if (rain.score >= AppConfig.rainScoreWarn &&
            base.severity < RiskLevel.warning.severity) {
          base = RiskLevel.warning;
        }
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

      final risk = effectiveRisk(station, settings, rain: rain);
      if (!risk.isAtLeastWarning) continue;

      final assessment = assessV2(
        levelMsl: station.displayLevel,
        previousMsl: station.waterLevelMslPrev,
        bankM: station.hasBank ? station.bankLevel : null,
        situationLevel: station.situationLevel,
        rain1hMm: (settings.rainScoreEnabled && rain != null && rain.hasData)
            ? rain.score * 0.6
            : 0.0,
        isFlashFlood: AppConfig.flashFloodAmphoes.contains(station.amphoeTh ?? ''),
        leadTimeHours: AppConfig.bangLangDownstreamLeadTime[station.amphoeTh ?? ''],
      );

      final effectiveAlertLevel = applyHysteresis(
        current: assessment.level,
        memory: memoryByStation?[station.code],
        now: timestamp,
      );

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
          message: _buildMessage(station, risk, assessment),
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
      RiskLevel.warning => 'เตือนภัย',
      RiskLevel.watch => 'เฝ้าระวัง',
      _ => 'สถานะน้ำ',
    };
    return '$prefix: ${station.nameTh}';
  }

  String _buildMessage(Station station, RiskLevel level, AssessmentV2 assessment) {
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
    buf.write(' · คะแนนความเสี่ยง ${assessment.score.toStringAsFixed(1)}/100');
    return buf.toString();
  }

  /// คำแนะนำการปฏิบัติตัวภาษาไทยสำหรับหน้าจอรายละเอียดสถานี
  String guidanceTh(RiskLevel level, String amphoe) {
    final lead = AppConfig.bangLangDownstreamLeadTime[amphoe];
    final leadSuffix = lead != null ? ' (พื้นที่ท้ายเขื่อนบางลาง ระยะเวลาน้ำเดินทาง $lead)' : '';
    switch (level) {
      case RiskLevel.danger:
        return 'เตรียมอพยพทันทีไปยังจุดพักพิงปลอดภัย หากต้องการความช่วยเหลือโทร 1784 (ปภ.), 073-203559 (ปภ.ยะลา) หรือ 1669$leadSuffix';
      case RiskLevel.warning:
        return 'ยกของมีค่าขึ้นที่สูง เตรียมถุงยังชีพและแผนอพยพ ติดตามประกาศ ปภ.ยะลาอย่างใกล้ชิด$leadSuffix';
      case RiskLevel.watch:
        return 'ติดตามค่าระดับน้ำและฝนสะสมเป็นระยะ หลีกเลี่ยงพื้นที่ลุ่มต่ำและริมลำน้ำ$leadSuffix';
      case RiskLevel.normal:
        return 'สถานการณ์ระดับน้ำปกติ ยังควรติดตามข่าวพยากรณ์อากาศในช่วงฤดูมรสุม$leadSuffix';
      case RiskLevel.unknown:
        return 'ยังไม่มีเกณฑ์ระดับน้ำของสถานีนี้ โปรดตรวจสอบควบคู่กับฝนสะสมและประกาศ ปภ.ยะลา (073-203559)';
    }
  }
}
