/// ระบบแปลภาษา 4 ภาษา (ไทย / อังกฤษ / จีน / มาเลเซีย) สำหรับแอปน้ำท่วมยะลา
class AppStrings {
  const AppStrings(this.lang);

  final String lang;

  static const List<MapEntry<String, String>> supportedLanguages = [
    MapEntry('th', '🇹🇭 ไทย (Thai)'),
    MapEntry('en', '🇬🇧 English'),
    MapEntry('zh', '🇨🇳 中文 (Chinese)'),
    MapEntry('ms', '🇲🇾 Bahasa Melayu'),
  ];

  static const Map<String, Map<String, String>> _dict = {
    'app_title': {
      'th': 'น้ำท่วมยะลา',
      'en': 'Yala Flood Watch',
      'zh': '也拉洪水预警',
      'ms': 'Amaran Banjir Yala',
    },
    'tab_home': {'th': 'หน้าหลัก', 'en': 'Home', 'zh': '首页', 'ms': 'Utama'},
    'tab_alerts': {'th': 'แจ้งเตือน', 'en': 'Alerts', 'zh': '预警', 'ms': 'Amaran'},
    'tab_sos': {'th': 'SOS', 'en': 'SOS', 'zh': '求救', 'ms': 'SOS'},
    'tab_shelters': {
      'th': 'ศูนย์พักพิง',
      'en': 'Shelters',
      'zh': '避难中心',
      'ms': 'Pusat Pemindahan',
    },
    'tab_settings': {'th': 'ตั้งค่า', 'en': 'Settings', 'zh': '设置', 'ms': 'Tetapan'},
    'shelters_title': {
      'th': 'ศูนย์พักพิง',
      'en': 'Evacuation Centers',
      'zh': '临时避难中心',
      'ms': 'Pusat Pemindahan',
    },
    'nav_google_maps': {
      'th': 'นำทาง Google Maps',
      'en': 'Google Maps Route',
      'zh': 'Google 地图导航',
      'ms': 'Arah Google Maps',
    },
    'call_shelter': {
      'th': 'โทรสอบถาม',
      'en': 'Call',
      'zh': '拨打电话',
      'ms': 'Hubungi',
    },
    'updated_tz': {
      'th': 'เวลาไทย UTC+7',
      'en': 'Thailand UTC+7',
      'zh': '泰国时间 UTC+7',
      'ms': 'Waktu Thailand UTC+7',
    },
    'language_section': {
      'th': 'ภาษาของแอป (Language)',
      'en': 'App Language',
      'zh': '应用语言 (Language)',
      'ms': 'Bahasa Aplikasi',
    },
    'rain_drawer_open': {
      'th': 'ซ่อนกราฟพยากรณ์ฝนรายชั่วโมง (เวลาไทย UTC+7)',
      'en': 'Hide 24h Hourly Rain Forecast (UTC+7)',
      'zh': '收起逐时降雨预报 (泰国时间 UTC+7)',
      'ms': 'Tutup Carta Hujan 24 Jam (UTC+7)',
    },
    'rain_drawer_closed': {
      'th': 'ดูกราฟพยากรณ์ฝนรายชั่วโมง (เวลาไทย UTC+7)',
      'en': 'Show 24h Hourly Rain Forecast (UTC+7)',
      'zh': '展开逐时降雨预报 (泰国时间 UTC+7)',
      'ms': 'Lihat Carta Hujan 24 Jam (UTC+7)',
    },
    'latest_stations': {
      'th': 'สถานีอัปเดตล่าสุด',
      'en': 'Latest Stations',
      'zh': '最新水文站',
      'ms': 'Stesen Terkini',
    },
    'all_amphoes': {
      'th': 'ทั้ง 8 อำเภอ',
      'en': 'All 8 Districts',
      'zh': '全部 8 县',
      'ms': 'Semua 8 Daerah',
    },
    'settings_title': {'th': 'ตั้งค่า', 'en': 'Settings', 'zh': '设置', 'ms': 'Tetapan'},
  };

  static const Map<String, Map<String, String>> _amphoes = {
    'เมืองยะลา': {'th': 'เมืองยะลา', 'en': 'Mueang Yala', 'zh': '也拉府直辖县', 'ms': 'Mueang Yala'},
    'รามัน': {'th': 'รามัน', 'en': 'Raman', 'zh': '拉曼县', 'ms': 'Raman'},
    'ยะหา': {'th': 'ยะหา', 'en': 'Yaha', 'zh': '亚哈县', 'ms': 'Yaha'},
    'กรงปินัง': {'th': 'กรงปินัง', 'en': 'Krong Pinang', 'zh': '功比南县', 'ms': 'Krong Pinang'},
    'เบตง': {'th': 'เบตง', 'en': 'Betong', 'zh': '勿洞县', 'ms': 'Betong'},
    'บันนังสตา': {'th': 'บันนังสตา', 'en': 'Bannang Sata', 'zh': '班南沙达县', 'ms': 'Bannang Sata'},
    'ธารโต': {'th': 'ธารโต', 'en': 'Than To', 'zh': '丹多县', 'ms': 'Than To'},
    'กาบัง': {'th': 'กาบัง', 'en': 'Kabang', 'zh': '加邦县', 'ms': 'Kabang'},
  };

  String get(String key) => _dict[key]?[lang] ?? _dict[key]?['th'] ?? key;

  String amphoe(String thName) => _amphoes[thName]?[lang] ?? thName;

  /// แปลงเวลาใดๆ เป็นเวลาประเทศไทย (UTC+7) ชัดเจนเสมอ
  static String formatThailandTime(DateTime dt, {bool includeDate = true}) {
    final th = dt.toUtc().add(const Duration(hours: 7));
    final hh = th.hour.toString().padLeft(2, '0');
    final mm = th.minute.toString().padLeft(2, '0');
    if (!includeDate) return '$hh:$mm น. (UTC+7)';
    final dd = th.day.toString().padLeft(2, '0');
    final mo = th.month.toString().padLeft(2, '0');
    return '$dd/$mo $hh:$mm น. (เวลาไทย UTC+7)';
  }
}
