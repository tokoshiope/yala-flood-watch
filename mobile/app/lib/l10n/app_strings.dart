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
      'th': 'แจ้งเตือนน้ำท่วมยะลา',
      'en': 'Yala Flood Warning',
      'zh': '也拉洪水预警',
      'ms': 'Amaran Banjir Yala',
    },
    'tab_home': {'th': 'แผนที่', 'en': 'Map', 'zh': '地图', 'ms': 'Peta'},
    'tab_alerts': {'th': 'ข้อมูล', 'en': 'Info', 'zh': '数据', 'ms': 'Info'},
    'tab_sos': {'th': 'SOS', 'en': 'SOS', 'zh': '求救', 'ms': 'SOS'},
    'tab_shelters': {
      'th': 'ศูนย์พักพิง',
      'en': 'Shelters',
      'zh': '避难中心',
      'ms': 'Pusat Pemindahan',
    },
    'tab_settings': {'th': 'ตั้งค่า', 'en': 'Settings', 'zh': '设置', 'ms': 'Tetapan'},
    'info_title': {'th': 'ข้อมูล', 'en': 'Flood Info', 'zh': '水情数据', 'ms': 'Maklumat Banjir'},
    'dam_title': {
      'th': 'เขื่อนบางลาง',
      'en': 'Bang Lang Dam',
      'zh': '邦朗水坝',
      'ms': 'Empangan Bang Lang',
    },
    'shelters_title': {
      'th': 'ศูนย์พักพิง',
      'en': 'Evacuation Centers',
      'zh': '临时避难中心',
      'ms': 'Pusat Pemindahan',
    },
    'hist_shelter_badge': {
      'th': 'อ้างอิงจากข้อมูลเดิม รอยืนยัน',
      'en': 'Historical reference — pending confirmation',
      'zh': '参考历史数据（待确认）',
      'ms': 'Rujukan data lama — menunggu pengesahan',
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
      'th': 'สถานีวัดระดับน้ำ จ.ยะลา',
      'en': 'Yala Water Stations',
      'zh': '也拉水文监测站',
      'ms': 'Stesen Paras Air Yala',
    },
    'all_amphoes': {
      'th': 'ทั้ง 8 อำเภอ',
      'en': 'All 8 Districts',
      'zh': '全部 8 县',
      'ms': 'Semua 8 Daerah',
    },
    'sound_toggle': {
      'th': 'เปิดเสียงแจ้งเตือน',
      'en': 'Alert Sound',
      'zh': '警报声音',
      'ms': 'Bunyi Amaran',
    },
    'sound_toggle_sub': {
      'th': 'ส่งเสียงเตือนทันทีเมื่อมีระดับน้ำสูงขึ้น',
      'en': 'Play sound when a flood alert triggers',
      'zh': '触发洪水预警时播放声音',
      'ms': 'Mainkan bunyi apabila amaran banjir diaktifkan',
    },
    'notif_toggle': {
      'th': 'เปิดข้อความ Notification',
      'en': 'Notification Messages',
      'zh': '通知消息 (Notification)',
      'ms': 'Mesej Pemberitahuan (Notification)',
    },
    'notif_toggle_sub': {
      'th': 'แสดงแถบข้อความแจ้งเตือนบนหน้าจอโทรศัพท์',
      'en': 'Show push notification banners on screen',
      'zh': '在手机屏幕上显示预警通知横幅',
      'ms': 'Papar pemberitahuan amaran di skrin telefon',
    },
    'map_back_province': {
      'th': 'กลับทั้งจังหวัดยะลา',
      'en': 'Back to Yala Province',
      'zh': '返回也拉全府',
      'ms': 'Kembali ke Wilayah Yala',
    },
    'large_text_toggle': {
      'th': 'โหมดตัวอักษรใหญ่ (ผู้สูงอายุ)',
      'en': 'Large Text Mode',
      'zh': '大字体模式 (长辈关怀)',
      'ms': 'Mod Tulisan Besar',
    },
    'large_text_sub': {
      'th': 'ขยายขนาดตัวอักษรให้อ่านง่ายชัดเจนยิ่งขึ้น',
      'en': 'Increase text size across screens for easier reading',
      'zh': '放大界面字体便于阅读',
      'ms': 'Besarkan teks untuk kemudahan membaca',
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
