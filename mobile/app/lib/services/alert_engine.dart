import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/alert_settings.dart';
import 'package:yala_flood_app/models/rain_forecast.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';

/// ตรรกะตัดสินว่าสถานีไหนต้องแจ้งเตือน
///
/// กฎหลัก (จากเกณฑ์ ThaiWater):
///   situation_level >= 3  → เตือนภัย
///   situation_level >= 4  → อันตราย
/// ถ้าสถานีไม่มี situation_level ใช้ระดับน้ำเทียบตลิ่งแทน
/// และรองรับการปรับระดับด้วยคะแนนฝนในอนาคต ([RainForecast])
class AlertEngine {
  const AlertEngine();

  /// คำนวณระดับความเสี่ยงที่ใช้จริงของสถานี ตามเกณฑ์ในการตั้งค่า
  RiskLevel effectiveRisk(
    Station station,
    AlertSettings settings, {
    RainForecast? rain,
  }) {
    RiskLevel base;

    final situation = station.situationLevel;
    if (situation != null) {
      if (situation >= settings.dangerLevel) {
        base = RiskLevel.danger;
      } else if (situation >= settings.warningLevel) {
        base = RiskLevel.warning;
      } else if (situation >= 2) {
        base = RiskLevel.watch;
      } else {
        base = RiskLevel.normal;
      }
    } else {
      base = station.riskLevel;
    }

    // ถ้าสถานีไม่มีเกณฑ์เลย ให้ถ่วงน้ำหนักไปที่ระดับน้ำเทียบตลิ่ง
    if (base == RiskLevel.unknown && station.hasBank) {
      base = station.riskLevel;
    }

    if (!settings.rainScoreEnabled) return base;
    final suggestion = rain?.suggestedLevel;
    if (rain == null || suggestion == null) return base;

    // ใช้ระดับที่รุนแรงกว่า และไม่เพิ่มเกินหนึ่งระดับจากข้อมูลระดับน้ำ
    final combined =
        suggestion.severity > base.severity ? suggestion : base;
    if (combined.severity > base.severity) return base.escalate();
    return combined;
  }

  /// สร้างรายการแจ้งเตือนใหม่จากสถานีที่ผ่านเกณฑ์
  ///
  /// [previous] ใช้กันการซ้ำ: ถ้าสถานี+ระดับเดิมอยู่ในประวัติแล้วจะไม่สร้างซ้ำ
  List<AlertItem> evaluate({
    required List<Station> stations,
    AlertSettings settings = const AlertSettings(),
    RainForecast? rain,
    DateTime? now,
    List<AlertItem> previous = const <AlertItem>[],
  }) {
    final at = now ?? DateTime.now();
    final seen = previous.map((a) => a.id).toSet();
    final result = <AlertItem>[];

    for (final station in stations) {
      if (!_matchesFilter(station, settings)) continue;
      final level = effectiveRisk(station, settings, rain: rain);
      if (!level.isAtLeastWarning) continue;

      final id = AlertItem.buildId(station.code, level, at);
      if (seen.contains(id)) continue;

      result.add(
        AlertItem(
          id: id,
          stationCode: station.code,
          stationName: station.nameTh,
          level: level,
          title: _title(station, level),
          message: _message(station, level, rain),
          createdAt: at,
          waterLevelMsl: station.displayLevel,
          rainScore: rain?.hasData ?? false ? rain!.score : null,
          amphoeTh: station.amphoeTh,
        ),
      );
      seen.add(id);
    }

    result.sort((a, b) {
      final byLevel = b.level.severity.compareTo(a.level.severity);
      if (byLevel != 0) return byLevel;
      return b.createdAt.compareTo(a.createdAt);
    });
    return result;
  }

  bool _matchesFilter(Station station, AlertSettings settings) {
    final amphoe = settings.selectedAmphoeTh;
    if (amphoe != null && amphoe.isNotEmpty) {
      if (station.amphoeTh != amphoe) return false;
    }
    final tumbon = settings.selectedTumbonTh;
    if (tumbon != null && tumbon.isNotEmpty) {
      if (station.tumbonTh != tumbon) return false;
    }
    return true;
  }

  String _title(Station station, RiskLevel level) {
    final prefix = level == RiskLevel.danger ? 'อันตราย' : 'เตือนภัย';
    return '$prefix: ${station.nameTh}';
  }

  String _message(Station station, RiskLevel level, RainForecast? rain) {
    final buffer = StringBuffer();
    final wl = station.displayLevel;
    if (wl != null) {
      buffer.write('ระดับน้ำ ${wl.toStringAsFixed(2)} ม. (MSL)');
    } else {
      buffer.write('ยังไม่มีค่าระดับน้ำ');
    }

    final bank = station.bankLevel;
    if (bank != null && bank > 0) {
      final remaining = station.remainingToBank;
      if (remaining != null) {
        buffer.write(
          remaining >= 0
              ? ' เหลือ ${remaining.toStringAsFixed(2)} ม. ถึงตลิ่ง'
              : ' ล้นตลิ่ง ${(-remaining).toStringAsFixed(2)} ม.',
        );
      }
    }

    if (station.trend != WaterTrend.unknown) {
      buffer.write(' (${station.trend.labelTh})');
    }

    if (rain != null && rain.hasData) {
      buffer.write(' · ค่าฝน ${rain.score}/100');
    }

    buffer.write(' · ${station.locationLabel}');
    return buffer.toString();
  }

  /// คำแนะนำสำหรับหน้าจอรายละเอียด
  String guidanceTh(RiskLevel level, String amphoe) {
    switch (level) {
      case RiskLevel.danger:
        return 'เตรียมอพยพทันทีไปยังจุดอพยพที่สูง นำของจำเป็นและเอกสารสำคัญไปด้วย';
      case RiskLevel.warning:
        return 'เตรียมตัวอพยพ เฝ้าระวังข่าว และเตรียมถุงยังชีพไว้ใกล้ตัว';
      case RiskLevel.watch:
        return 'ติดตามค่าถี่ หลีกเลี่ยงพื้นที่ต่ำและริมลำน้ำ';
      case RiskLevel.normal:
        return 'สถานการณ์ปกติ ยังควรติดตามค่าระดับน้ำเป็นระยะ';
      case RiskLevel.unknown:
        return 'ยังไม่มีข้อมูลของสถานีนี้ ควรสอบถามจาก ศูนย์ปภ.ยะลา';
    }
  }

  /// อำเภอที่เลือกอยู่ในรายชื่อเสี่ยงหรือไม่
  bool isRiskAmphoe(String? amphoe) =>
      amphoe != null && AppConfig.riskAmphoeTh.contains(amphoe);
}
