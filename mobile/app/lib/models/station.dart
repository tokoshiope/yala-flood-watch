import 'package:material_ui/material_ui.dart';

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
class Station {
  const Station({
    required this.id,
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
  });

  final int id;

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

  /// ระดับสถานการณ์ 1-4 จากกระทรวง/สสน. (อาจเป็น null)
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

  /// แปลง JSON หนึ่ง record จาก ThaiWater เป็น [Station]
  factory Station.fromThaiWaterJson(Map<String, dynamic> json) {
    final station = _asMap(json['station']);
    final geocode = _asMap(json['geocode']);
    final agency = _asMap(json['agency']);
    final basin = _asMap(json['basin']);

    return Station(
      id: _asInt(json['id']) ?? 0,
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
      agencyShortTh: _asStr(_asMap(agency['agency_shortname'])['th']),
      basinNameTh: _asStr(_asMap(basin['basin_name'])['th']),
      riverName: _asStr(json['river_name']),
      datetime: _asStr(json['waterlevel_datetime']),
      stationType: _asStr(json['station_type']).isEmpty
          ? 'tele_waterlevel'
          : _asStr(json['station_type']),
    );
  }

  /// ระดับความเสี่ยงหลัก จาก situation_level ของกระทรวง
  RiskLevel get riskLevel {
    final level = RiskLevel.fromSituation(situationLevel);

    // กรณีสถานีไม่ได้ตั้ง situation_level ให้ประเมินจากระดับน้ำเทียบตลิ่ง
    // เฉพาะเมื่อมีตลิ่งจริง (มากกว่า 0) — สถานีอย่างเขื่อนที่ไม่มีตลิ่งจะไม่ถูกตีความผิด
    if (level == RiskLevel.unknown) {
      final bank = bankLevel;
      final wl = waterLevelMsl;
      final diff = diffWlBank;
      if (bank != null && bank > 0 && wl != null) {
        if (wl >= bank) return RiskLevel.danger;
        final remaining = bank - wl;
        if (remaining <= 0.5) return RiskLevel.warning;
        if (remaining <= 2.0) return RiskLevel.watch;
        return RiskLevel.normal;
      }
      // มี diff_wl_bank แต่ไม่มีตลิ่ง (เช่น เขื่อน) — ใช้ค่าลบระบุว่าล้น
      if (diff != null && diff < 0 && (bank ?? 0) > 0) return RiskLevel.danger;
    }
    return level;
  }

  /// ตลิ่งอ้างอิง: ซ้าย → ขวา → ต่ำสุด (ข้ามค่า <= 0 ให้ตรงกับ backend/pipeline.py)
  double? get bankLevel {
    for (final candidate in [leftBank, rightBank, minBank]) {
      if (candidate != null && candidate > 0) return candidate;
    }
    return null;
  }

  /// ตลิ่งที่ใช้ได้จริง (มากกว่า 0)
  bool get hasBank => (bankLevel ?? 0) > 0;

  /// ระยะจากระดับน้ำถึงตลิ่ง (ม.) — ค่าลบแปลว่าล้นตลิ่งแล้ว
  double? get remainingToBank {
    final bank = bankLevel;
    final wl = waterLevelMsl;
    if (bank == null || wl == null) return null;
    return bank - wl;
  }

  /// สัดส่วนความจุจาก ground ถึงตลิ่ง 0.0 - 1.0 (null ถ้าประเมินไม่ได้)
  double? get fillRatio {
    final ground = groundLevel;
    final bank = bankLevel;
    final wl = waterLevelMsl;
    if (ground == null || bank == null || wl == null) return null;
    final span = bank - ground;
    if (span <= 0) return null;
    final ratio = (wl - ground) / span;
    if (ratio < 0) return 0;
    if (ratio > 1) return 1;
    return ratio;
  }

  /// ระดับน้ำที่ใช้แสดง เรียงความสำคัญ MSL ก่อน
  double? get displayLevel => waterLevelMsl ?? waterLevelM;

  /// ทิศทางการเปลี่ยนแปลงของระดับน้ำ
  WaterTrend get trend {
    final cur = waterLevelMsl;
    final prev = waterLevelMslPrev;
    if (cur == null || prev == null) return WaterTrend.unknown;
    final diff = cur - prev;
    if (diff.abs() < 0.05) return WaterTrend.steady;
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
      };

  factory Station.fromJson(Map<String, dynamic> json) => Station(
        id: _asInt(json['id']) ?? 0,
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
      );

  Station copyWith({
    double? waterLevelMsl,
    double? waterLevelMslPrev,
    int? situationLevel,
    String? datetime,
  }) =>
      Station(
        id: id,
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
