import 'package:material_ui/material_ui.dart';

/// ระดับความเสี่ยงสำหรับ UI Badge (ครบ 5 ระดับหลักตรงกับ AlertLevel 1–5 + unknown)
enum RiskLevel {
  unknown('ไม่มีข้อมูล', 0),
  normal('ปกติ', 1),
  watch('เฝ้าระวัง', 2),
  warning('เตือนภัย', 3),
  high('เตือนภัยสูง', 4),
  danger('อันตราย', 5);

  const RiskLevel(this.labelTh, this.severity);

  final String labelTh;
  final int severity;

  /// แปลง ThaiWater `situation_level` (1=น้อยวิกฤต ≤10%, 2=น้อย 10–30%, 3=ปกติ 30–70%,
  /// 4=มาก 70–100%, 5=ล้นตลิ่ง >100%) เป็นระดับเตือนภัยน้ำท่วมที่ถูกต้อง
  factory RiskLevel.fromSituation(int? situation) {
    switch (situation) {
      case 5:
        return RiskLevel.danger;
      case 4:
        return RiskLevel.watch;
      case 3:
      case 2:
      case 1:
      case 0:
        return RiskLevel.normal;
      default:
        return RiskLevel.unknown;
    }
  }

  bool get isAtLeastWarning => severity >= warning.severity;
  bool get isHighOrDanger => severity >= high.severity;
  bool get isDanger => this == RiskLevel.danger;

  RiskLevel escalate() => switch (this) {
        RiskLevel.unknown || RiskLevel.normal => RiskLevel.watch,
        RiskLevel.watch => RiskLevel.warning,
        RiskLevel.warning => RiskLevel.high,
        RiskLevel.high || RiskLevel.danger => RiskLevel.danger,
      };

  String get messageTh => switch (this) {
        RiskLevel.danger =>
          'เกิดอุทกภัยในพื้นที่แล้ว ระดับน้ำล้นตลิ่ง โปรดอพยพทันทีไปยังศูนย์พักพิงที่ปลอดภัย (โทร. 1784 / 073-203559 / 1669)',
        RiskLevel.high =>
          'ระดับน้ำเข้าใกล้ระดับวิกฤตหรือพื้นที่ใกล้เคียงประสบอุทกภัย เตรียมพร้อมอพยพทันทีและติดตามประกาศ ปภ.ยะลา (073-203559)',
        RiskLevel.warning =>
          'มีแนวโน้มเกิดอุทกภัยภายใน 24 ชั่วโมง หรืออาจเกิดน้ำป่าไหลหลากฉับพลัน ขนย้ายทรัพย์สินขึ้นที่สูงและเตรียมแผนอพยพ',
        RiskLevel.watch =>
          'ระดับน้ำเริ่มสูงขึ้นเข้าใกล้เกณฑ์เฝ้าระวัง โปรดติดตามประกาศอย่างใกล้ชิดและเตรียมสิ่งของจำเป็น',
        RiskLevel.normal =>
          'ระดับน้ำต่ำกว่าเกณฑ์เฝ้าระวัง สถานการณ์อยู่ในภาวะปกติ',
        RiskLevel.unknown => 'ยังไม่มีข้อมูลเกณฑ์อ้างอิงของสถานีนี้',
      };
}

extension RiskLevelVisual on RiskLevel {
  Color get color {
    switch (this) {
      case RiskLevel.danger:
        return const Color(0xFFB71C1C);
      case RiskLevel.high:
        return const Color(0xFFE53935);
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
      case RiskLevel.high:
        return const Color(0xFFEF5350);
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
      case RiskLevel.high:
        return Icons.error_outline_rounded;
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

/// ระดับแจ้งเตือน 5 ระดับตามสูตร formula_version = 5
enum AlertLevel {
  normal(1, 'ปกติ', RiskLevel.normal, Color(0xFF2E7D32)),
  watch(2, 'เฝ้าระวัง', RiskLevel.watch, Color(0xFFF9A825)),
  warning(3, 'เตือนภัย', RiskLevel.warning, Color(0xFFEF6C00)),
  high(4, 'เตือนภัยสูง', RiskLevel.high, Color(0xFFE53935)),
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

  /// แปลง ThaiWater `situation_level` (1=น้อยวิกฤต, 2=น้อย, 3=ปกติ, 4=มาก, 5=ล้นตลิ่ง)
  /// 1–3 = ปกติ, 4 = เฝ้าระวัง (fallback เฉพาะสถานีไร้ตลิ่ง), 5 = อันตราย (ล้นตลิ่ง)
  static AlertLevel fromSituation(int? situation) {
    if (situation == null) return AlertLevel.normal;
    if (situation >= 5) return AlertLevel.danger;
    if (situation == 4) return AlertLevel.watch;
    return AlertLevel.normal;
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
        AlertLevel.danger =>
          'อพยพทันทีไปยังศูนย์พักพิงชั่วคราวที่ปลอดภัย หากต้องการความช่วยเหลือเร่งด่วน โทร. 1784, 073-203559 หรือ 1669',
        AlertLevel.high =>
          'เตรียมพร้อมอพยพทันที ตัดกระแสไฟฟ้าชั้นล่างหากน้ำเริ่มเข้าพื้นที่ และติดตามประกาศ ปภ.ยะลา (073-203559)',
        AlertLevel.warning =>
          'ขนย้ายทรัพย์สินขึ้นที่สูง ตรวจสอบเส้นทางปลอดภัย และเตรียมแผนอพยพกลุ่มเปราะบาง',
        AlertLevel.watch =>
          'ติดตามประกาศอย่างใกล้ชิด เตรียมสิ่งของจำเป็น ยาประจำตัว และสำรองพลังงานอุปกรณ์สื่อสาร',
        AlertLevel.normal =>
          'ติดตามข่าวสารพยากรณ์อากาศและสถานการณ์น้ำตามปกติ',
      };
}
