// ค่าคงที่ทั้งหมดของแอพ "แจ้งเตือนน้ำท่วมยะลา" (Yala Flood Watch)
// เฉพาะ จ.ยะลา (รหัส 95) · formula_version = 3 · Google Maps Foundation + 4 Languages
library;

class AppConfig {
  AppConfig._();

  // ── แอพ ────────────────────────────────────────────────────────────────
  static const String appName = 'แจ้งเตือนน้ำท่วมยะลา';
  static const String appNameEn = 'Yala Flood Watch';
  static const String packageName = 'net.yala.floodapp';
  static const String appVersion = '1.0.1';
  static const int formulaVersion = 4;

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

  /// กำหนดค่าผ่าน `--dart-define=YALA_SUPABASE_URL=https://<project>.supabase.co`
  /// (หากไม่ระบุ จะดึง origin `https://<project>.supabase.co` จาก YALA_SNAPSHOT_CDN_BASE อัตโนมัติ)
  static const String supabaseUrl = String.fromEnvironment(
    'YALA_SUPABASE_URL',
    defaultValue: '',
  );

  /// Public Supabase anon key สำหรับเรียกเฉพาะ RPC `submit_community_report` (RLS + Rate-Limited) และวิวไม่ระบุตัวตน
  static const String supabaseAnonKey = String.fromEnvironment(
    'YALA_SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// URL ฐานของ Supabase Project (HTTPS เท่านั้น)
  static String get effectiveSupabaseBaseUrl =>
      resolveSupabaseBaseUrl(
        explicitUrl: supabaseUrl,
        snapshotCdnUrl: snapshotCdnBaseUrl,
      );

  static String resolveSupabaseBaseUrl({
    required String explicitUrl,
    required String snapshotCdnUrl,
  }) {
    final direct = explicitUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (direct.isNotEmpty) {
      final parsed = Uri.tryParse(direct);
      if (parsed != null && parsed.scheme == 'https' && parsed.host.isNotEmpty) {
        return '${parsed.scheme}://${parsed.authority}';
      }
      return '';
    }
    final cdn = snapshotCdnUrl.trim();
    if (cdn.isEmpty) return '';
    final parsed = Uri.tryParse(cdn);
    if (parsed != null &&
        parsed.scheme == 'https' &&
        parsed.host.isNotEmpty &&
        parsed.path.contains('/storage/v1/object/public/')) {
      return '${parsed.scheme}://${parsed.authority}';
    }
    return '';
  }

  static String get snapshotLatestUrl =>
      snapshotCdnBaseUrl.isEmpty ? '' : '$snapshotCdnBaseUrl/latest.json';

  static String get snapshotManifestUrl =>
      snapshotCdnBaseUrl.isEmpty ? '' : '$snapshotCdnBaseUrl/manifest.json';

  static const String thaiWaterBaseUrl =
      'https://api-v3.thaiwater.net/api/v1/thaiwater30/public';
  static const String thaiWaterWaterLevelPath = '/waterlevel';
  static const String thaiWaterWaterLevelGraphPath = '/waterlevel_graph';
  static const String thaiWaterRain24hPath = '/rain_24h';
  static const String thaiWaterAnalystDamUrl =
      'https://api-v3.thaiwater.net/api/v1/thaiwater30/analyst/dam';
  static const String openMeteoForecastUrl =
      'https://api.open-meteo.com/v1/forecast';
  static const String openMeteoFloodUrl =
      'https://flood-api.open-meteo.com/v1/flood';

  static String get waterLevelUrl =>
      '$thaiWaterBaseUrl$thaiWaterWaterLevelPath?province_code=$provinceCode';

  static String waterLevelGraphUrl({
    required int stationId,
    required String startDate,
    required String endDate,
    String stationType = 'tele_waterlevel',
  }) =>
      '$thaiWaterBaseUrl$thaiWaterWaterLevelGraphPath'
      '?station_type=$stationType&station_id=$stationId'
      '&start_date=$startDate&end_date=$endDate';

  static String get rain24hUrl =>
      '$thaiWaterBaseUrl$thaiWaterRain24hPath?province_code=$provinceCode';

  static const String bundledSnapshotAsset = 'assets/snapshots/latest.json';
  static const String bundledGeoJsonAsset = 'assets/geo/yala_amphoes.geojson';
  static const String bundledSubdistrictsAsset = 'assets/geo/yala_subdistricts.geojson';
  static const String bundledVillagesAsset = 'assets/geo/yala_villages.json';
  static const String bundledVillageZonesAsset = 'assets/geo/yala_village_zones.geojson';
  static const String bundledElevationZonesAsset = 'assets/geo/yala_elevation_zones.geojson';
  static const String bundledDemGridAsset = 'assets/geo/yala_dem_grid.json';

  static const int yalaDataSetHash = 95;

  // ── เครือข่าย & แคช ────────────────────────────────────────────────────
  static const Duration networkTimeout = Duration(seconds: 12);
  static const int maxRetries = 2;
  static const Duration retryDelay = Duration(milliseconds: 900);

  static const String cacheStationsKey = 'yala_flood_stations_v1';
  static const String cacheUpdatedAtKey = 'yala_flood_updated_at_v1';
  static const String cacheSnapshotKey = 'yala_flood_snapshot_v2';
  static const String cacheStationHistoryPrefix = 'yala_flood_hist7d_v1_';
  static const Duration cacheTtl = Duration(minutes: 10);

  // ── เกณฑ์แจ้งเตือน (formula_version = 4 · ระดับน้ำ 5 ขั้น + เตือนฝน/เขื่อนสูงสุด Lv 3) ──
  static const int defaultWarningLevel = 3;
  static const int defaultDangerLevel = 5;
  static const int maxSituationLevel = 5;
  static const int rainScoreWarn = 60;
  static const int rainScoreDanger = 85;
  static const double steadyBandMeters = 0.05;
  static const double risingFastMetersPerHour = 0.30;
  static const Duration hysteresisWindow = Duration(hours: 3);
  static const Duration alertCooldownWindow = Duration(minutes: 30);

  static const Set<String> flashFloodAmphoes = {
    'บันนังสตา',
    'กรงปินัง',
    'เบตง',
    'กาบัง',
    'ธารโต',
  };

  static const Set<String> urbanBasinAmphoes = {
    'เมืองยะลา',
    'รามัน',
    'ยะหา',
  };

  /// เกณฑ์ระดับเฝ้าระวัง / วิกฤต อ้างอิง สทภ.8 ปี 2568 และ stations.yaml v2
  static const Map<String, double> stationWatchMsl = {
    'X.40A': 15.50,
    'X.77': 38.00,
    'X.273': 15.00,
    'PAT002': 12.35,
    'PAT001': 36.80,
    'BLGTD01': 46.70,
    'BLGTD02': 38.70,
    'BLGTD03': 15.80,
    'BLGTD04': 29.80,
    'BLGTU02': 118.50,
    'MOU454': 284.80,
    'FOP045': 23.20,
  };

  static const Map<String, double> stationCriticalMsl = {
    'X.40A': 16.50,
    'X.77': 39.70,
    'X.273': 16.50,
    'PAT002': 13.85,
    'PAT001': 38.678,
    'BLGTD01': 48.678,
    'BLGTD02': 40.71,
    'BLGTD03': 17.29,
    'BLGTD04': 31.55,
    'BLGTU02': 120.37,
    'MOU454': 286.432,
    'FOP045': 25.128,
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
  static const String subscribedTopicPrefsKey = 'yala_flood_subscribed_topic_v1';
  static const String pinnedLocationPrefsKey = 'yala_flood_pinned_location_v1';
  static const String communityDeviceSaltKey = 'yala_flood_community_salt_v1';
  static const String communityLastReportAtKey = 'yala_flood_community_last_report_v1';
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
  static const String emergencyYalaHospital = '073228934';
  static const String emergencyYalaHospitalDisplay = '073-228934';
  static const String emergencyArmyMtb46 = '073340141';
  static const String emergencyArmyMtb46Display = '073-340141';
  static const String emergencyVolunteer = '1677';

  // ── ช่องทางออนไลน์ทางการที่ตรวจสอบ HTTP 200 แล้ว (contacts.yaml v3) ────────
  static const String lineDdpmUrl = 'https://line.me/R/ti/p/@1784DDPM';
  static const String lineYalaCityUrl = 'https://line.me/R/ti/p/@yalacity';
  static const String fbDdpmUrl = 'https://www.facebook.com/DDPMNews';
  static const String fbNiemsUrl = 'https://www.facebook.com/thainems';
  static const String fbYalaHospitalUrl = 'https://www.facebook.com/pryalahospital';
  static const String fbRuamduayUrl = 'https://www.facebook.com/ruamduay';
  static const String webYalaCityUrl = 'https://www.yalacity.go.th';
  static const String webYalaHospitalUrl = 'https://www.yalahospital.go.th';

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
