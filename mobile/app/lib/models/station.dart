import 'package:material_ui/material_ui.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/risk_level.dart';

/// สถานีวัดระดับน้ำของจังหวัดยะลา ที่แปลงมาจาก ThaiWater API v3
///
/// JSON ที่ได้จาก:
/// https://api-v3.thaiwater.net/api/v1/thaiwater30/public/waterlevel?province_code=95
/// มีโครงแบบเช่น
/// {
///   "waterlevel_msl": "13.00",
///   "waterlevel_msl_previous": "13.00",
///   "situation_level": 4,
///   "station": {"tele_station_oldcode": "PAT002", "tele_station_name": {"th": "เมืองยะลา"},
///               "tele_station_lat": 6.67525, "tele_station_long": 101.286354,
///               "left_bank": 13.85, "right_bank": 13.85, "ground_level": 1.74},
///   "geocode": {"amphoe_name": {"th": "เมืองยะลา"}, "tumbon_name": {"th": "ตาเซะ"}}
/// }
/// ค่าบางค่าเป็น null ได้ (เช่น situation_level ของสถานีที่ไม่ได้ตั้งเกณฑ์)
/// จุดข้อมูลระดับน้ำย้อนหลัง (1 จุดจาก ThaiWater waterlevel_graph หรือ Snapshot 7 วัน)
class WaterLevelPoint {
  const WaterLevelPoint({
    required this.timestamp,
    required this.valueMsl,
    this.discharge,
  });

  /// เวลาประเทศไทย (UTC+7) เช่น `2026-11-26 23:40`
  final String timestamp;
  final double valueMsl;
  final double? discharge;

  DateTime? get dateTime => DateTime.tryParse(timestamp.replaceFirst(' ', 'T'));

  Map<String, dynamic> toJson() => {
        't': timestamp,
        'v': valueMsl,
        if (discharge != null) 'q': discharge,
      };

  factory WaterLevelPoint.fromJson(Map<String, dynamic> json) => WaterLevelPoint(
        timestamp: _asStr(json['t'] ?? json['datetime']),
        valueMsl: _asDouble(json['v'] ?? json['value']) ?? 0.0,
        discharge: _asDouble(json['q'] ?? json['discharge']),
      );
}

class Station {
  const Station({
    required this.id,
    this.stationId,
    required this.code,
    required this.nameTh,
    this.nameEn = '',
    this.lat,
    this.lng,
    this.waterLevelMsl,
    this.waterLevelMslPrev,
    this.waterLevelM,
    this.leftBank,
    this.rightBank,
    this.minBank,
    this.groundLevel,
    this.situationLevel,
    this.storagePercent,
    this.diffWlBank,
    this.diffWlBankText,
    this.amphoeTh,
    this.tumbonTh,
    this.agencyShortTh,
    this.basinNameTh,
    this.riverName,
    this.datetime,
    this.stationType = 'tele_waterlevel',
    this.updateIntervalMinutes,
  });

  final int id;

  /// รหัสสถานีใน ThaiWater (`station.id`) ใช้สำหรับดึงกราฟย้อนหลัง 7 วัน (`waterlevel_graph`)
  final int? stationId;

  /// รหัสสถานี เช่น PAT002, BLGTD03
  final String code;

  /// ชื่อสถานีภาษาไทย
  final String nameTh;
  final String nameEn;

  /// พิกัด
  final double? lat;
  final double? lng;

  /// ระดับน้ำ (ม.ระดับน้ำทะเลปานกลาง) — ค่าล่าสุด
  final double? waterLevelMsl;

  /// ระดับน้ำก่อนหน้า (จาก API) ใช้ทำกราฟจำลอง
  final double? waterLevelMslPrev;

  /// ระดับน้ำ (ม.รากฐาน) ของบางสถานี
  final double? waterLevelM;

  /// ระดับตลิ่งซ้าย/ขวา/ต่ำสุด (ม. MSL)
  final double? leftBank;
  final double? rightBank;
  final double? minBank;

  /// ระดับพื้นดิน (ม. MSL) ใช้คำนวณ % ความจุ
  final double? groundLevel;

  /// ระดับสถานการณ์ 1-5 จาก สสน. (1=น้อยวิกฤต, 2=น้อย, 3=ปกติ, 4=มาก, 5=ล้นตลิ่ง; อาจเป็น null)
  final int? situationLevel;

  /// % ความจุ (เขื่อน) — สถานีระดับน้ำธรรมดามักเป็น null
  final double? storagePercent;

  /// ระดับน้ำต่ำ/สูงกว่าตลิ่งกี่เมตร (ค่าลบ = ล้นตลิ่ง)
  final double? diffWlBank;

  /// คำอธิบายจากกระทรวง เช่น "ต่ำกว่าตลิ่ง (ม.)"
  final String? diffWlBankText;

  final String? amphoeTh;
  final String? tumbonTh;
  final String? agencyShortTh;
  final String? basinNameTh;
  final String? riverName;

  /// วันเวลาที่ข้อมูลถูกอัปเดตตามรูปแบบของกระทรวง (เช่น 2026-11-23 20:10)
  final String? datetime;

  final String stationType;

  /// ความถี่อัปเดตเซ็นเซอร์ของหน่วยงาน (นาที): สสน./พพภ ทุก 10 นาที, กฟผ./ชป. ทุก 60 นาที
  final int? updateIntervalMinutes;

  int get effectiveUpdateIntervalMinutes {
    if (updateIntervalMinutes != null && updateIntervalMinutes! > 0) {
      return updateIntervalMinutes!;
    }
    return inferUpdateIntervalMinutes(agencyShortTh);
  }

  static int inferUpdateIntervalMinutes(String? agencyShort) {
    final ag = (agencyShort ?? '').trim();
    if (ag == 'สสน.' || ag == 'พพภ' || ag == 'พพภ.') return 10;
    return 60;
  }

  /// แปลง JSON หนึ่ง record จาก ThaiWater เป็น [Station]
  factory Station.fromThaiWaterJson(Map<String, dynamic> json) {
    final station = _asMap(json['station']);
    final geocode = _asMap(json['geocode']);
    final agency = _asMap(json['agency']);
    final basin = _asMap(json['basin']);
    final agencyShort = _asStr(_asMap(agency['agency_shortname'])['th']);

    return Station(
      id: _asInt(json['id']) ?? 0,
      stationId: _asInt(station['id']),
      code: _asStr(station['tele_station_oldcode']),
      nameTh: _asStr(_asMap(station['tele_station_name'])['th']),
      nameEn: _asStr(_asMap(station['tele_station_name'])['en']),
      lat: _asDouble(station['tele_station_lat']),
      lng: _asDouble(station['tele_station_long']),
      waterLevelMsl: _asDouble(json['waterlevel_msl']),
      waterLevelMslPrev: _asDouble(json['waterlevel_msl_previous']),
      waterLevelM: _asDouble(json['waterlevel_m']),
      leftBank: _asDouble(station['left_bank']),
      rightBank: _asDouble(station['right_bank']),
      minBank: _asDouble(station['min_bank']),
      groundLevel: _asDouble(station['ground_level']),
      situationLevel: _asInt(json['situation_level']),
      storagePercent: _asDouble(json['storage_percent']),
      diffWlBank: _asDouble(json['diff_wl_bank']),
      diffWlBankText: _asStr(json['diff_wl_bank_text']),
      amphoeTh: _asStr(_asMap(geocode['amphoe_name'])['th']),
      tumbonTh: _asStr(_asMap(geocode['tumbon_name'])['th']),
      agencyShortTh: agencyShort,
      basinNameTh: _asStr(_asMap(basin['basin_name'])['th']),
      riverName: _asStr(json['river_name']),
      datetime: _asStr(json['waterlevel_datetime']),
      stationType: _asStr(json['station_type']).isEmpty
          ? 'tele_waterlevel'
          : _asStr(json['station_type']),
      updateIntervalMinutes: inferUpdateIntervalMinutes(agencyShort),
    );
  }

  /// เกณฑ์วิกฤต/เส้นตลิ่งอ้างอิง (คืน null หากฐานตลิ่งยังไม่ยืนยัน เช่น FOP045 เพื่อป้องกันแสดงค่าหลอกบน UI)
  double? get criticalLevel {
    if (isDatumUnverified) return null;
    final configured = AppConfig.stationCriticalMsl[code];
    if (configured != null && configured > 0) return configured;
    return bankLevel;
  }

  /// เส้นเฝ้าระวังอ้างอิงรายสถานี (watch_m จาก stations.yaml / AppConfig หรือ crit - 1.5 ม.)
  double? get watchLevel {
    if (isDatumUnverified) return null;
    final crit = criticalLevel;
    if (crit == null || crit <= 0) return null;
    final configured = AppConfig.stationWatchMsl[code];
    if (configured != null && configured > 0 && configured < crit) {
      return configured;
    }
    return crit - 1.5;
  }

  /// เส้นความเฉลี่ยกึ่งกลางระหว่างเส้นเฝ้าระวังและเส้นตลิ่ง (mid = (watch + crit) / 2)
  double? get midLevel {
    final w = watchLevel;
    final c = criticalLevel;
    if (w == null || c == null) return null;
    return (w + c) / 2.0;
  }

  /// เส้นเตือนภัยสูง (เหนือเส้นกึ่งกลางเกือบถึงเส้นตลิ่ง: 75% ของช่วง watch → crit)
  double? get highLevel {
    final m = midLevel;
    final c = criticalLevel;
    if (m == null || c == null) return null;
    return (m + c) / 2.0;
  }

  /// สถานีที่ฐานค่าระดับตลิ่งยังไม่ยืนยัน (เช่น FOP045 กรงปินัง) — ไม่ใช้ bank - level กดเตือนภัย
  bool get isDatumUnverified => AppConfig.unverifiedDatumStations.contains(code);

  /// ระดับความเสี่ยงหลักตามเกณฑ์น้ำ 5 ขั้น (`formula_version = 5`):
  /// 1 ปกติ (< watch) · 2 เฝ้าระวัง (watch..mid) · 3 เตือนภัย (mid..high หรือขึ้นเร็ว/คาดล้น <=24 ชม.)
  /// 4 เตือนภัยสูง (high..bank เกือบถึงตลิ่ง หรือคาดล้น <=6 ชม.) · 5 อันตราย (>= bank / sit==5)
  RiskLevel get riskLevel {
    // ThaiWater situation_level == 5 ยืนยันล้นตลิ่ง (>100%) เสมอ
    if (situationLevel != null && situationLevel! >= 5) {
      return RiskLevel.danger;
    }

    final dH = (waterLevelMsl != null && waterLevelMslPrev != null)
        ? ((waterLevelMsl! - waterLevelMslPrev!) * 10000).round() / 10000.0
        : 0.0;

    // กรณีสถานีฐานตลิ่งยังไม่ยืนยัน (FOP045): ประเมินจาก dH/dt และ situation_level แทน bank-level
    if (isDatumUnverified) {
      if (waterLevelMsl != null && dH >= AppConfig.risingFastMetersPerHour) {
        return RiskLevel.warning;
      }
      if (waterLevelMsl != null && dH >= 0.15) {
        return RiskLevel.watch;
      }
      final sitLevel = RiskLevel.fromSituation(situationLevel);
      return sitLevel != RiskLevel.unknown ? sitLevel : RiskLevel.normal;
    }

    final crit = criticalLevel;
    final watch = watchLevel;
    final mid = midLevel;
    final high = highLevel;
    final wl = displayLevel;

    if (crit != null && watch != null && mid != null && high != null && wl != null) {
      final double? timeToBankH = (wl < crit && dH >= 0.05)
          ? (((crit - wl) / dH) * 100.0).round() / 100.0
          : null;
      if (wl >= crit) return RiskLevel.danger;
      if (wl >= high) return RiskLevel.high;
      if (wl >= mid) {
        return (dH >= AppConfig.risingFastMetersPerHour ||
                (timeToBankH != null && timeToBankH <= 6.0))
            ? RiskLevel.high
            : RiskLevel.warning;
      }
      if (wl >= watch) {
        if (timeToBankH != null && timeToBankH <= 6.0) return RiskLevel.high;
        if (dH >= 0.15 || (timeToBankH != null && timeToBankH <= 24.0)) {
          return RiskLevel.warning;
        }
        return RiskLevel.watch;
      }
      return RiskLevel.normal;
    }

    // กรณีสถานีไม่มีเกณฑ์ตลิ่ง (เช่น เขื่อนบางลาง/ฝายละแอ) ใช้ ThaiWater situation_level ที่แก้สเกลแล้ว
    final sitLevel = RiskLevel.fromSituation(situationLevel);
    if (sitLevel != RiskLevel.unknown) return sitLevel;

    final diff = diffWlBank;
    if (diff != null && diff < 0 && (bankLevel ?? 0) > 0) return RiskLevel.danger;
    return RiskLevel.unknown;
  }

  /// ตลิ่งอ้างอิง: ซ้าย → ขวา → ต่ำสุด (ข้ามค่า <= 0 ให้ตรงกับ backend/pipeline.py)
  double? get bankLevel {
    for (final candidate in [leftBank, rightBank, minBank]) {
      if (candidate != null && candidate > 0) return candidate;
    }
    return null;
  }

  /// ตลิ่งที่ใช้ได้จริง (มากกว่า 0 และยืนยันฐานระดับแล้ว)
  bool get hasBank => !isDatumUnverified && (bankLevel ?? 0) > 0;

  /// ระยะจากระดับน้ำถึงตลิ่ง (ม.) — ค่าลบแปลว่าล้นตลิ่งแล้ว (คืน null หากฐานตลิ่งยังไม่ยืนยัน)
  double? get remainingToBank {
    if (isDatumUnverified) return null;
    final bank = bankLevel;
    final wl = waterLevelMsl;
    if (bank == null || wl == null) return null;
    return bank - wl;
  }

  /// ระดับน้ำที่ใช้แสดง เรียงความสำคัญ MSL ก่อน
  double? get displayLevel => waterLevelMsl ?? waterLevelM;

  /// ทิศทางการเปลี่ยนแปลงของระดับน้ำ (ใช้เกณฑ์ steadyBandMeters = 0.05 ม. ตรงกับ formula_version = 5)
  WaterTrend get trend {
    final cur = waterLevelMsl;
    final prev = waterLevelMslPrev;
    if (cur == null || prev == null) return WaterTrend.unknown;
    final diff = ((cur - prev) * 10000).round() / 10000.0;
    if (diff.abs() <= AppConfig.steadyBandMeters) return WaterTrend.steady;
    return diff > 0 ? WaterTrend.rising : WaterTrend.falling;
  }

  /// ความชันโดยประมาณ (ม./ชม.) จาก prev ที่ API ให้มา
  /// สมมติว่าช่วงเวลาระหว่างการอัปเดตคือ 1 ชม. (ThaiWater รายงานทุก ~10 นาที ถึง 1 ชม.)
  double? get trendMetersPerHour {
    final cur = waterLevelMsl;
    final prev = waterLevelMslPrev;
    if (cur == null || prev == null) return null;
    return cur - prev;
  }

  /// จุดที่พอไปใช้กับแผนที่ได้
  bool get hasCoordinate => lat != null && lng != null;

  /// ข้อความสถานที่แบบสั้น ๆ
  String get locationLabel {
    final parts = <String>[
      if ((amphoeTh ?? '').isNotEmpty) 'อ.$amphoeTh',
      if ((tumbonTh ?? '').isNotEmpty) 'ต.$tumbonTh',
    ];
    return parts.isEmpty ? 'จ.ยะลา' : parts.join(' ');
  }

  /// แปลงกลับเป็น JSON เพื่อเก็บแคช
  Map<String, dynamic> toJson() => {
        'id': id,
        'stationId': stationId,
        'code': code,
        'nameTh': nameTh,
        'nameEn': nameEn,
        'lat': lat,
        'lng': lng,
        'waterLevelMsl': waterLevelMsl,
        'waterLevelMslPrev': waterLevelMslPrev,
        'waterLevelM': waterLevelM,
        'leftBank': leftBank,
        'rightBank': rightBank,
        'minBank': minBank,
        'groundLevel': groundLevel,
        'situationLevel': situationLevel,
        'storagePercent': storagePercent,
        'diffWlBank': diffWlBank,
        'diffWlBankText': diffWlBankText,
        'amphoeTh': amphoeTh,
        'tumbonTh': tumbonTh,
        'agencyShortTh': agencyShortTh,
        'basinNameTh': basinNameTh,
        'riverName': riverName,
        'datetime': datetime,
        'stationType': stationType,
        'updateIntervalMinutes': updateIntervalMinutes,
      };

  factory Station.fromJson(Map<String, dynamic> json) => Station(
        id: _asInt(json['id']) ?? 0,
        stationId: _asInt(json['stationId']),
        code: _asStr(json['code']),
        nameTh: _asStr(json['nameTh']),
        nameEn: _asStr(json['nameEn']),
        lat: _asDouble(json['lat']),
        lng: _asDouble(json['lng']),
        waterLevelMsl: _asDouble(json['waterLevelMsl']),
        waterLevelMslPrev: _asDouble(json['waterLevelMslPrev']),
        waterLevelM: _asDouble(json['waterLevelM']),
        leftBank: _asDouble(json['leftBank']),
        rightBank: _asDouble(json['rightBank']),
        minBank: _asDouble(json['minBank']),
        groundLevel: _asDouble(json['groundLevel']),
        situationLevel: _asInt(json['situationLevel']),
        storagePercent: _asDouble(json['storagePercent']),
        diffWlBank: _asDouble(json['diffWlBank']),
        diffWlBankText: _asStr(json['diffWlBankText']),
        amphoeTh: _asStr(json['amphoeTh']),
        tumbonTh: _asStr(json['tumbonTh']),
        agencyShortTh: _asStr(json['agencyShortTh']),
        basinNameTh: _asStr(json['basinNameTh']),
        riverName: _asStr(json['riverName']),
        datetime: _asStr(json['datetime']),
        stationType: _asStr(json['stationType']).isEmpty
            ? 'tele_waterlevel'
            : _asStr(json['stationType']),
        updateIntervalMinutes: _asInt(json['updateIntervalMinutes']),
      );

  Station copyWith({
    double? waterLevelMsl,
    double? waterLevelMslPrev,
    int? situationLevel,
    String? datetime,
  }) =>
      Station(
        id: id,
        stationId: stationId,
        code: code,
        nameTh: nameTh,
        nameEn: nameEn,
        lat: lat,
        lng: lng,
        waterLevelMsl: waterLevelMsl ?? this.waterLevelMsl,
        waterLevelMslPrev: waterLevelMslPrev ?? this.waterLevelMslPrev,
        waterLevelM: waterLevelM,
        leftBank: leftBank,
        rightBank: rightBank,
        minBank: minBank,
        groundLevel: groundLevel,
        situationLevel: situationLevel ?? this.situationLevel,
        storagePercent: storagePercent,
        diffWlBank: diffWlBank,
        diffWlBankText: diffWlBankText,
        amphoeTh: amphoeTh,
        tumbonTh: tumbonTh,
        agencyShortTh: agencyShortTh,
        basinNameTh: basinNameTh,
        riverName: riverName,
        datetime: datetime ?? this.datetime,
        stationType: stationType,
        updateIntervalMinutes: updateIntervalMinutes,
      );

  @override
  String toString() => 'Station($code, $nameTh, ${waterLevelMsl ?? '-'} ม.)';
}

/// ทิศทางระดับน้ำ
enum WaterTrend {
  rising('กำลังขึ้น', Icons.trending_up, Color(0xFFC62828)),
  falling('กำลังลง', Icons.trending_down, Color(0xFF2E7D32)),
  steady('คงที่', Icons.trending_flat, Color(0xFF616161)),
  unknown('ไม่ทราบ', Icons.remove, Color(0xFF9E9E9E));

  const WaterTrend(this.labelTh, this.icon, this.color);

  final String labelTh;
  final IconData icon;
  final Color color;

  Color colorFor(Brightness brightness) {
    if (brightness == Brightness.light) return color;
    return switch (this) {
      WaterTrend.rising => const Color(0xFFFF6B6B),
      WaterTrend.falling => const Color(0xFF66BB6A),
      WaterTrend.steady => const Color(0xFFCBD5E1),
      WaterTrend.unknown => const Color(0xFF94A3B8),
    };
  }
}

// ── ตัวช่วยแปลงค่าจาก JSON (รองรับทั้ง String และ num, และ null) ──────────
Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _asStr(dynamic value) {
  if (value == null) return '';
  if (value is String) return value.trim();
  return value.toString();
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString());
}

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    final d = value.toDouble();
    return d.isFinite ? d : null;
  }
  final parsed = double.tryParse(value.toString());
  return (parsed != null && parsed.isFinite) ? parsed : null;
}
