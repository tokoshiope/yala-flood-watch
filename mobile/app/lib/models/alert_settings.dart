import 'package:yala_flood_app/config/app_config.dart';

/// การตั้งค่าของผู้ใช้ เก็บใน SharedPreferences
class AlertSettings {
  const AlertSettings({
    this.selectedAmphoeTh,
    this.selectedTumbonTh,
    this.warningLevel = AppConfig.defaultWarningLevel,
    this.dangerLevel = AppConfig.defaultDangerLevel,
    this.quietMode = false,
    this.pushEnabled = true,
    this.rainScoreEnabled = true,
    this.refreshMinutes = 15,
  });

  /// อำเภอที่เลือกฟังการแจ้งเตือน (null = ทั้งจังหวัด)
  final String? selectedAmphoeTh;

  /// ตำบลที่เลือก (null = ทุกตำบลในอำเภอ)
  final String? selectedTumbonTh;

  /// situation_level ที่ถือว่า "เตือนภัย"
  final int warningLevel;

  /// situation_level ที่ถือว่า "อันตราย"
  final int dangerLevel;

  /// โหมดเงียบ: ยังแสดงสถานะแต่ไม่เล่นเสียง/สั่น
  final bool quietMode;

  /// เปิด Push
  final bool pushEnabled;

  /// นำคะแนนฝนมาปรับระดับความรุนแรงด้วยหรือไม่
  final bool rainScoreEnabled;

  /// รอบการรีเฟรชอัตโนมัติ (นาที)
  final int refreshMinutes;

  AlertSettings copyWith({
    String? selectedAmphoeTh,
    String? selectedTumbonTh,
    bool clearAmphoe = false,
    bool clearTumbon = false,
    int? warningLevel,
    int? dangerLevel,
    bool? quietMode,
    bool? pushEnabled,
    bool? rainScoreEnabled,
    int? refreshMinutes,
  }) =>
      AlertSettings(
        selectedAmphoeTh:
            clearAmphoe ? null : (selectedAmphoeTh ?? this.selectedAmphoeTh),
        selectedTumbonTh:
            clearTumbon ? null : (selectedTumbonTh ?? this.selectedTumbonTh),
        warningLevel: warningLevel ?? this.warningLevel,
        dangerLevel: dangerLevel ?? this.dangerLevel,
        quietMode: quietMode ?? this.quietMode,
        pushEnabled: pushEnabled ?? this.pushEnabled,
        rainScoreEnabled: rainScoreEnabled ?? this.rainScoreEnabled,
        refreshMinutes: refreshMinutes ?? this.refreshMinutes,
      );

  /// ล้างค่าที่เป็น null ได้ (ใช้กับ dropdown ที่เลือก "ทั้งหมด")
  AlertSettings clearAmphoe() => AlertSettings(
        selectedAmphoeTh: null,
        selectedTumbonTh: null,
        warningLevel: warningLevel,
        dangerLevel: dangerLevel,
        quietMode: quietMode,
        pushEnabled: pushEnabled,
        rainScoreEnabled: rainScoreEnabled,
        refreshMinutes: refreshMinutes,
      );

  Map<String, dynamic> toJson() => {
        'selectedAmphoeTh': selectedAmphoeTh,
        'selectedTumbonTh': selectedTumbonTh,
        'warningLevel': warningLevel,
        'dangerLevel': dangerLevel,
        'quietMode': quietMode,
        'pushEnabled': pushEnabled,
        'rainScoreEnabled': rainScoreEnabled,
        'refreshMinutes': refreshMinutes,
      };

  factory AlertSettings.fromJson(Map<String, dynamic> json) => AlertSettings(
        selectedAmphoeTh: json['selectedAmphoeTh'] as String?,
        selectedTumbonTh: json['selectedTumbonTh'] as String?,
        warningLevel: _intOr(json['warningLevel'], AppConfig.defaultWarningLevel),
        dangerLevel: _intOr(json['dangerLevel'], AppConfig.defaultDangerLevel),
        quietMode: json['quietMode'] as bool? ?? false,
        pushEnabled: json['pushEnabled'] as bool? ?? true,
        rainScoreEnabled: json['rainScoreEnabled'] as bool? ?? true,
        refreshMinutes: _intOr(json['refreshMinutes'], 15),
      );

  static int _intOr(dynamic value, int fallback) =>
      value is num ? value.toInt() : fallback;
}
