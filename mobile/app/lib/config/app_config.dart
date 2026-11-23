// ค่าคงที่ทั้งหมดของแอพ "น้ำท่วมยะลา" อยู่ที่นี่
// เปลี่ยนค่าได้ในไฟล์เดียว ไม่กระจายในโค้ด
// หมายเหตุ: ไม่มีการ hardcode ข้อมูลรัฐบาลอื่น — ที่นี่มีเฉพาะ จ.ยะลา (รหัส 95)
library;

class AppConfig {
  AppConfig._();

  // ── แอพ ────────────────────────────────────────────────────────────────
  static const String appName = 'น้ำท่วมยะลา';
  static const String appNameEn = 'Yala Flood';
  static const String packageName = 'net.yala.floodapp';
  static const String appVersion = '0.1.0';

  // ── จังหวัดยะลา ────────────────────────────────────────────────────────
  static const String provinceCode = '95';
  static const String provinceNameTh = 'ยะลา';
  static const String provinceNameEn = 'Yala';
  static const String provinceNameYawi = 'يلا';

  // พิกัดกึ่งกลางจังหวัดยะลา (สำหรับเริ่มการแสดงแผนที่)
  static const double defaultLat = 6.5413;
  static const double defaultLng = 101.2803;
  static const double defaultZoom = 9.5;

  // ── ThaiWater API ──────────────────────────────────────────────────────
  // แหล่งข้อมูล: สถาบันสารสนเทศทรัพยากรน้ำ (HII) — ThaiWater API v3
  // ตัวอย่าง: https://api-v3.thaiwater.net/api/v1/thaiwater30/public/waterlevel?province_code=95
  static const String thaiWaterBaseUrl =
      'https://api-v3.thaiwater.net/api/v1/thaiwater30/public';
  static const String thaiWaterWaterLevelPath = '/waterlevel';

  /// URL เรียกระดับน้ำจริงของจ.ยะลา (รหัส 95)
  static String get waterLevelUrl =>
      '$thaiWaterBaseUrl$thaiWaterWaterLevelPath?province_code=$provinceCode';

  /// ตัวเลขคงที่สำหรับชุดข้อมูลยะลา (ใช้ตรวจว่าข้อมูลที่ cache ยังเป็นของยะลา)
  static const int yalaDataSetHash = 95;

  // ── เครือข่าย ──────────────────────────────────────────────────────────
  static const Duration networkTimeout = Duration(seconds: 12);
  static const int maxRetries = 2;
  static const Duration retryDelay = Duration(milliseconds: 900);

  // ── แคช ────────────────────────────────────────────────────────────────
  static const String cacheStationsKey = 'yala_flood_stations_v1';
  static const String cacheUpdatedAtKey = 'yala_flood_updated_at_v1';
  static const Duration cacheTtl = Duration(minutes: 30);

  // ── เกณฑ์แจ้งเตือน (situation_level จาก ThaiWater) ───────────────────
  // 1 = ปกติ, 2 = เฝ้าระวัง, 3 = เตือนภัย, 4 = อันตราย
  static const int defaultWarningLevel = 3;
  static const int defaultDangerLevel = 4;
  static const int maxSituationLevel = 4;

  /// คะแนนฝน (0-100) ที่ถึงเกณฑ์เพิ่มระดับความรุนแรง
  static const int rainScoreWarn = 60;
  static const int rainScoreDanger = 85;

  /// ระยะเวลาที่ระดับน้ำคงที่ถือว่า "นิ่ง" (ม. MSL)
  static const double steadyBandMeters = 0.05;

  /// ระดับน้ำขึ้น/ลงมากกว่ากี่ครั้งใน 1 ชม. ถึงถือว่า "ลึก"
  static const double risingFastMetersPerHour = 0.30;

  // ── ธีมสี ──────────────────────────────────────────────────────────────
  static const int colorPrimary = 0xFF0E5FA6;
  static const int colorSafe = 0xFF2E7D32;
  static const int colorWatch = 0xFFF9A825;
  static const int colorWarning = 0xFFEF6C00;
  static const int colorDanger = 0xFFC62828;
  static const int colorUnknown = 0xFF616161;

  // ── การแจ้งเตือน / ผังข้อมูลฝั่งผู้ใช้ ──────────────────────────────────
  static const String alertsPrefsKey = 'yala_flood_alerts_v1';
  static const String settingsPrefsKey = 'yala_flood_settings_v1';
  static const String sosLogPrefsKey = 'yala_flood_sos_log_v1';
  static const int maxStoredAlerts = 100;
  static const int maxStoredSosRequests = 50;

  // ── Deep link ──────────────────────────────────────────────────────────
  /// รูปแบบ: yalaflood://station/PAT002, yalaflood://alerts, yalaflood://sos
  static const String deepLinkScheme = 'yalaflood';
  static const String deepLinkHostStation = 'station';
  static const String deepLinkHostAlerts = 'alerts';
  static const String deepLinkHostSos = 'sos';
  static const String deepLinkHostShelters = 'shelters';
  static const String deepLinkHostSettings = 'settings';

  // ── หมู่บ้าน/อำเภอที่เสี่ยง (ใช้กรองการแจ้งเตือน) ──────────────────────────
  static const List<String> riskAmphoeTh = [
    'เมืองยะลา',
    'รามัน',
    'ยะหา',
    'กรงปินัง',
    'เบตง',
    'บันนังสตา',
    'ธารโต',
    'กาบัง',
  ];

  // ── เบอร์ฉุกเฉิน ───────────────────────────────────────────────────────
  static const String emergencyDDPM = '1677'; // กรมป้องกันและบรรเทาสาธารณภัย
  static const String emergencyDisaster = '199'; // หน่วยงานภัยพิบัติ
  /// ศูนย์ป้องกันและบรรเทาสาธารณภัยจังหวัดยะลา
  /// หมายเหตุ: ใส่เบอร์จริงของศูนย์ปภ.ยะลาที่นี่เมื่อได้รับการยืนยัน
  /// ตอนนี้ใช้ 1677 เป็นค่าเริ่มต้นเพื่อให้ปุ่มโทรใช้งานได้ทันที
  static const String emergencyYalaCenter = '1677';
  static const String emergencyYalaCenterLabel = 'ศูนย์ปภ.ยะลา';

  // ── แหล่งข้อมูลฝน (เตรียมไว้สำหรับอนาคต) ─────────────────────────────────
  /// ยังไม่ได้เปิดใช้งาน — เมื่อมี API คะแนนฝนแล้วใส่ endpoint ที่นี่
  static const String rainForecastEndpoint = '';

  // ── OpenStreetMap ──────────────────────────────────────────────────────
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmAttribution = '© OpenStreetMap contributors';
  static const String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=';
}
