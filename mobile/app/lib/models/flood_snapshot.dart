import 'package:latlong2/latlong.dart';

import 'package:yala_flood_app/models/station.dart';

/// หมู่บ้านและตำบลพื้นที่เฝ้าระวังสำคัญในอำเภอ (เทียบความสูงจริง Copernicus DEM กับระดับน้ำแม่น้ำ)
class WatchAreaInfo {
  const WatchAreaInfo({
    required this.nameTh,
    required this.nameEn,
    required this.moo,
    required this.tumbonTh,
    this.elevationMsl,
    this.marginM,
  });

  final String nameTh;
  final String nameEn;
  final int moo;
  final String tumbonTh;
  final double? elevationMsl;
  final double? marginM;

  factory WatchAreaInfo.fromJson(Map<String, dynamic> json) => WatchAreaInfo(
        nameTh: json['name_th']?.toString() ?? '',
        nameEn: json['name_en']?.toString() ?? '',
        moo: (json['moo'] as num?)?.toInt() ?? 0,
        tumbonTh: json['tumbon_th']?.toString() ?? '',
        elevationMsl: (json['elevation_msl'] as num?)?.toDouble(),
        marginM: (json['margin_m'] as num?)?.toDouble(),
      );
}

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
    this.rain72hMm = 0.0,
    this.api7dMm = 0.0,
    this.forecast6hMm = 0.0,
    this.floodMechanism = 'monitoring',
    this.confidence = 'high',
    this.leadTimeHours,
    this.watchAreas = const <WatchAreaInfo>[],
  });

  final String amphoeTh;
  final String basinTh;
  final int level;
  final double score;
  final String labelTh;
  final String actionTh;
  final double rain1hMaxMm;
  final double rain24hMaxMm;
  final double rain72hMm;
  final double api7dMm;
  final double forecast6hMm;
  final double forecast24hMm;
  final double forecast72hMm;
  final String floodMechanism;
  final String confidence;
  final List<HourlyRainPoint> hourlyNext24h;
  final String? leadTimeHours;
  final List<WatchAreaInfo> watchAreas;

  factory AmphoeForecastSummary.fromJson(Map<String, dynamic> json) {
    final rain = (json['rain'] as Map?)?.cast<String, dynamic>() ?? const {};
    final wx = (json['weather_forecast'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ass = (json['assessment'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rawHourly = (wx['hourly_next_24h'] as List?) ?? const [];
    final rawWatch = (json['watch_areas'] as List?) ?? const [];
    return AmphoeForecastSummary(
      amphoeTh: json['amphoe']?.toString() ?? '',
      basinTh: json['basin']?.toString() ?? '',
      level: (ass['level'] as num?)?.toInt() ?? 1,
      score: (ass['score'] as num?)?.toDouble() ?? 0.0,
      labelTh: ass['label_th']?.toString() ?? 'ปกติ',
      actionTh: ass['action_th']?.toString() ?? '',
      rain1hMaxMm: (rain['max_rain_1h_mm'] as num?)?.toDouble() ?? 0.0,
      rain24hMaxMm: (rain['max_rain_24h_mm'] as num?)?.toDouble() ?? 0.0,
      rain72hMm: (wx['observed_rain_72h_mm'] as num?)?.toDouble() ?? 0.0,
      api7dMm: (wx['api_7d_mm'] as num?)?.toDouble() ?? 0.0,
      forecast6hMm: (wx['forecast_6h_mm'] as num?)?.toDouble() ?? 0.0,
      forecast24hMm: (wx['forecast_24h_mm'] as num?)?.toDouble() ?? 0.0,
      forecast72hMm: (wx['forecast_72h_mm'] as num?)?.toDouble() ?? 0.0,
      floodMechanism: ass['flood_mechanism']?.toString() ?? 'monitoring',
      confidence: ass['confidence']?.toString() ?? 'high',
      hourlyNext24h: rawHourly
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => HourlyRainPoint.fromJson(e.cast<String, dynamic>()))
          .toList(),
      leadTimeHours: ass['lead_time_hours']?.toString(),
      watchAreas: rawWatch
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => WatchAreaInfo.fromJson(e.cast<String, dynamic>()))
          .toList(),
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
    this.stationHistory7dByCode = const <String, List<WaterLevelPoint>>{},
    this.stationTeleIdByCode = const <String, int>{},
    this.sourceLabel = 'Bundled 5-Source Snapshot',
  });

  final int formulaVersion;
  final String generatedAtIso;
  final String contentHash;
  final List<AmphoeForecastSummary> amphoes;
  final int rainGaugeCount;
  final BangLangDamStatus? bangLangDam;
  final Map<String, List<WaterLevelPoint>> stationHistory7dByCode;
  final Map<String, int> stationTeleIdByCode;
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
    final rawStations = (json['stations'] as List?) ?? const [];
    final histMap = <String, List<WaterLevelPoint>>{};
    final teleIdMap = <String, int>{};
    for (final item in rawStations) {
      if (item is! Map) continue;
      final oc = item['oldcode']?.toString().trim() ?? '';
      if (oc.isEmpty) continue;
      final tid = item['tele_station_id'];
      if (tid is num) teleIdMap[oc] = tid.toInt();
      final rawHist = item['history_7d'];
      if (rawHist is List && rawHist.isNotEmpty) {
        final pts = <WaterLevelPoint>[];
        for (final pt in rawHist) {
          if (pt is Map) {
            final cast = pt.cast<String, dynamic>();
            final val = cast['v'] ?? cast['value'];
            if (val is num && val.isFinite) {
              pts.add(WaterLevelPoint.fromJson(cast));
            }
          }
        }
        if (pts.isNotEmpty) histMap[oc] = pts;
      }
    }
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
      stationHistory7dByCode: histMap,
      stationTeleIdByCode: teleIdMap,
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

/// แถบความสูงภูมิประเทศจริงจาก Copernicus DEM สำหรับระบายสีไล่ระดับตาม ม.รทก. บนแผนที่
class ElevationBandZone {
  const ElevationBandZone({
    required this.amphoeTh,
    required this.band,
    required this.elevMin,
    required this.elevMax,
    required this.elevMid,
    required this.ring,
  });

  final String amphoeTh;
  final String band;
  final double elevMin;
  final double elevMax;
  final double elevMid;
  final List<LatLng> ring;
}

/// ขอบเขตโซนหมู่บ้านแบบเว้าโค้งตามภูมิประเทศภายในขอบเขตตำบลจริง
class VillageZoneBoundary {
  const VillageZoneBoundary({
    required this.code,
    required this.moo,
    required this.nameTh,
    required this.nameEn,
    required this.amphoeTh,
    required this.tumbonTh,
    required this.ring,
    this.elevationMsl,
  });

  final String code;
  final int moo;
  final String nameTh;
  final String nameEn;
  final String amphoeTh;
  final String tumbonTh;
  final List<LatLng> ring;
  final double? elevationMsl;
}

/// ตารางความสูงภูมิประเทศจริง (Copernicus DEM) สำหรับคำนวณ ม.รทก. ณ พิกัด GPS หรือหมุดผู้ใช้แบบออฟไลน์ทันที
class DemElevationGrid {
  const DemElevationGrid({
    required this.latMin,
    required this.lonMin,
    required this.step,
    required this.rows,
    required this.cols,
    required this.values,
  });

  final double latMin;
  final double lonMin;
  final double step;
  final int rows;
  final int cols;
  final List<List<int?>> values;

  /// คำนวณความสูง ม.รทก. แบบ Bilinear Interpolation ที่พิกัด (lat, lon)
  double? elevationAt(double lat, double lon) {
    if (rows <= 0 || cols <= 0 || step <= 0) return null;
    final fr = (lat - latMin) / step;
    final fc = (lon - lonMin) / step;
    final r0 = fr.floor();
    final c0 = fc.floor();
    if (r0 < 0 || c0 < 0 || r0 >= rows || c0 >= cols) return null;
    final r1 = (r0 + 1).clamp(0, rows - 1);
    final c1 = (c0 + 1).clamp(0, cols - 1);
    final dr = (fr - r0).clamp(0.0, 1.0);
    final dc = (fc - c0).clamp(0.0, 1.0);

    final v00 = values[r0][c0];
    final v01 = values[r0][c1];
    final v10 = values[r1][c0];
    final v11 = values[r1][c1];

    if (v00 != null && v01 != null && v10 != null && v11 != null) {
      final top = v00 * (1 - dc) + v01 * dc;
      final bot = v10 * (1 - dc) + v11 * dc;
      return double.parse((top * (1 - dr) + bot * dr).toStringAsFixed(1));
    }
    final valid = <int>[?v00, ?v01, ?v10, ?v11];
    if (valid.isEmpty) return null;
    final avg = valid.reduce((a, b) => a + b) / valid.length;
    return double.parse(avg.toStringAsFixed(1));
  }
}

/// ข้อมูลเปรียบเทียบระดับความสูงและระดับแจ้งเตือน ณ ตำแหน่ง GPS หรือจุดปักหมุดของผู้ใช้
class UserPinAssessment {
  const UserPinAssessment({
    required this.lat,
    required this.lng,
    required this.isGps,
    required this.level,
    this.amphoeTh,
    this.tumbonTh,
    this.tumbonEn,
    this.elevationMsl,
    this.refWaterMsl,
    this.marginMeters,
    this.nearestStationCode,
    this.nearestStationDistKm,
  });

  final double lat;
  final double lng;
  final bool isGps;
  final int level;
  final String? amphoeTh;
  final String? tumbonTh;
  final String? tumbonEn;
  final double? elevationMsl;
  final double? refWaterMsl;
  final double? marginMeters;
  final String? nearestStationCode;
  final double? nearestStationDistKm;

  LatLng get point => LatLng(lat, lng);
}
