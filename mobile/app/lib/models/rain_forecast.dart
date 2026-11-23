import 'package:yala_flood_app/models/risk_level.dart';

/// คะแนนฝนในอนาคต (0-100) ที่ใช้ปรับความรุนแรงของแจ้งเตือน
///
/// ขณะนี้ยังไม่มี API ฝนที่เปิดใช้งาน (ดู [AppConfig.rainForecastEndpoint])
/// โมเดลนี้เตรียมไว้ให้ [AlertEngine] ใช้ทันทีเมื่อมีแหล่งข้อมูล
class RainForecast {
  const RainForecast({
    required this.score,
    required this.source,
    required this.summaryTh,
    this.validAt,
    this.stationCode,
  });

  /// 0-100 ค่าสูง = ฝนตกหนัก/เสี่ยงสูง
  final int score;

  /// แหล่งข้อมูล เช่น "กรมอุตุฯ", "TMD", "จากผู้ใช้"
  final String source;

  final String summaryTh;
  final DateTime? validAt;
  final String? stationCode;

  /// ไม่มีข้อมูลฝน
  factory RainForecast.none({String stationCode = ''}) => RainForecast(
        score: 0,
        source: '-',
        summaryTh: 'ยังไม่มีข้อมูลค่าฝน',
        stationCode: stationCode,
    );

  bool get hasData => score > 0;

  /// ระดับที่ฝนควรปรับให้รุนแรงขึ้น
  RiskLevel? get suggestedLevel {
    if (score >= 85) return RiskLevel.danger;
    if (score >= 60) return RiskLevel.warning;
    if (score >= 40) return RiskLevel.watch;
    return null;
  }
}
