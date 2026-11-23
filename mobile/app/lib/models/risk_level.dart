import 'package:material_ui/material_ui.dart';

/// ระดับความเสี่ยงของสถานี
/// ค่าต้องเรียงจากน้อยไปมาก เพื่อให้เปรียบเทียบด้วย [severity] ได้
enum RiskLevel {
  unknown('ไม่มีข้อมูล', 0),
  normal('ปกติ', 1),
  watch('เฝ้าระวัง', 2),
  warning('เตือนภัย', 3),
  danger('อันตราย', 4);

  const RiskLevel(this.labelTh, this.severity);

  /// ชื่อภาษาไทยสำหรับแสดงผล
  final String labelTh;

  /// ค่าความรุนแรง ใช้เปรียบเทียบ/จัดเรียงได้
  final int severity;

  /// รับค่า situation_level จาก ThaiWater (อาจเป็น null)
  factory RiskLevel.fromSituation(int? situation) {
    switch (situation) {
      case 4:
        return RiskLevel.danger;
      case 3:
        return RiskLevel.warning;
      case 2:
        return RiskLevel.watch;
      case 1:
      case 0:
        return RiskLevel.normal;
      default:
        return RiskLevel.unknown;
    }
  }

  bool get isAtLeastWarning => severity >= warning.severity;
  bool get isDanger => this == RiskLevel.danger;

  /// เพิ่มระดับหนึ่งระดับ (สำหรับเอาคะแนนฝนมาปรับ)
  RiskLevel escalate() => switch (this) {
        RiskLevel.unknown || RiskLevel.normal => RiskLevel.watch,
        RiskLevel.watch => RiskLevel.warning,
        RiskLevel.warning || RiskLevel.danger => RiskLevel.danger,
      };

  String get messageTh => switch (this) {
        RiskLevel.danger => 'ระดับน้ำถึงเกณฑ์อันตราย ควรเตรียมอพยพ',
        RiskLevel.warning => 'ระดับน้ำถึงเกณฑ์เตือนภัย เฝ้าระวังตลอด',
        RiskLevel.watch => 'ระดับน้ำเริ่มสูงขึ้น โปรดติดตามค่าถี่',
        RiskLevel.normal => 'ระดับน้ำอยู่ในเกณฑ์ปกติ',
        RiskLevel.unknown => 'ยังไม่มีข้อมูลเกณฑ์ของสถานีนี้',
      };
}

/// สีประจำระดับ กับไอคอน แยกไว้ตรงนี้เพื่อโมเดลไม่ต้องรู้จักสี
extension RiskLevelVisual on RiskLevel {
  Color get color {
    switch (this) {
      case RiskLevel.danger:
        return const Color(0xFFC62828);
      case RiskLevel.warning:
        return const Color(0xFFEF6C00);
      case RiskLevel.watch:
        return const Color(0xFFF9A825);
      case RiskLevel.normal:
        return const Color(0xFF2E7D32);
      case RiskLevel.unknown:
        return const Color(0xFF616161);
    }
  }

  Color get onColor => Colors.white;

  IconData get icon {
    switch (this) {
      case RiskLevel.danger:
        return Icons.dangerous_outlined;
      case RiskLevel.warning:
        return Icons.warning_amber_rounded;
      case RiskLevel.watch:
        return Icons.visibility_outlined;
      case RiskLevel.normal:
        return Icons.check_circle_outline;
      case RiskLevel.unknown:
        return Icons.help_outline;
    }
  }
}
