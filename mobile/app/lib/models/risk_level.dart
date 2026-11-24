import 'package:material_ui/material_ui.dart';

/// ระดับความเสี่ยงสำหรับ UI Badge (4 ระดับหลัก + unknown)
enum RiskLevel {
  unknown('ไม่มีข้อมูล', 0),
  normal('ปกติ', 1),
  watch('เฝ้าระวัง', 2),
  warning('เตือนภัย', 3),
  danger('อันตราย', 4);

  const RiskLevel(this.labelTh, this.severity);

  final String labelTh;
  final int severity;

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

  RiskLevel escalate() => switch (this) {
        RiskLevel.unknown || RiskLevel.normal => RiskLevel.watch,
        RiskLevel.watch => RiskLevel.warning,
        RiskLevel.warning || RiskLevel.danger => RiskLevel.danger,
      };

  String get messageTh => switch (this) {
        RiskLevel.danger => 'ระดับน้ำถึงเกณฑ์อันตราย เตรียมอพยพทันที (โทร 1784 / 073-203559)',
        RiskLevel.warning => 'ระดับน้ำถึงเกณฑ์เตือนภัย ยกของขึ้นที่สูงและเตรียมอพยพ',
        RiskLevel.watch => 'ระดับน้ำเริ่มสูงขึ้น ติดตามสถานการณ์และเตรียมถุงยังชีพ',
        RiskLevel.normal => 'ระดับน้ำอยู่ในเกณฑ์ปกติ',
        RiskLevel.unknown => 'ยังไม่มีข้อมูลเกณฑ์ของสถานีนี้',
      };
}

extension RiskLevelVisual on RiskLevel {
  Color get color {
    switch (this) {
      case RiskLevel.danger:
        return const Color(0xFFB71C1C);
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

  Color colorFor(Brightness brightness) {
    if (brightness == Brightness.light) return color;
    switch (this) {
      case RiskLevel.danger:
        return const Color(0xFFFF6B6B);
      case RiskLevel.warning:
        return const Color(0xFFFFB74D);
      case RiskLevel.watch:
        return const Color(0xFFFFD54F);
      case RiskLevel.normal:
        return const Color(0xFF66BB6A);
      case RiskLevel.unknown:
        return const Color(0xFFB0BEC5);
    }
  }

  Color get onColor => this == RiskLevel.watch ? const Color(0xFF111827) : Colors.white;

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

/// ระดับแจ้งเตือน 5 ระดับตามสูตร Alert Score formula_version = 2
enum AlertLevel {
  normal(1, 'ปกติ', RiskLevel.normal, Color(0xFF2E7D32)),
  watch(2, 'เฝ้าระวัง', RiskLevel.watch, Color(0xFFF9A825)),
  warning(3, 'เตือนภัย', RiskLevel.warning, Color(0xFFEF6C00)),
  high(4, 'เตือนภัยสูง', RiskLevel.danger, Color(0xFFE53935)),
  danger(5, 'อันตราย', RiskLevel.danger, Color(0xFFB71C1C));

  const AlertLevel(this.value, this.labelTh, this.risk, this.color);

  final int value;
  final String labelTh;
  final RiskLevel risk;
  final Color color;

  Color get onSolidColor =>
      this == AlertLevel.watch ? const Color(0xFF111827) : Colors.white;

  Color colorFor(Brightness brightness) {
    if (brightness == Brightness.light) return color;
    return switch (this) {
      AlertLevel.normal => const Color(0xFF66BB6A),
      AlertLevel.watch => const Color(0xFFFFD54F),
      AlertLevel.warning => const Color(0xFFFFB74D),
      AlertLevel.high => const Color(0xFFEF5350),
      AlertLevel.danger => const Color(0xFFFF6B6B),
    };
  }

  static AlertLevel fromValue(int value) {
    final clamped = value.clamp(1, 5);
    return AlertLevel.values[clamped - 1];
  }

  static AlertLevel fromSituation(int? situation) {
    if (situation == null) return AlertLevel.normal;
    final clamped = situation.clamp(1, 4);
    return AlertLevel.values[clamped - 1];
  }

  static AlertLevel fromScore(double score) {
    if (score < 20.0) return AlertLevel.normal;
    if (score < 40.0) return AlertLevel.watch;
    if (score < 60.0) return AlertLevel.warning;
    if (score < 80.0) return AlertLevel.high;
    return AlertLevel.danger;
  }

  AlertLevel maxWith(AlertLevel other) => value >= other.value ? this : other;

  AlertLevel plusLevels(int delta) => fromValue(value + delta);

  String get guidanceTh => switch (this) {
        AlertLevel.danger => 'อพยพทันทีไปยังศูนย์พักพิงปลอดภัย หากติดค้างโทร 1784 / 1669',
        AlertLevel.high => 'พร้อมอพยพทันที ติดตามประกาศ ปภ.ยะลา (073-203559)',
        AlertLevel.warning => 'ยกของขึ้นที่สูง เตรียมเส้นทางและแผนอพยพ',
        AlertLevel.watch => 'ติดตามข่าวใกล้ชิด เตรียมถุงยังชีพและชาร์จแบต',
        AlertLevel.normal => 'ติดตามสถานการณ์ได้ตามปกติ',
      };
}
