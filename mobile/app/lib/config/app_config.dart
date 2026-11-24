// ค่าคงที่ทั้งหมดของแอพ "น้ำท่วมยะลา" (Yala Flood Watch)
// เฉพาะ จ.ยะลา (รหัส 95) · formula_version = 2 · Google Maps Foundation + 4 Languages
library;

class AppConfig {
  AppConfig._();

  // ── แอพ ────────────────────────────────────────────────────────────────
  static const String appName = 'น้ำท่วมยะลา';
  static const String appNameEn = 'Yala Flood Watch';
  static const String packageName = 'net.yala.floodapp';
  static const String appVersion = '0.3.0';
  static const int formulaVersion = 2;

  // ── จังหวัดยะลา ────────────────────────────────────────────────────────
  static const String provinceCode = '95';
  static const String provinceNameTh = 'ยะลา';
  static const String provinceNameEn = 'Yala';
  static const String provinceNameYawi = 'يلا';

  static const double defaultLat = 6.24;
  static const double defaultLng = 101.22;
  static const double defaultZoom = 9.0;

  // ── Phase 2 Cloud CDN Snapshot Bridge + 5 แหล่งข้อมูลจริง ────────────────
  /// กำหนดค่าผ่าน `--dart-define=YALA_SNAPSHOT_CDN_BASE=https://<project>.supabase.co/storage/v1/object/public/snapshots`
  static const String snapshotCdnBaseUrl = String.fromEnvironment(
    'YALA_SNAPSHOT_CDN_BASE',
    defaultValue: '',
  );

  static String get snapshotLatestUrl =>
      snapshotCdnBaseUrl.isEmpty ? '' : '$snapshotCdnBaseUrl/latest.json';

  static const String thaiWaterBaseUrl =
      'https://api-v3.thaiwater.net/api/v1/thaiwater30/public';
  static const String thaiWaterWaterLevelPath = '/waterlevel';
  static const String thaiWaterRain24hPath = '/rain_24h';
  static const String thaiWaterAnalystDamUrl =
      'https://api-v3.thaiwater.net/api/v1/thaiwater30/analyst/dam';
  static const String openMeteoForecastUrl =
      'https://api.open-meteo.com/v1/forecast';
  static const String openMeteoFloodUrl =
      'https://flood-api.open-meteo.com/v1/flood';

  static String get waterLevelUrl =>
      '$thaiWaterBaseUrl$thaiWaterWaterLevelPath?province_code=$provinceCode';

  static String get rain24hUrl =>
      '$thaiWaterBaseUrl$thaiWaterRain24hPath?province_code=$provinceCode';

  static const String bundledSnapshotAsset = 'assets/snapshots/latest.json';
  static const String bundledGeoJsonAsset = 'assets/geo/yala_amphoes.geojson';

  static const int yalaDataSetHash = 95;

  // ── เครือข่าย & แคช ────────────────────────────────────────────────────
  static const Duration networkTimeout = Duration(seconds: 12);
  static const int maxRetries = 2;
  static const Duration retryDelay = Duration(milliseconds: 900);

  static const String cacheStationsKey = 'yala_flood_stations_v1';
  static const String cacheUpdatedAtKey = 'yala_flood_updated_at_v1';
  static const String cacheSnapshotKey = 'yala_flood_snapshot_v2';
  static const Duration cacheTtl = Duration(minutes: 30);

  // ── เกณฑ์แจ้งเตือน (formula_version = 2) ───────────────────────────────
  static const int defaultWarningLevel = 3;
  static const int defaultDangerLevel = 4;
  static const int maxSituationLevel = 4;
  static const int rainScoreWarn = 60;
  static const int rainScoreDanger = 85;
  static const double steadyBandMeters = 0.05;
  static const double risingFastMetersPerHour = 0.30;
  static const Duration hysteresisWindow = Duration(hours: 2);
  static const Duration alertCooldownWindow = Duration(minutes: 30);

  static const Set<String> flashFloodAmphoes = {
    'บันนังสตา',
    'กรงปินัง',
    'เบตง',
    'กาบัง',
    'ธารโต',
  };

  static const Map<String, String> bangLangDownstreamLeadTime = {
    'บันนังสตา': '2–4 ชม.',
    'กรงปินัง': '4–6 ชม.',
    'เมืองยะลา': '6–12 ชม.',
  };

  // ── ธีมสี ──────────────────────────────────────────────────────────────
  static const int colorPrimary = 0xFF0E5FA6;
  static const int colorSafe = 0xFF2E7D32;
  static const int colorWatch = 0xFFF9A825;
  static const int colorWarning = 0xFFEF6C00;
  static const int colorHigh = 0xFFE53935;
  static const int colorDanger = 0xFFB71C1C;
  static const int colorUnknown = 0xFF616161;

  // ── การแจ้งเตือน / ผังข้อมูลฝั่งผู้ใช้ ──────────────────────────────────
  static const String alertsPrefsKey = 'yala_flood_alerts_v1';
  static const String settingsPrefsKey = 'yala_flood_settings_v1';
  static const String sosLogPrefsKey = 'yala_flood_sos_log_v1';
  static const String gpsConsentPrefsKey = 'yala_flood_gps_consent_v1';
  static const int maxStoredAlerts = 100;
  static const int maxStoredSosRequests = 50;

  // ── Deep link ──────────────────────────────────────────────────────────
  static const String deepLinkScheme = 'yalaflood';
  static const String deepLinkHostStation = 'station';
  static const String deepLinkHostAlerts = 'alerts';
  static const String deepLinkHostSos = 'sos';
  static const String deepLinkHostShelters = 'shelters';
  static const String deepLinkHostSettings = 'settings';

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

  // ── เบอร์ฉุกเฉินที่ตรวจสอบยืนยันแล้ว (DEC-013 Zero-Hallucination Rule) ────
  static const String emergencyDDPM = '1784';
  static const String emergencyYalaCenter = '073203559';
  static const String emergencyYalaCenterDisplay = '073-203559';
  static const String emergencyYalaCenterLabel = 'สำนักงาน ปภ. จังหวัดยะลา';
  static const String emergencyYalaMunicipality = '073212345';
  static const String emergencyYalaMunicipalityDisplay = '073-212345';
  static const String emergencyMedical = '1669';
  static const String emergencyDisaster = '199';
  static const String emergencyPolice = '191';
  static const String emergencyVolunteer = '1677';

  static const String lifeSafetyDisclaimerTh =
      'แอปนี้เป็นเครื่องมือเฝ้าระวังและแจ้งเตือนล่วงหน้าอิสระ ไม่ใช่ช่องทางกู้ภัยหลักของทางราชการ '
      'หากประสบเหตุวิกฤตกรุณาโทร 1784 (ปภ.), 073-203559 (ปภ.ยะลา) หรือ 1669 ทันที';

  static const String rainForecastEndpoint = '';

  // ── Google Maps (Primary Map Foundation — DEC-014) ──────────────────────
  /// Google Maps Road Tiles (รองรับ hl ตามภาษาที่เลือก: th / en / zh-CN / ms)
  static String googleMapsTileUrl(String langCode) {
    final hl = langCode == 'zh' ? 'zh-CN' : langCode;
    return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}&hl=$hl';
  }

  static const String googleMapsAttribution = 'Map data © Google · Yala 8 Districts';

  /// Google Maps Turn-by-Turn Navigation URL (Free Unlimited SKU)
  static String googleMapsDirectionsUrl(double lat, double lng) =>
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';

  /// คงไว้เพื่อความเข้ากันย้อนหลัง
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmAttribution = '© OpenStreetMap contributors';
  static const String googleMapsUrl = 'https://www.google.com/maps/dir/?api=1&destination=';
}
