import 'package:yala_flood_app/config/app_config.dart';

/// การตั้งค่าของผู้ใช้ เก็บใน SharedPreferences (รวมภาษา 4 ภาษา: th / en / zh / ms)
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
    this.languageCode = 'th',
  });

  final String? selectedAmphoeTh;
  final String? selectedTumbonTh;
  final int warningLevel;
  final int dangerLevel;
  final bool quietMode;
  final bool pushEnabled;
  final bool rainScoreEnabled;
  final int refreshMinutes;

  /// รหัสภาษา UI และแผนที่ Google Maps: 'th' | 'en' | 'zh' | 'ms'
  final String languageCode;

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
    String? languageCode,
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
        languageCode: languageCode ?? this.languageCode,
      );

  AlertSettings clearAmphoe() => AlertSettings(
        selectedAmphoeTh: null,
        selectedTumbonTh: null,
        warningLevel: warningLevel,
        dangerLevel: dangerLevel,
        quietMode: quietMode,
        pushEnabled: pushEnabled,
        rainScoreEnabled: rainScoreEnabled,
        refreshMinutes: refreshMinutes,
        languageCode: languageCode,
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
        'languageCode': languageCode,
      };

  factory AlertSettings.fromJson(Map<String, dynamic> json) {
    final lang = json['languageCode']?.toString() ?? 'th';
    final validLang = const {'th', 'en', 'zh', 'ms'}.contains(lang) ? lang : 'th';
    return AlertSettings(
      selectedAmphoeTh: json['selectedAmphoeTh'] as String?,
      selectedTumbonTh: json['selectedTumbonTh'] as String?,
      warningLevel: _intOr(json['warningLevel'], AppConfig.defaultWarningLevel),
      dangerLevel: _intOr(json['dangerLevel'], AppConfig.defaultDangerLevel),
      quietMode: json['quietMode'] as bool? ?? false,
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      rainScoreEnabled: json['rainScoreEnabled'] as bool? ?? true,
      refreshMinutes: _intOr(json['refreshMinutes'], 15),
      languageCode: validLang,
    );
  }

  static int _intOr(dynamic value, int fallback) =>
      value is num ? value.toInt() : fallback;
}
