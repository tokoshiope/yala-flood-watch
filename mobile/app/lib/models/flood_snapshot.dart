import 'package:latlong2/latlong.dart';

/// ข้อมูลพยากรณ์ฝนรายชั่วโมง (Open-Meteo, เวลาไทย UTC+7)
class HourlyRainPoint {
  const HourlyRainPoint({
    required this.timeIso,
    required this.mm,
    required this.probPct,
  });

  final String timeIso;
  final double mm;
  final int probPct;

  String get datePart => timeIso.contains('T') ? timeIso.split('T').first : '';
  String get hourMinute {
    if (!timeIso.contains('T')) return timeIso;
    final t = timeIso.split('T')[1];
    return t.length >= 5 ? t.substring(0, 5) : t;
  }

  factory HourlyRainPoint.fromJson(Map<String, dynamic> json) => HourlyRainPoint(
        timeIso: json['time']?.toString() ?? '',
        mm: (json['mm'] as num?)?.toDouble() ?? 0.0,
        probPct: (json['prob'] as num?)?.toInt() ?? 0,
      );
}

/// ข้อมูลสรุปเตือนภัยล่วงหน้ารายอำเภอ (ครบทั้ง 8 อำเภอรวม อ.กาบัง)
class AmphoeForecastSummary {
  const AmphoeForecastSummary({
    required this.amphoeTh,
    required this.basinTh,
    required this.level,
    required this.score,
    required this.labelTh,
    required this.actionTh,
    required this.rain1hMaxMm,
    required this.rain24hMaxMm,
    required this.forecast24hMm,
    required this.forecast72hMm,
    required this.hourlyNext24h,
    this.leadTimeHours,
  });

  final String amphoeTh;
  final String basinTh;
  final int level;
  final double score;
  final String labelTh;
  final String actionTh;
  final double rain1hMaxMm;
  final double rain24hMaxMm;
  final double forecast24hMm;
  final double forecast72hMm;
  final List<HourlyRainPoint> hourlyNext24h;
  final String? leadTimeHours;

  factory AmphoeForecastSummary.fromJson(Map<String, dynamic> json) {
    final rain = (json['rain'] as Map?)?.cast<String, dynamic>() ?? const {};
    final wx = (json['weather_forecast'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ass = (json['assessment'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawHourly = (wx['hourly_next_24h'] as List?) ?? const [];
    return AmphoeForecastSummary(
      amphoeTh: json['amphoe']?.toString() ?? '',
      basinTh: json['basin']?.toString() ?? '',
      level: (ass['level'] as num?)?.toInt() ?? 1,
      score: (ass['score'] as num?)?.toDouble() ?? 0.0,
      labelTh: ass['label_th']?.toString() ?? 'ปกติ',
      actionTh: ass['action_th']?.toString() ?? '',
      rain1hMaxMm: (rain['max_rain_1h_mm'] as num?)?.toDouble() ?? 0.0,
      rain24hMaxMm: (rain['max_rain_24h_mm'] as num?)?.toDouble() ?? 0.0,
      forecast24hMm: (wx['forecast_24h_mm'] as num?)?.toDouble() ?? 0.0,
      forecast72hMm: (wx['forecast_72h_mm'] as num?)?.toDouble() ?? 0.0,
      hourlyNext24h: rawHourly
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => HourlyRainPoint.fromJson(e.cast<String, dynamic>()))
          .toList(),
      leadTimeHours: ass['lead_time_hours']?.toString(),
    );
  }
}

/// ข้อมูลเขื่อนบางลาง (กฟผ. รายชั่วโมง + ชป. รายวัน)
class BangLangDamStatus {
  const BangLangDamStatus({
    required this.storagePercent,
    required this.storageMcm,
    required this.releasedDailyMcm,
    required this.spillwayActive,
    required this.observedAt,
  });

  final double? storagePercent;
  final double? storageMcm;
  final double? releasedDailyMcm;
  final bool spillwayActive;
  final String observedAt;

  factory BangLangDamStatus.fromJson(Map<String, dynamic> json) => BangLangDamStatus(
        storagePercent: (json['storage_percent'] as num?)?.toDouble(),
        storageMcm: (json['storage_mcm'] as num?)?.toDouble(),
        releasedDailyMcm: (json['released_daily_mcm'] as num?)?.toDouble(),
        spillwayActive: json['spillway_active'] == true,
        observedAt: (json['hourly_observed_at'] ?? json['daily_observed_at'] ?? '').toString(),
      );
}

/// Snapshot รวม 5 ฐานข้อมูลจาก Pipeline CDN หรือ Bundled Offline Asset
class FloodSnapshot {
  const FloodSnapshot({
    required this.formulaVersion,
    required this.generatedAtIso,
    required this.contentHash,
    required this.amphoes,
    required this.rainGaugeCount,
    this.bangLangDam,
    this.sourceLabel = 'Bundled 5-Source Snapshot',
  });

  final int formulaVersion;
  final String generatedAtIso;
  final String contentHash;
  final List<AmphoeForecastSummary> amphoes;
  final int rainGaugeCount;
  final BangLangDamStatus? bangLangDam;
  final String sourceLabel;

  AmphoeForecastSummary? byAmphoe(String amphoeTh) {
    for (final a in amphoes) {
      if (a.amphoeTh == amphoeTh) return a;
    }
    return null;
  }

  factory FloodSnapshot.fromJson(
    Map<String, dynamic> json, {
    String sourceLabel = 'Bundled 5-Source Snapshot',
  }) {
    final rawAmps = (json['amphoes'] as List?) ?? const [];
    final damJson = json['banglang_dam'];
    final rainSum = (json['rain_gauges_summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    return FloodSnapshot(
      formulaVersion: (json['formula_version'] as num?)?.toInt() ?? 2,
      generatedAtIso: json['generated_at']?.toString() ?? '',
      contentHash: json['content_hash']?.toString() ?? '',
      amphoes: rawAmps
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => AmphoeForecastSummary.fromJson(e.cast<String, dynamic>()))
          .toList(),
      rainGaugeCount: (rainSum['total'] as num?)?.toInt() ?? 0,
      bangLangDam: damJson is Map
          ? BangLangDamStatus.fromJson(damJson.cast<String, dynamic>())
          : null,
      sourceLabel: sourceLabel,
    );
  }
}

/// ขอบเขตภูมิศาสตร์ของแต่ละอำเภอ จ.ยะลา (แปลงจาก yala_amphoes.geojson)
class AmphoeBoundary {
  const AmphoeBoundary({
    required this.amphoeTh,
    required this.amphoeEn,
    required this.rings,
    required this.centroid,
  });

  final String amphoeTh;
  final String amphoeEn;
  final List<List<LatLng>> rings;
  final LatLng centroid;
}

/// ขอบเขตตำบลจริง จ.ยะลา (ครบ 58 ตำบล พร้อมความสูงภูมิประเทศจริง MSL)
class SubdistrictBoundary {
  const SubdistrictBoundary({
    required this.amphoeTh,
    required this.tumbonTh,
    required this.tumbonEn,
    required this.tumbonCode,
    required this.rings,
    required this.centroid,
    this.elevationMsl,
    this.minElevationMsl,
    this.maxElevationMsl,
    this.villageCount = 0,
  });

  final String amphoeTh;
  final String tumbonTh;
  final String tumbonEn;
  final String tumbonCode;
  final List<List<LatLng>> rings;
  final LatLng centroid;
  final double? elevationMsl;
  final double? minElevationMsl;
  final double? maxElevationMsl;
  final int villageCount;
}

/// หมู่บ้าน / ชุมชนจริง จ.ยะลา (ครบ 449 หมู่บ้านจาก DOPA พร้อมความสูงจริง MSL)
class VillagePoint {
  const VillagePoint({
    required this.code,
    required this.moo,
    required this.nameTh,
    required this.nameEn,
    required this.amphoeTh,
    required this.tumbonTh,
    required this.lat,
    required this.lon,
    this.elevationMsl,
  });

  final String code;
  final int moo;
  final String nameTh;
  final String nameEn;
  final String amphoeTh;
  final String tumbonTh;
  final double lat;
  final double lon;
  final double? elevationMsl;

  LatLng get point => LatLng(lat, lon);

  factory VillagePoint.fromJson(Map<String, dynamic> json) => VillagePoint(
        code: json['code']?.toString() ?? '',
        moo: (json['moo'] as num?)?.toInt() ?? 0,
        nameTh: json['name_th']?.toString() ?? '',
        nameEn: json['name_en']?.toString() ?? '',
        amphoeTh: json['amphoe_th']?.toString() ?? '',
        tumbonTh: json['tumbon_th']?.toString() ?? '',
        lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
        lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
        elevationMsl: (json['elevation_msl'] as num?)?.toDouble(),
      );
}

/// ผลประเมินระดับน้ำท่วมถึงจากความสูงพื้นที่จริง (MSL) เทียบระดับน้ำแม่น้ำ
class ElevationFloodResult {
  const ElevationFloodResult({
    required this.level,
    required this.summaryTh,
    this.marginMeters,
    this.refWaterMsl,
  });

  final int level;
  final String summaryTh;
  final double? marginMeters;
  final double? refWaterMsl;
}
