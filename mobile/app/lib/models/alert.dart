import 'package:yala_flood_app/models/risk_level.dart';

/// รายการแจ้งเตือนหนึ่งรายการ เก็บย้อนหลังไว้ในเครื่อง
class AlertItem {
  const AlertItem({
    required this.id,
    required this.stationCode,
    required this.stationName,
    required this.level,
    required this.title,
    required this.message,
    required this.createdAt,
    this.waterLevelMsl,
    this.rainScore,
    this.amphoeTh,
    this.read = false,
    this.score,
    this.alertLevel,
    this.waterSignal = false,
    this.pushed = false,
    this.leadTimeHours,
  });

  final String id;
  final String stationCode;
  final String stationName;
  final RiskLevel level;
  final String title;
  final String message;
  final DateTime createdAt;
  final double? waterLevelMsl;
  final int? rainScore;
  final String? amphoeTh;
  final bool read;
  final double? score;
  final AlertLevel? alertLevel;
  final bool waterSignal;
  final bool pushed;
  final String? leadTimeHours;

  bool get isActionable => level.isAtLeastWarning;

  AlertItem copyWith({bool? read, bool? pushed}) => AlertItem(
        id: id,
        stationCode: stationCode,
        stationName: stationName,
        level: level,
        title: title,
        message: message,
        createdAt: createdAt,
        waterLevelMsl: waterLevelMsl,
        rainScore: rainScore,
        amphoeTh: amphoeTh,
        read: read ?? this.read,
        score: score,
        alertLevel: alertLevel,
        waterSignal: waterSignal,
        pushed: pushed ?? this.pushed,
        leadTimeHours: leadTimeHours,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'stationCode': stationCode,
        'stationName': stationName,
        'level': level.name,
        'title': title,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'waterLevelMsl': waterLevelMsl,
        'rainScore': rainScore,
        'amphoeTh': amphoeTh,
        'read': read,
        'score': score,
        'alertLevel': alertLevel?.value,
        'waterSignal': waterSignal,
        'pushed': pushed,
        'leadTimeHours': leadTimeHours,
      };

  factory AlertItem.fromJson(Map<String, dynamic> json) => AlertItem(
        id: json['id'] as String? ?? '',
        stationCode: json['stationCode'] as String? ?? '',
        stationName: json['stationName'] as String? ?? '',
        level: RiskLevel.values.firstWhere(
          (e) => e.name == json['level'],
          orElse: () => RiskLevel.unknown,
        ),
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
        waterLevelMsl: json['waterLevelMsl'] is num
            ? (json['waterLevelMsl'] as num).toDouble()
            : null,
        rainScore: json['rainScore'] is num
            ? (json['rainScore'] as num).toInt()
            : null,
        amphoeTh: json['amphoeTh'] as String?,
        read: json['read'] as bool? ?? false,
        score: json['score'] is num ? (json['score'] as num).toDouble() : null,
        alertLevel: json['alertLevel'] is num
            ? AlertLevel.fromValue((json['alertLevel'] as num).toInt())
            : null,
        waterSignal: json['waterSignal'] as bool? ?? false,
        pushed: json['pushed'] as bool? ?? false,
        leadTimeHours: json['leadTimeHours'] as String?,
      );

  /// รหัส unique ตามสถานี + ระดับ + หน้าต่างเวลา (ระดับชั่วโมงเพื่อลดซ้ำระดับนาที)
  static String buildId(String stationCode, RiskLevel level, DateTime time) {
    final minute = time.toIso8601String().substring(0, 16);
    return '$stationCode-${level.name}-$minute';
  }

  @override
  String toString() => 'AlertItem($stationName, ${level.labelTh})';
}
