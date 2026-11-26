import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/sos_request.dart';
import 'package:yala_flood_app/models/station.dart';

/// ระบบแปลภาษาสมบูรณ์ 4 ภาษา (ไทย / อังกฤษ / จีน / มาเลเซีย) ครอบคลุมทุกหน้าจอและข้อมูล
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
    // ── App & Navigation ──────────────────────────────────────────────────
    'app_title': {
      'th': 'แจ้งเตือนน้ำท่วมยะลา',
      'en': 'Yala Flood Warning',
      'zh': '也拉洪水预警',
      'ms': 'Amaran Banjir Yala',
    },
    'tab_home': {'th': 'แผนที่', 'en': 'Map', 'zh': '地图', 'ms': 'Peta'},
    'tab_alerts': {'th': 'ข้อมูล', 'en': 'Info', 'zh': '数据', 'ms': 'Info'},
    'tab_sos': {'th': 'ฉุกเฉิน', 'en': 'Emergency', 'zh': '紧急求助', 'ms': 'Kecemasan'},
    'tab_shelters': {
      'th': 'ศูนย์พักพิง',
      'en': 'Shelters',
      'zh': '避难中心',
      'ms': 'Pusat Pemindahan',
    },
    'tab_settings': {'th': 'ตั้งค่า', 'en': 'Settings', 'zh': '设置', 'ms': 'Tetapan'},
    'info_title': {'th': 'ข้อมูล', 'en': 'Flood Info', 'zh': '水情数据', 'ms': 'Maklumat Banjir'},
    'settings_title': {'th': 'ตั้งค่า', 'en': 'Settings', 'zh': '设置', 'ms': 'Tetapan'},
    'shelters_title': {
      'th': 'ศูนย์พักพิง',
      'en': 'Evacuation Centers',
      'zh': '临时避难中心',
      'ms': 'Pusat Pemindahan',
    },
    'sos_title': {
      'th': 'ช่องทางฉุกเฉิน',
      'en': 'Emergency Contacts',
      'zh': '紧急联络渠道',
      'ms': 'Saluran Kecemasan',
    },
    'station_detail_title': {
      'th': 'รายละเอียดสถานี',
      'en': 'Station Details',
      'zh': '监测站详情',
      'ms': 'Butiran Stesen',
    },
    'refresh_tooltip': {
      'th': 'โหลดข้อมูลใหม่',
      'en': 'Refresh data',
      'zh': '刷新数据',
      'ms': 'Muat semula data',
    },
    'retry': {'th': 'ลองอีกครั้ง', 'en': 'Try Again', 'zh': '重试', 'ms': 'Cuba Lagi'},
    'cancel': {'th': 'ยกเลิก', 'en': 'Cancel', 'zh': '取消', 'ms': 'Batal'},
    'close': {'th': 'ปิด', 'en': 'Close', 'zh': '关闭', 'ms': 'Tutup'},
    'unknown': {'th': 'ไม่ระบุ', 'en': 'N/A', 'zh': '未知', 'ms': 'Tiada data'},
    'yala_province': {
      'th': 'จ.ยะลา',
      'en': 'Yala Province',
      'zh': '也拉府',
      'ms': 'Wilayah Yala',
    },

    // ── Bang Lang Dam Card ────────────────────────────────────────────────
    'dam_title': {
      'th': 'เขื่อนบางลาง',
      'en': 'Bang Lang Dam',
      'zh': '邦朗水坝',
      'ms': 'Empangan Bang Lang',
    },
    'dam_normal': {
      'th': 'ควบคุมปกติ',
      'en': 'Normal Control',
      'zh': '正常调控',
      'ms': 'Kawalan Normal',
    },
    'dam_spillway_alert': {
      'th': 'ระบายน้ำล้นฉุกเฉิน',
      'en': 'Spillway Active',
      'zh': '溢洪道紧急泄洪',
      'ms': 'Pelepasan Kecemasan',
    },
    'dam_storage_pct': {
      'th': 'ความจุน้ำ',
      'en': 'Capacity',
      'zh': '蓄水率',
      'ms': 'Kapasiti',
    },
    'dam_volume': {
      'th': 'ปริมาณน้ำ',
      'en': 'Volume',
      'zh': '蓄水量',
      'ms': 'Isipadu',
    },
    'dam_release_day': {
      'th': 'ระบายน้ำ/วัน',
      'en': 'Release/Day',
      'zh': '日泄洪量',
      'ms': 'Pelepasan/Hari',
    },
    'unit_mcm': {
      'th': 'ล้าน ลบ.ม.',
      'en': 'MCM',
      'zh': '百万方',
      'ms': 'Juta m³',
    },

    // ── Map, Elevation & Drill-Down ───────────────────────────────────────
    'map_province_hint': {
      'th': 'จ.ยะลา (8 อำเภอ · แตะอำเภอหรือกดค้างเพื่อปักหมุด)',
      'en': 'Yala (8 Districts · Tap district or long-press to pin)',
      'zh': '也拉府 (8个县 · 点击县区或长按地图标记位置)',
      'ms': 'Yala (8 Daerah · Tekan daerah atau tekan lama untuk pin)',
    },
    'map_back_province': {
      'th': 'กลับทั้งจังหวัดยะลา',
      'en': 'Back to Yala Province',
      'zh': '返回也拉全府',
      'ms': 'Kembali ke Wilayah Yala',
    },
    'map_back_tumbon': {
      'th': 'กลับตำบล',
      'en': 'Back to Subdistricts',
      'zh': '返回乡镇',
      'ms': 'Kembali ke Mukim',
    },
    'subdistricts_unit': {
      'th': 'ตำบล',
      'en': 'subdistricts',
      'zh': '个乡镇',
      'ms': 'mukim',
    },
    'villages_unit': {
      'th': 'หมู่บ้าน',
      'en': 'villages',
      'zh': '个村',
      'ms': 'kampung',
    },
    'elev_legend_title': {
      'th': 'ความสูงพื้นที่ (ม.รทก.)',
      'en': 'Elevation (m MSL)',
      'zh': '海拔高度 (米 MSL)',
      'ms': 'Ketinggian (m MSL)',
    },
    'elev_low_risk': {
      'th': 'ลุ่มต่ำ/เสี่ยงสูง',
      'en': 'Lowland / High risk',
      'zh': '低洼/高风险',
      'ms': 'Rendah / Risiko tinggi',
    },
    'elev_high_safe': {
      'th': 'ที่สูง/ปลอดภัยกว่า',
      'en': 'Highland / Safer',
      'zh': '高地/较安全',
      'ms': 'Tinggi / Lebih selamat',
    },
    'unit_msl': {'th': 'ม.รทก.', 'en': 'm MSL', 'zh': '米 MSL', 'ms': 'm MSL'},
    'unit_m': {'th': 'ม.', 'en': 'm', 'zh': '米', 'ms': 'm'},
    'unit_mm': {'th': 'มม.', 'en': 'mm', 'zh': '毫米', 'ms': 'mm'},
    'unit_km': {'th': 'กม.', 'en': 'km', 'zh': '公里', 'ms': 'km'},
    'view_station_detail': {
      'th': 'ดูรายละเอียดสถานี',
      'en': 'View Station Details',
      'zh': '查看监测站详情',
      'ms': 'Lihat Butiran Stesen',
    },
    'loading_yala': {
      'th': 'กำลังโหลดข้อมูลระดับน้ำของจังหวัดยะลา…',
      'en': 'Loading Yala flood monitoring data…',
      'zh': '正在加载也拉水文监测数据…',
      'ms': 'Memuatkan data paras air Wilayah Yala…',
    },
    'load_failed': {
      'th': 'ขออภัย โหลดข้อมูลไม่สำเร็จ',
      'en': 'Unable to load data',
      'zh': '抱歉，数据加载失败',
      'ms': 'Maaf, gagal memuatkan data',
    },
    'no_station_data': {
      'th': 'ยังไม่มีข้อมูลสถานี',
      'en': 'No station data available yet',
      'zh': '暂无监测站数据',
      'ms': 'Tiada data stesen buat masa ini',
    },
    'offline_cached_notice': {
      'th': 'ไม่มีสัญญาณเน็ต กำลังแสดงข้อมูลล่าสุดที่บันทึกไว้',
      'en': 'Offline mode — showing last saved snapshot',
      'zh': '离线模式 — 显示最近保存的数据',
      'ms': 'Mod luar talian — memaparkan data terakhir disimpan',
    },

    // ── User GPS & Map Pin Comparison ─────────────────────────────────────
    'my_location_btn': {
      'th': 'ตำแหน่งของฉัน',
      'en': 'My Location',
      'zh': '我的位置',
      'ms': 'Lokasi Saya',
    },
    'pin_mode_btn': {
      'th': 'ปักหมุด',
      'en': 'Drop Pin',
      'zh': '地图标点',
      'ms': 'Pin Lokasi',
    },
    'pin_mode_hint': {
      'th': 'แตะบนแผนที่เพื่อปักหมุดจุดที่ต้องการเปรียบเทียบระดับน้ำ',
      'en': 'Tap anywhere in Yala on the map to place your pin',
      'zh': '点击也拉地图任意位置放置标记点以对比水位',
      'ms': 'Tekan mana-mana lokasi di peta Yala untuk meletakkan pin',
    },
    'pinned_point_title': {
      'th': 'จุดปักหมุดของคุณ',
      'en': 'Your Pinned Location',
      'zh': '您的标记位置',
      'ms': 'Lokasi Pin Anda',
    },
    'gps_point_title': {
      'th': 'ตำแหน่ง GPS ของคุณ',
      'en': 'Your GPS Location',
      'zh': '您的 GPS 位置',
      'ms': 'Lokasi GPS Anda',
    },
    'clear_pin': {
      'th': 'ลบหมุด',
      'en': 'Clear Pin',
      'zh': '清除标记',
      'ms': 'Padam Pin',
    },
    'outside_yala_notice': {
      'th': 'พิกัดอยู่นอกเขต จ.ยะลา — กดปุ่มปักหมุดหรือกดค้างในเขตยะลาเพื่อเทียบระดับน้ำ',
      'en': 'Coordinates are outside Yala — drop a pin inside Yala to compare flood levels',
      'zh': '坐标位于也拉府外 — 请在也拉区域内长按标点以对比水位',
      'ms': 'Koordinat di luar Yala — letakkan pin dalam Yala untuk perbandingan paras air',
    },
    'ground_elevation': {
      'th': 'ความสูงพื้นที่',
      'en': 'Ground Elevation',
      'zh': '地面海拔',
      'ms': 'Ketinggian Tanah',
    },
    'nearest_station': {
      'th': 'สถานีใกล้สุด',
      'en': 'Nearest Station',
      'zh': '最近监测站',
      'ms': 'Stesen Terdekat',
    },
    'ref_river_level': {
      'th': 'ระดับน้ำแม่น้ำอ้างอิงในอำเภอ',
      'en': 'District reference river level',
      'zh': '县参考河流水位',
      'ms': 'Paras air sungai rujukan daerah',
    },

    // ── Info / Alerts Screen ──────────────────────────────────────────────
    'mark_all_read': {
      'th': 'อ่านทั้งหมด',
      'en': 'Mark All Read',
      'zh': '全部已读',
      'ms': 'Tanda Dibaca',
    },
    'all_stations_normal': {
      'th': 'ขณะนี้ระดับน้ำทุกสถานีอยู่ในเกณฑ์ปกติ',
      'en': 'All monitoring stations are currently at normal levels',
      'zh': '目前所有水文监测站水位均处于正常范围',
      'ms': 'Semua stesen pemantauan berada pada paras normal',
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
    'latest_alerts_header': {
      'th': 'ประกาศแจ้งเตือนล่าสุด',
      'en': 'Recent Alerts',
      'zh': '最新预警公告',
      'ms': 'Amaran Terkini',
    },
    'district_summary_header': {
      'th': 'สถานการณ์รายอำเภอ',
      'en': 'District Overview',
      'zh': '各县水情概况',
      'ms': 'Situasi Mengikut Daerah',
    },
    'districts_unit': {
      'th': 'อำเภอ',
      'en': 'Districts',
      'zh': '个县',
      'ms': 'Daerah',
    },
    'latest_stations': {
      'th': 'สถานีวัดระดับน้ำ จ.ยะลา',
      'en': 'Yala Water Stations',
      'zh': '也拉水文监测站',
      'ms': 'Stesen Paras Air Yala',
    },
    'stations_unit': {
      'th': 'แห่ง',
      'en': 'stations',
      'zh': '座',
      'ms': 'stesen',
    },
    'rain_24h_label': {
      'th': 'ฝน 24 ชม.',
      'en': '24h Rain',
      'zh': '24小时降雨',
      'ms': 'Hujan 24j',
    },
    'forecast_24h_label': {
      'th': 'พยากรณ์ฝน 24 ชม.',
      'en': '24h Forecast',
      'zh': '24小时预报',
      'ms': 'Ramalan 24j',
    },
    'updated_tz': {
      'th': 'เวลาไทย UTC+7',
      'en': 'Thailand UTC+7',
      'zh': '泰国时间 UTC+7',
      'ms': 'Waktu Thailand UTC+7',
    },

    // ── Shelters Screen ───────────────────────────────────────────────────
    'shelters_call_notice': {
      'th': 'โปรดโทร 073-203559 (ปภ.ยะลา) หรือ 073-212345 (เทศบาลนครยะลา) เพื่อตรวจสถานะการเปิดรับผู้ประสบภัยก่อนเดินทาง',
      'en': 'Please call 073-203559 (Yala DDPM) or 073-212345 (Yala Municipality) to confirm shelter opening status before traveling.',
      'zh': '出行前请先致电 073-203559（也拉防灾减灾办）或 073-212345（也拉市政府）确认避难中心开放状态。',
      'ms': 'Sila hubungi 073-203559 (DDPM Yala) atau 073-212345 (Perbandaran Yala) untuk mengesahkan status pembukaan sebelum bertolak.',
    },
    'all_amphoes': {
      'th': 'ทั้ง 8 อำเภอ',
      'en': 'All 8 Districts',
      'zh': '全部 8 县',
      'ms': 'Semua 8 Daerah',
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
    'cannot_open_maps': {
      'th': 'ไม่สามารถเปิด Google Maps ได้จากเครื่องนี้',
      'en': 'Unable to open Google Maps on this device',
      'zh': '无法在此设备上打开 Google 地图',
      'ms': 'Tidak dapat membuka Google Maps pada peranti ini',
    },
    'cannot_call': {
      'th': 'ไม่สามารถโทรได้จากเครื่องนี้',
      'en': 'Unable to place call from this device',
      'zh': '无法在此设备上拨打电话',
      'ms': 'Tidak dapat membuat panggilan daripada peranti ini',
    },
    'cannot_open_link': {
      'th': 'ไม่สามารถเปิดลิงก์ภายนอกได้จากเครื่องนี้',
      'en': 'Unable to open external link on this device',
      'zh': '无法在此设备上打开外部链接',
      'ms': 'Tidak dapat membuka pautan luar pada peranti ini',
    },

    // ── SOS Screen ────────────────────────────────────────────────────────
    'life_safety_disclaimer': {
      'th': 'แอปนี้เป็นเครื่องมือเฝ้าระวังและแจ้งเตือนล่วงหน้าอิสระ ไม่ใช่ช่องทางกู้ภัยหลักของทางราชการ หากประสบเหตุวิกฤตกรุณาโทร 1784 (ปภ.), 073-203559 (ปภ.ยะลา) หรือ 1669 ทันที',
      'en': 'This app is an independent early flood warning tool, not an official rescue dispatch channel. In life-threatening emergencies, call 1784 (DDPM), 073-203559 (Yala DDPM), or 1669 immediately.',
      'zh': '本应用为独立的洪水预警监测工具，并非官方紧急救援通道。如遇危及生命的紧急情况，请立即拨打 1784（防灾热线）、073-203559（也拉防灾办）或 1669。',
      'ms': 'Aplikasi ini ialah alat amaran awal banjir bebas, bukan saluran penyelamat rasmi kerajaan. Dalam kecemasan kritikal, hubungi 1784 (DDPM), 073-203559 (DDPM Yala) atau 1669 segera.',
    },
    'emergency_channels': {
      'th': 'ช่องทางฉุกเฉิน (โทร · LINE · Facebook)',
      'en': 'Emergency Channels (Call · LINE · Facebook)',
      'zh': '紧急求助渠道（电话 · LINE · Facebook）',
      'ms': 'Saluran Kecemasan (Telefon · LINE · Facebook)',
    },
    'sos_save_btn': {
      'th': 'ส่งคำขอ SOS พร้อมพิกัดจริง',
      'en': 'Send Real SOS with GPS',
      'zh': '发送带 GPS 坐标的真实 SOS 求助',
      'ms': 'Hantar SOS Sebenar dengan GPS',
    },
    'sos_save_sub': {
      'th': 'ส่งผ่าน SMS (ใช้ได้แม้ไม่มีเน็ต) · LINE · คัดลอก หรือโทร 1784 / 073-203559',
      'en': 'Dispatch via SMS (works offline) · LINE · Copy or Call 1784 / 073-203559',
      'zh': '通过短信（离线可用）· LINE · 复制或直接拨打 1784 / 073-203559',
      'ms': 'Hantar melalui SMS (berfungsi luar talian) · LINE · Salin atau Hubungi 1784 / 073-203559',
    },
    'sos_help_type': {
      'th': 'ประเภทความช่วยเหลือ',
      'en': 'Type of Assistance',
      'zh': '求助类型',
      'ms': 'Jenis Bantuan',
    },
    'gps_card_title': {
      'th': 'พิกัด GPS ของคุณ (ขอสิทธิ์เมื่อกดเท่านั้น)',
      'en': 'Your GPS Coordinates (On-Demand Only)',
      'zh': '您的 GPS 坐标（仅在点击时获取）',
      'ms': 'Koordinat GPS Anda (Atas Permintaan Sahaja)',
    },
    'gps_locate_btn': {
      'th': 'ค้นหาพิกัด GPS',
      'en': 'Find GPS',
      'zh': '获取 GPS',
      'ms': 'Cari GPS',
    },
    'gps_searching': {
      'th': 'กำลังค้นหาสัญญาณ GPS…',
      'en': 'Acquiring GPS signal…',
      'zh': '正在获取 GPS 信号…',
      'ms': 'Sedang mencari isyarat GPS…',
    },
    'gps_idle_hint': {
      'th': 'กดปุ่ม "ค้นหาพิกัด GPS" เพื่อให้แสดงพิกัดสำหรับแจ้งเจ้าหน้าที่กู้ภัย (ไม่เก็บพิกัดพื้นหลัง)',
      'en': 'Tap "Find GPS" to view your coordinates to read to rescue dispatchers (no background tracking).',
      'zh': '点击“获取 GPS”以显示坐标并告知救援人员（不进行后台位置追踪）。',
      'ms': 'Tekan "Cari GPS" untuk melihat koordinat bagi dimaklumkan kepada penyelamat (tiada penjejakan latar).',
    },
    'gps_open_settings': {
      'th': 'เปิดการตั้งค่าตำแหน่ง',
      'en': 'Open Location Settings',
      'zh': '打开位置设置',
      'ms': 'Buka Tetapan Lokasi',
    },
    'gps_permission_denied': {
      'th': 'ยังไม่ได้รับสิทธิ์ตำแหน่ง กด "เปิดการตั้งค่าตำแหน่ง" เพื่ออนุญาตเฉพาะขณะใช้งาน (When In Use)',
      'en': 'Location permission not granted. Tap "Open Location Settings" to allow "While Using the App".',
      'zh': '未获得位置权限。请点击“打开位置设置”以允许“使用应用期间”访问位置。',
      'ms': 'Kebenaran lokasi tidak diberikan. Tekan "Buka Tetapan Lokasi" untuk membenarkan semasa digunakan.',
    },
    'gps_service_disabled': {
      'th': 'GPS ของเครื่องยังปิดอยู่ กรุณาเปิดบริการตำแหน่ง',
      'en': 'Location Services are turned off. Please enable GPS in device settings.',
      'zh': '设备定位服务已关闭，请在系统设置中开启 GPS。',
      'ms': 'Perkhidmatan Lokasi dimatikan. Sila aktifkan GPS pada tetapan peranti.',
    },
    'gps_consent_title': {
      'th': 'ขอความยินยอมใช้พิกัด GPS (PDPA)',
      'en': 'GPS Location Consent (PDPA)',
      'zh': 'GPS 位置使用授权 (PDPA)',
      'ms': 'Persetujuan Lokasi GPS (PDPA)',
    },
    'gps_consent_body': {
      'th': 'แอปจะอ่านพิกัดของคุณเฉพาะขณะใช้งานหน้าแผนที่นี้เท่านั้น เพื่อเทียบความสูงพื้นที่กับระดับน้ำแม่น้ำในเครื่อง โดยไม่มีการส่งออกหรือติดตามตำแหน่งพื้นหลัง คุณสามารถลบข้อมูลได้ทุกเมื่อในหน้าตั้งค่า',
      'en': 'The app reads your GPS only while using the map to compare your ground elevation against river levels on-device. Coordinates are never tracked in the background or uploaded, and can be deleted anytime in Settings.',
      'zh': '本应用仅在您使用地图时在本地读取 GPS，用于对比地面海拔与河流水位。绝不后台追踪或上传位置，您可随时在设置中删除。',
      'ms': 'Aplikasi hanya membaca GPS semasa peta digunakan bagi membandingkan ketinggian tanah dengan paras air secara setempat. Tiada penjejakan latar belakang dan data boleh dipadam bila-bila masa di Tetapan.',
    },
    'gps_decline': {'th': 'ไม่ยินยอม', 'en': 'Decline', 'zh': '拒绝', 'ms': 'Tolak'},
    'gps_accept': {
      'th': 'ยินยอมและค้นหาพิกัด',
      'en': 'Allow & Locate',
      'zh': '同意并定位',
      'ms': 'Setuju & Cari',
    },
    'phone_input_label': {
      'th': 'เบอร์โทรที่ติดต่อได้ (เก็บในเครื่องเท่านั้น)',
      'en': 'Contact Phone Number (Stored Locally Only)',
      'zh': '联系电话（仅存储在本地设备）',
      'ms': 'Nombor Telefon (Disimpan Dalam Peranti Sahaja)',
    },
    'phone_input_hint': {
      'th': 'เช่น 0812345678',
      'en': 'e.g. 0812345678',
      'zh': '例如 0812345678',
      'ms': 'cth. 0812345678',
    },
    'phone_invalid': {
      'th': 'กรุณากรอกเบอร์โทรที่ติดต่อได้ให้ถูกต้อง',
      'en': 'Please enter a valid contact phone number',
      'zh': '请输入有效的联系电话',
      'ms': 'Sila masukkan nombor telefon yang sah',
    },
    'sos_need_gps': {
      'th': 'กรุณากด "ค้นหาพิกัด GPS" เพื่อยืนยันตำแหน่งก่อนส่งคำขอ SOS',
      'en': 'Please tap "Find GPS" first to confirm your location before sending SOS.',
      'zh': '发送 SOS 前请先点击“获取 GPS”确认您的位置。',
      'ms': 'Sila tekan "Cari GPS" dahulu untuk mengesahkan lokasi sebelum menghantar SOS.',
    },
    'sos_saved_snack': {
      'th': 'เตรียมข้อความ SOS พร้อมพิกัดแล้ว เลือกส่งผ่าน SMS / LINE หรือโทร 1784 ได้ทันที',
      'en': 'SOS message & GPS ready. Dispatch via SMS / LINE or call 1784 immediately.',
      'zh': 'SOS 求助信息与坐标已准备就绪，可立即通过短信 / LINE 发送或拨打 1784。',
      'ms': 'Mesej SOS & GPS sedia. Hantar melalui SMS / LINE atau hubungi 1784 segera.',
    },
    'sos_local_history': {
      'th': 'ประวัติคำขอ SOS ในเครื่อง',
      'en': 'Local SOS History',
      'zh': '本机 SOS 求助记录',
      'ms': 'Sejarah SOS Dalam Peranti',
    },
    'sos_note_label': {
      'th': 'รายละเอียดเพิ่มเติม (เก็บในเครื่องเท่านั้น)',
      'en': 'Additional Details (Stored Locally Only)',
      'zh': '补充说明（仅保存在本机）',
      'ms': 'Maklumat Tambahan (Disimpan Dalam Peranti Sahaja)',
    },
    'sos_note_hint': {
      'th': 'เช่น มีผู้สูงอายุ 2 คน น้ำท่วมชั้น 1 สูง 80 ซม.',
      'en': 'e.g. 2 elderly residents, water 80 cm indoors',
      'zh': '例如：有 2 位老人，室内积水 80 厘米',
      'ms': 'cth. 2 warga emas, air setinggi 80 cm di dalam rumah',
    },
    'sos_dispatch_title': {
      'th': 'เลือกช่องทางส่งข้อความ SOS จริง',
      'en': 'Choose Real SOS Dispatch Channel',
      'zh': '选择真实 SOS 发送渠道',
      'ms': 'Pilih Saluran Penghantaran SOS Sebenar',
    },
    'sos_dispatch_sub': {
      'th': 'ข้อความถูกจัดเตรียมพร้อมพิกัด GPS และลิงก์แผนที่แล้ว (ไม่เก็บเบอร์โทรบนเซิร์ฟเวอร์)',
      'en': 'Message prepared with exact GPS & Google Maps link (phone number stays strictly on device).',
      'zh': '已生成包含精确 GPS 与地图链接的求助信息（电话号码仅保留在本机）。',
      'ms': 'Mesej sedia dengan GPS tepat & pautan Google Maps (nombor telefon kekal dalam peranti).',
    },
    'sos_dispatch_sms': {
      'th': 'ส่ง SMS ฉุกเฉิน (ใช้ได้แม้เน็ตล่ม)',
      'en': 'Send Emergency SMS (Works Offline)',
      'zh': '发送紧急短信（断网可用）',
      'ms': 'Hantar SMS Kecemasan (Berfungsi Tanpa Internet)',
    },
    'sos_dispatch_line': {
      'th': 'ส่งต่อผ่าน LINE (ญาติ / กู้ภัย / กลุ่ม)',
      'en': 'Share via LINE (Family / Rescue / Group)',
      'zh': '通过 LINE 分享（家人 / 救援队 / 群组）',
      'ms': 'Kongsi melalui LINE (Keluarga / Penyelamat)',
    },
    'sos_dispatch_copy': {
      'th': 'คัดลอกข้อความ + พิกัด',
      'en': 'Copy Message & GPS',
      'zh': '复制求助信息与坐标',
      'ms': 'Salin Mesej & GPS',
    },
    'sos_dispatch_copied': {
      'th': 'คัดลอกข้อความ SOS พร้อมพิกัดแล้ว สามารถวางส่งใน LINE หรือแชทได้ทันที',
      'en': 'SOS message & GPS copied. You can paste and send immediately.',
      'zh': '已复制 SOS 信息与坐标，可立即粘贴发送。',
      'ms': 'Mesej SOS & GPS disalin. Anda boleh tampal dan hantar segera.',
    },
    'sos_dispatch_copy_ddpm': {
      'th': 'คัดลอกแล้วเปิด LINE @1784DDPM',
      'en': 'Copy & Open LINE @1784DDPM',
      'zh': '复制并打开 LINE @1784DDPM',
      'ms': 'Salin & Buka LINE @1784DDPM',
    },
    'sos_dispatch_copy_city': {
      'th': 'คัดลอกแล้วเปิด LINE @yalacity',
      'en': 'Copy & Open LINE @yalacity',
      'zh': '复制并打开 LINE @yalacity',
      'ms': 'Salin & Buka LINE @yalacity',
    },
    'sos_dispatch_call_section': {
      'th': 'หรือกดโทรด่วนทันที (อ่านพิกัดด้านบนให้เจ้าหน้าที่)',
      'en': 'Or call immediately (read coordinates above to dispatcher)',
      'zh': '或立即拨打急救电话（向接线员读出上方坐标）',
      'ms': 'Atau hubungi segera (baca koordinat di atas kepada petugas)',
    },
    'sos_dispatch_resend': {
      'th': 'ส่งซ้ำ / แชร์',
      'en': 'Resend / Share',
      'zh': '重新发送 / 分享',
      'ms': 'Hantar Semula / Kongsi',
    },
    'sos_cannot_open_sms': {
      'th': 'ไม่สามารถเปิดแอปส่ง SMS ได้ (คัดลอกข้อความให้แล้ว)',
      'en': 'Unable to open SMS app (message copied to clipboard)',
      'zh': '无法打开短信应用（信息已复制到剪贴板）',
      'ms': 'Tidak dapat membuka aplikasi SMS (mesej telah disalin)',
    },
    'sos_msg_header': {
      'th': '🆘 แจ้งเหตุฉุกเฉินน้ำท่วมยะลา (SOS)',
      'en': '🆘 YALA FLOOD EMERGENCY (SOS)',
      'zh': '🆘 也拉府洪水紧急求助 (SOS)',
      'ms': '🆘 KECEMASAN BANJIR YALA (SOS)',
    },
    'sos_msg_type': {
      'th': 'ประเภท',
      'en': 'Type',
      'zh': '类型',
      'ms': 'Jenis',
    },
    'sos_msg_area': {
      'th': 'พื้นที่',
      'en': 'Area',
      'zh': '区域',
      'ms': 'Kawasan',
    },
    'sos_msg_elevation': {
      'th': 'ความสูงพื้นที่',
      'en': 'Ground Elevation',
      'zh': '地面海拔',
      'ms': 'Ketinggian Tanah',
    },
    'sos_msg_gps': {
      'th': 'พิกัด GPS',
      'en': 'GPS',
      'zh': 'GPS 坐标',
      'ms': 'GPS',
    },
    'sos_msg_map': {
      'th': 'แผนที่นำทาง',
      'en': 'Google Maps',
      'zh': '导航地图',
      'ms': 'Peta Google',
    },
    'sos_msg_phone': {
      'th': 'เบอร์ติดต่อกลับ',
      'en': 'Callback Phone',
      'zh': '联系电话',
      'ms': 'No. Telefon',
    },
    'sos_msg_note': {
      'th': 'รายละเอียด',
      'en': 'Details',
      'zh': '详情',
      'ms': 'Butiran',
    },
    'sos_msg_time': {
      'th': 'เวลาแจ้ง',
      'en': 'Time',
      'zh': '时间',
      'ms': 'Masa',
    },
    // ── Tier C Community Flood Reports (Anonymous · PDPA 90-day) ──────────
    'community_report_title': {
      'th': 'รายงานจุดน้ำท่วมชุมชน (ไม่ระบุตัวตน)',
      'en': 'Community Flood Report (Anonymous)',
      'zh': '社区灾情上报（匿名）',
      'ms': 'Laporan Banjir Komuniti (Tanpa Nama)',
    },
    'community_report_sub': {
      'th': 'ช่วยแจ้งสถานการณ์จริงในพื้นที่เพื่อเตือนภัยเพื่อนบ้านและเสริมข้อมูลระบบ',
      'en': 'Share live ground conditions to alert neighbors and strengthen flood warnings.',
      'zh': '分享实时灾情，提醒周边居民并辅助预警判断。',
      'ms': 'Kongsi keadaan sebenar di lapangan untuk membantu amaran banjir.',
    },
    'community_report_pdpa_note': {
      'th': 'PDPA: ส่งเฉพาะอำเภอ ประเภทเหตุ ระดับน้ำ และพิกัดหยาบ (~110 ม.) ไม่เก็บชื่อหรือเบอร์โทร · ลบอัตโนมัติใน 90 วัน (จำกัด 1 ครั้ง/ชม.)',
      'en': 'PDPA: Sends only district, event type, depth & ~110m rounded coordinates. No name or phone stored; auto-deleted after 90 days (max 1/hr).',
      'zh': 'PDPA 隐私保护：仅上传县区、事件类型、水深及约 110 米模糊坐标，不收集姓名电话，90 天自动删除（每小时限 1 次）。',
      'ms': 'PDPA: Hanya menghantar daerah, jenis kejadian, kedalaman & koordinat dibundarkan ~110m. Tiada nama/telefon; dipadam automatik selepas 90 hari (had 1/jam).',
    },
    'community_report_amphoe': {
      'th': 'อำเภอที่เกิดเหตุ',
      'en': 'District',
      'zh': '所在县区',
      'ms': 'Daerah',
    },
    'community_report_type': {
      'th': 'สถานการณ์ที่พบ',
      'en': 'Observed Situation',
      'zh': '现场情况',
      'ms': 'Keadaan Ditemui',
    },
    'community_report_depth_label': {
      'th': 'ความลึกน้ำโดยประมาณ (ซม. · ไม่บังคับ)',
      'en': 'Estimated Water Depth (cm · optional)',
      'zh': '估算水深（厘米 · 可选）',
      'ms': 'Anggaran Kedalaman Air (cm · pilihan)',
    },
    'community_report_depth_hint': {
      'th': 'เช่น 40',
      'en': 'e.g. 40',
      'zh': '例如 40',
      'ms': 'cth. 40',
    },
    'community_report_note_label': {
      'th': 'หมายเหตุสั้น ๆ (ห้ามระบุชื่อ/เบอร์โทรส่วนตัว)',
      'en': 'Short Note (do not include personal name or phone)',
      'zh': '简短备注（请勿填写个人姓名或电话）',
      'ms': 'Nota Ringkas (jangan masukkan nama/telefon peribadi)',
    },
    'community_report_note_hint': {
      'th': 'เช่น ถนนหน้าตลาดรถเล็กผ่านไม่ได้',
      'en': 'e.g. Market road impassable for small cars',
      'zh': '例如：市场前道路小型车无法通行',
      'ms': 'cth. Jalan hadapan pasar tidak boleh dilalui kereta kecil',
    },
    'community_report_submit_btn': {
      'th': 'ส่งรายงานสถานการณ์ชุมชน',
      'en': 'Submit Community Report',
      'zh': '提交社区灾情报告',
      'ms': 'Hantar Laporan Komuniti',
    },
    'community_report_submitting': {
      'th': 'กำลังส่งรายงาน…',
      'en': 'Submitting report…',
      'zh': '正在提交报告…',
      'ms': 'Sedang menghantar laporan…',
    },
    'community_report_success': {
      'th': 'ส่งรายงานสถานการณ์ชุมชนสำเร็จ ขอบคุณที่ช่วยแจ้งเตือนคนยะลา',
      'en': 'Community flood report submitted. Thank you for helping Yala residents.',
      'zh': '社区灾情报告已提交，感谢您协助守护也拉居民。',
      'ms': 'Laporan banjir komuniti berjaya dihantar. Terima kasih kerana membantu warga Yala.',
    },
    'community_report_rate_limited': {
      'th': 'คุณส่งรายงานไปแล้วภายใน 60 นาทีที่ผ่านมา (ระบบจำกัด 1 ครั้ง/ชั่วโมง เพื่อป้องกันสแปม)',
      'en': 'You already submitted a report within the past 60 minutes (limit: 1 report/hour).',
      'zh': '您在过去 60 分钟内已提交过报告（防刷限制：每小时 1 次）。',
      'ms': 'Anda telah menghantar laporan dalam tempoh 60 minit lalu (had: 1 laporan/jam).',
    },
    'community_report_outside_yala': {
      'th': 'พิกัดอยู่นอกเขตจังหวัดยะลา ไม่สามารถส่งรายงานชุมชนได้',
      'en': 'Coordinates are outside Yala Province; community report rejected.',
      'zh': '当前坐标位于也拉府范围之外，无法提交。',
      'ms': 'Koordinat berada di luar Wilayah Yala; laporan tidak dapat dihantar.',
    },
    'community_report_not_configured': {
      'th': 'บิลด์นี้ยังไม่ได้ตั้งค่าคีย์เซิร์ฟเวอร์รายงานชุมชน (ยังใช้ปุ่มส่ง SOS ผ่าน SMS / LINE ด้านบนได้ตามปกติ)',
      'en': 'Community report server key is not configured in this build (SMS / LINE SOS above works normally).',
      'zh': '当前版本未配置社区上报服务密钥（上方短信 / LINE SOS 功能可正常使用）。',
      'ms': 'Kunci pelayan laporan komuniti belum dikonfigurasi dalam binaan ini (SOS SMS / LINE di atas berfungsi seperti biasa).',
    },
    'community_report_error': {
      'th': 'ไม่สามารถส่งรายงานได้ในขณะนี้ โปรดตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
      'en': 'Unable to submit report right now. Please check your connection and try again.',
      'zh': '暂时无法提交报告，请检查网络后重试。',
      'ms': 'Tidak dapat menghantar laporan sekarang. Sila semak sambungan internet anda.',
    },
    'community_report_invalid_depth': {
      'th': 'กรุณาระบุความลึกน้ำระหว่าง 0–1,000 ซม.',
      'en': 'Please enter water depth between 0 and 1,000 cm.',
      'zh': '请输入 0 至 1,000 厘米之间的水深。',
      'ms': 'Sila masukkan kedalaman air antara 0 hingga 1,000 cm.',
    },
    'community_recent_title': {
      'th': 'รายงานล่าสุดจากชุมชนในพื้นที่',
      'en': 'Recent Community Reports',
      'zh': '最新社区灾情动态',
      'ms': 'Laporan Komuniti Terkini',
    },
    'community_recent_empty': {
      'th': 'ยังไม่มีรายงานชุมชนล่าสุดในขณะนี้',
      'en': 'No recent community reports yet.',
      'zh': '目前暂无最新社区上报记录。',
      'ms': 'Tiada laporan komuniti terkini buat masa ini.',
    },
    'unit_cm': {
      'th': 'ซม.',
      'en': 'cm',
      'zh': '厘米',
      'ms': 'cm',
    },

    // ── Settings Screen & Alert Level Guide ───────────────────────────────
    'language_section': {
      'th': 'ภาษาของแอป (Language)',
      'en': 'App Language',
      'zh': '应用语言 (Language)',
      'ms': 'Bahasa Aplikasi',
    },
    'alert_guide_section': {
      'th': 'คำอธิบายระดับการแจ้งเตือน (1–5)',
      'en': 'Alert Level Guide (Levels 1–5)',
      'zh': '预警级别说明 (1–5 级)',
      'ms': 'Panduan Tahap Amaran (Tahap 1–5)',
    },
    'alert_guide_map_note': {
      'th': 'สีบนแผนที่ไล่ระดับตามความสูงภูมิประเทศจริงจากระดับน้ำทะเล (ม.รทก.) เทียบกับระดับน้ำแม่น้ำในแต่ละอำเภอ พื้นที่ลุ่มต่ำใกล้แม่น้ำจะเปลี่ยนสีเตือนเร็วกว่าพื้นที่สูง',
      'en': 'Map colors grade continuously by real terrain elevation above sea level (m MSL) compared against local river water levels. Low-lying floodplains escalate sooner than highlands.',
      'zh': '地图颜色根据真实海拔高度（米 MSL）与当地河流水位动态渐变分级：低洼河谷区域会比高地更早进入预警色级。',
      'ms': 'Warna peta berubah secara berperingkat mengikut ketinggian sebenar dari aras laut (m MSL) berbanding paras sungai setempat. Kawasan rendah berubah amaran lebih awal berbanding tanah tinggi.',
    },
    'area_section': {
      'th': 'พื้นที่ที่ติดตาม',
      'en': 'Monitored Area',
      'zh': '关注区域',
      'ms': 'Kawasan Dipantau',
    },
    'amphoe_dropdown_label': {
      'th': 'อำเภอ (ครบทั้ง 8 อำเภอของยะลา)',
      'en': 'District (All 8 Yala Districts)',
      'zh': '县区（覆盖也拉全部 8 县）',
      'ms': 'Daerah (Semua 8 Daerah Yala)',
    },
    'whole_province': {
      'th': 'ทั้งจังหวัดยะลา',
      'en': 'All of Yala Province',
      'zh': '也拉全府',
      'ms': 'Seluruh Wilayah Yala',
    },
    'tumbon_dropdown_label': {
      'th': 'ตำบล',
      'en': 'Subdistrict',
      'zh': '乡镇',
      'ms': 'Mukim',
    },
    'all_tumbons': {
      'th': 'ทุกตำบล',
      'en': 'All Subdistricts',
      'zh': '全部乡镇',
      'ms': 'Semua Mukim',
    },
    'threshold_section': {
      'th': 'เกณฑ์การแจ้งเตือน',
      'en': 'Alert Thresholds',
      'zh': '预警触发阈值',
      'ms': 'Ambang Amaran',
    },
    'warn_level_label': {
      'th': 'เริ่มแจ้งเตือนเมื่อระดับสถานการณ์',
      'en': 'Start alerting at level',
      'zh': '开始预警级别',
      'ms': 'Mula amaran pada tahap',
    },
    'danger_level_label': {
      'th': 'ถือว่าอันตรายเมื่อระดับสถานการณ์',
      'en': 'Treat as danger at level',
      'zh': '危险警报级别',
      'ms': 'Anggap bahaya pada tahap',
    },
    'notifications_section': {
      'th': 'การแจ้งเตือนและการแสดงผล',
      'en': 'Notifications & Display',
      'zh': '通知与显示设置',
      'ms': 'Pemberitahuan & Paparan',
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
      'ms': 'Mesej Pemberitahuan',
    },
    'notif_toggle_sub': {
      'th': 'แสดงแถบข้อความแจ้งเตือนบนหน้าจอโทรศัพท์',
      'en': 'Show push notification banners on screen',
      'zh': '在手机屏幕上显示预警通知横幅',
      'ms': 'Papar pemberitahuan amaran di skrin telefon',
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
    'rain_score_toggle': {
      'th': 'ประเมินร่วมกับฝนจริง ความชื้นดิน และพยากรณ์ฝน',
      'en': 'Include real-time rain, soil wetness & forecast',
      'zh': '结合实测降雨、土壤湿润度与降雨预报',
      'ms': 'Sertakan hujan sebenar, kelembapan tanah & ramalan',
    },
    'rain_score_sub': {
      'th': 'ช่วยเตือนภัยล่วงหน้าในพื้นที่ฝนตกหนัก เขตเมือง และท้ายเขื่อนบางลาง',
      'en': 'Improves early warning for heavy rain, urban flooding & downstream Bang Lang Dam',
      'zh': '提升强降雨、城市内涝及邦朗水坝下游的提前预警能力',
      'ms': 'Meningkatkan amaran awal hujan lebat, banjir bandar & hilir Empangan Bang Lang',
    },
    'refresh_interval_label': {
      'th': 'รีเฟรชข้อมูลทุก ๆ',
      'en': 'Auto-refresh interval',
      'zh': '自动刷新间隔',
      'ms': 'Selang muat semula automatik',
    },
    'minutes_unit': {'th': 'นาที', 'en': 'minutes', 'zh': '分钟', 'ms': 'minit'},
    'pdpa_section': {
      'th': 'ความเป็นส่วนตัวและข้อมูล (PDPA)',
      'en': 'Privacy & Data (PDPA)',
      'zh': '隐私与数据管理 (PDPA)',
      'ms': 'Privasi & Data (PDPA)',
    },
    'clear_cache_title': {
      'th': 'ล้างข้อมูลสำรอง (Cache)',
      'en': 'Clear Offline Cache',
      'zh': '清除离线缓存',
      'ms': 'Kosongkan Cache Luar Talian',
    },
    'clear_cache_sub': {
      'th': 'บังคับโหลดค่าใหม่จากเซิร์ฟเวอร์',
      'en': 'Force reload latest telemetry from server',
      'zh': '强制从服务器重新加载最新水文数据',
      'ms': 'Paksa muat semula data terkini daripada pelayan',
    },
    'cache_cleared_snack': {
      'th': 'ล้างข้อมูลสำรองแล้ว',
      'en': 'Offline cache cleared',
      'zh': '已清除离线缓存',
      'ms': 'Cache luar talian dikosongkan',
    },
    'clear_alerts_title': {
      'th': 'ล้างประวัติแจ้งเตือน',
      'en': 'Clear Alert History',
      'zh': '清除预警历史',
      'ms': 'Padam Sejarah Amaran',
    },
    'delete_all_title': {
      'th': 'ลบข้อมูลของฉันทั้งหมด (PDPA)',
      'en': 'Delete All My Data (PDPA)',
      'zh': '删除我的全部本地数据 (PDPA)',
      'ms': 'Padam Semua Data Saya (PDPA)',
    },
    'delete_all_sub': {
      'th': 'ลบหมุดแผนที่, ความยินยอม GPS, แคชในเครื่อง, ประวัติแจ้งเตือน และการตั้งค่าทั้งหมด',
      'en': 'Erase map pin, GPS consent, offline cache, alert history & all preferences',
      'zh': '删除地图标记、GPS 授权、离线缓存、预警历史与全部设置',
      'ms': 'Padam pin peta, persetujuan GPS, cache luar talian, sejarah amaran & semua tetapan',
    },
    'delete_dialog_title': {
      'th': 'ลบข้อมูลทั้งหมดในเครื่อง (PDPA)',
      'en': 'Delete All Local Data (PDPA)',
      'zh': '确认删除全部本地数据 (PDPA)',
      'ms': 'Padam Semua Data Peranti (PDPA)',
    },
    'delete_dialog_body': {
      'th': 'การดำเนินการนี้จะลบประวัติแจ้งเตือน, หมุดแผนที่, ความยินยอม GPS, ข้อมูลแคช และการตั้งค่าทั้งหมดของคุณบนเครื่องนี้ทันที ยืนยันหรือไม่?',
      'en': 'This will immediately erase alert history, saved map pin, GPS consent, offline cache, and all preferences on this device. Continue?',
      'zh': '此操作将立即清除本机上的预警历史、地图标记、GPS 授权、缓存及全部设置。是否继续？',
      'ms': 'Tindakan ini akan memadam sejarah amaran, pin peta, persetujuan GPS, cache dan semua tetapan pada peranti ini dengan segera. Teruskan?',
    },
    'delete_confirm_btn': {
      'th': 'ลบข้อมูลทั้งหมด',
      'en': 'Delete Everything',
      'zh': '确认全部删除',
      'ms': 'Padam Semua',
    },
    'delete_done_snack': {
      'th': 'ลบข้อมูลส่วนบุคคลและประวัติในเครื่องทั้งหมดแล้ว',
      'en': 'All personal data and local history have been erased',
      'zh': '已清除全部个人数据与本地记录',
      'ms': 'Semua data peribadi dan sejarah setempat telah dipadam',
    },
    'sources_section': {
      'th': 'แหล่งข้อมูลและคำชี้แจง',
      'en': 'Data Sources & Disclaimer',
      'zh': '数据来源与免责声明',
      'ms': 'Sumber Data & Penafian',
    },
    'sources_desc': {
      'th': 'ข้อมูลระดับน้ำ ฝน และเขื่อนบางลางจากระบบคลังข้อมูลน้ำแห่งชาติ (สสน. / ชป. / กฟผ.) · พยากรณ์ฝนและปริมาณน้ำท่าจาก Open-Meteo · เวลาแสดงผลตามเวลาประเทศไทย (UTC+7)',
      'en': 'Water levels, rainfall & Bang Lang Dam data from National Hydroinformatics Data Center (HII / RID / EGAT) · Weather & river discharge forecast by Open-Meteo · Times in Thailand UTC+7.',
      'zh': '水位、降雨与邦朗水坝数据来自泰国国家水文信息中心 (HII / RID / EGAT) · 降雨及径流预报来自 Open-Meteo · 所有时间均为泰国时间 (UTC+7)。',
      'ms': 'Paras air, hujan & data Empangan Bang Lang daripada Pusat Data Hidroinformatik Kebangsaan (HII / RID / EGAT) · Ramalan cuaca & sungai oleh Open-Meteo · Masa dalam Waktu Thailand (UTC+7).',
    },

    // ── Station Detail Screen ─────────────────────────────────────────────
    'station_not_found': {
      'th': 'ไม่พบสถานีนี้ในข้อมูล ลองโหลดข้อมูลใหม่อีกครั้ง',
      'en': 'Station not found in current dataset. Please try refreshing.',
      'zh': '未在当前数据中找到该监测站，请尝试刷新。',
      'ms': 'Stesen tidak ditemui dalam data semasa. Sila cuba muat semula.',
    },
    'latest_water_level': {
      'th': 'ระดับน้ำล่าสุด',
      'en': 'Latest Water Level',
      'zh': '最新水位',
      'ms': 'Paras Air Terkini',
    },
    'msl_full_label': {
      'th': 'ม.ระดับน้ำทะเลปานกลาง (MSL)',
      'en': 'Meters above Mean Sea Level (MSL)',
      'zh': '平均海平面以上米数 (MSL)',
      'ms': 'Meter atas Aras Laut Purata (MSL)',
    },
    'compare_bank_title': {
      'th': 'เทียบระดับตลิ่ง',
      'en': 'Bank Level Comparison',
      'zh': '堤岸水位对比',
      'ms': 'Perbandingan Paras Tebing',
    },
    'no_bank_data': {
      'th': 'ไม่มีข้อมูลตลิ่ง',
      'en': 'No bank threshold',
      'zh': '无堤岸基准数据',
      'ms': 'Tiada data tebing',
    },
    'no_bank_explain': {
      'th': 'สถานีนี้ไม่มีค่าระดับตลิ่งจากหน่วยงาน จึงเปรียบเทียบไม่ได้ โปรดติดตามจาก ปภ.ยะลา (073-203559)',
      'en': 'Official bank elevation is not defined for this station. Please follow Yala DDPM (073-203559).',
      'zh': '该监测站暂无官方堤岸高程基准，请结合也拉防灾办 (073-203559) 通告关注。',
      'ms': 'Paras tebing rasmi tidak ditetapkan untuk stesen ini. Sila rujuk DDPM Yala (073-203559).',
    },
    'ground_level_label': {'th': 'ระดับพื้น', 'en': 'Ground', 'zh': '河床/地面', 'ms': 'Paras Tanah'},
    'bank_label': {'th': 'ตลิ่ง', 'en': 'Bank', 'zh': '堤岸', 'ms': 'Tebing'},
    'reservoir_capacity': {
      'th': 'ความจุอ่างเก็บน้ำ',
      'en': 'Reservoir Storage',
      'zh': '水库蓄水率',
      'ms': 'Kapasiti Takungan',
    },
    'trend_chart_title': {
      'th': 'แนวโน้มระดับน้ำย้อนหลัง 7 วัน',
      'en': '7-Day Water Level Trend',
      'zh': '近7天水位变化趋势',
      'ms': 'Trend Paras Air 7 Hari',
    },
    'trend_chart_sub': {
      'th': 'แตะบนกราฟเพื่อดูค่าแต่ละเวลา',
      'en': 'Tap or drag chart to inspect',
      'zh': '点击或拖动图表查看各时段水位',
      'ms': 'Sentuh atau seret graf untuk periksa',
    },
    'range_24h': {'th': '24 ชม.', 'en': '24h', 'zh': '24小时', 'ms': '24j'},
    'range_3d': {'th': '3 วัน', 'en': '3d', 'zh': '3天', 'ms': '3h'},
    'range_7d': {'th': '7 วัน', 'en': '7d', 'zh': '7天', 'ms': '7h'},
    'chart_loading': {
      'th': 'กำลังโหลดข้อมูลย้อนหลัง 7 วัน…',
      'en': 'Loading 7-day history…',
      'zh': '正在加载近7天历史数据…',
      'ms': 'Memuatkan sejarah 7 hari…',
    },
    'remaining_to_bank_hero': {
      'th': 'ระยะเหลือถึงตลิ่ง',
      'en': 'Remaining to Bank',
      'zh': '距堤岸余量',
      'ms': 'Baki ke Tebing',
    },
    'below_bank_short': {
      'th': 'เหลือถึงตลิ่ง',
      'en': 'to bank',
      'zh': '距堤岸',
      'ms': 'ke tebing',
    },
    'over_bank_short': {
      'th': 'ล้นตลิ่งแล้ว',
      'en': 'over bank',
      'zh': '已超堤岸',
      'ms': 'melimpah tebing',
    },
    'watch_level_label': {
      'th': 'เฝ้าระวัง',
      'en': 'Watch',
      'zh': '警戒',
      'ms': 'Waspada',
    },
    'mid_level_label': {
      'th': 'กึ่งกลาง',
      'en': 'Mid',
      'zh': '中线',
      'ms': 'Tengah',
    },
    'early_warning_rain_dam_badge': {
      'th': 'เตือนภัยล่วงหน้าจากฝน/เขื่อน',
      'en': 'Rain / Dam Early Warning',
      'zh': '降雨/水坝提前预警',
      'ms': 'Amaran Awal Hujan / Empangan',
    },
    'min_label': {'th': 'ต่ำสุด', 'en': 'Min', 'zh': '最低', 'ms': 'Min'},
    'max_label': {'th': 'สูงสุด', 'en': 'Max', 'zh': '最高', 'ms': 'Maks'},
    'rain_bar_tap_hint': {
      'th': 'แตะแท่งกราฟเพื่อดูปริมาณฝนรายชั่วโมง',
      'en': 'Tap any bar to inspect hourly rain',
      'zh': '点击柱条查看逐时降雨详情',
      'ms': 'Tekan bar untuk lihat hujan mengikut jam',
    },
    'rain_prob_label': {
      'th': 'โอกาสฝนตก',
      'en': 'Chance',
      'zh': '降雨概率',
      'ms': 'Peluang',
    },
    'watch_areas_header': {
      'th': 'พื้นที่หมู่บ้าน/ตำบลที่ต้องเฝ้าระวัง',
      'en': 'Villages & Subdistricts to Watch',
      'zh': '重点关注村庄与乡镇',
      'ms': 'Kampung & Mukim Perlu Dipantau',
    },
    'watch_areas_show_more': {
      'th': 'ดูหมู่บ้าน/ตำบลเพิ่มเติม',
      'en': 'Show more villages',
      'zh': '查看更多村庄',
      'ms': 'Lihat lagi kampung',
    },
    'watch_areas_show_less': {
      'th': 'ย่อรายชื่อพื้นที่',
      'en': 'Show fewer',
      'zh': '收起列表',
      'ms': 'Tunjuk kurang',
    },
    'affected_villages_near_station': {
      'th': 'หมู่บ้านและตำบลในพื้นที่รอบสถานี',
      'en': 'Nearby Villages & Subdistricts',
      'zh': '监测站周边村庄与乡镇',
      'ms': 'Kampung & Mukim Sekitar Stesen',
    },
    'meta_update_freq': {
      'th': 'ความถี่อัปเดตเซ็นเซอร์',
      'en': 'Sensor Update Rate',
      'zh': '传感器更新频率',
      'ms': 'Kekerapan Kemas Kini',
    },
    'chart_prev': {'th': 'ก่อนหน้า', 'en': 'Previous', 'zh': '上一轮', 'ms': 'Sebelum'},
    'chart_latest': {'th': 'ล่าสุด', 'en': 'Latest', 'zh': '最新', 'ms': 'Terkini'},
    'no_water_reading': {
      'th': 'ยังไม่มีค่าระดับน้ำ',
      'en': 'No water level reading yet',
      'zh': '暂无水位读数',
      'ms': 'Tiada bacaan paras air',
    },
    'guidance_title': {'th': 'คำแนะนำ', 'en': 'Recommended Action', 'zh': '行动建议', 'ms': 'Tindakan Disyorkan'},
    'emergency_kit_note': {
      'th': 'เตรียมถุงยังชีพ ยาประจำตัว เอกสารสำคัญ และเก็บสิ่งของให้อยู่สูงจากพื้นอย่างน้อย 1 เมตร',
      'en': 'Keep an emergency kit, essential medicine, and documents ready, and elevate valuables at least 1 meter.',
      'zh': '请备好应急包、常用药品及重要证件，并将贵重物品垫高至离地至少 1 米。',
      'ms': 'Sediakan beg kecemasan, ubat-ubatan serta dokumen penting dan letakkan barang berharga sekurang-kurangnya 1 meter tinggi.',
    },
    'request_help_btn': {
      'th': 'ดูช่องทางฉุกเฉิน (โทร / LINE / Facebook)',
      'en': 'Emergency Contacts (Call / LINE / Facebook)',
      'zh': '查看紧急联络渠道 (电话 / LINE / Facebook)',
      'ms': 'Saluran Kecemasan (Telefon / LINE / Facebook)',
    },
    'meta_station_code': {'th': 'รหัสสถานี', 'en': 'Station Code', 'zh': '监测站编号', 'ms': 'Kod Stesen'},
    'meta_location': {'th': 'อำเภอ/ตำบล', 'en': 'District / Subdistrict', 'zh': '县 / 乡镇', 'ms': 'Daerah / Mukim'},
    'meta_agency': {'th': 'หน่วยงาน', 'en': 'Agency', 'zh': '所属机构', 'ms': 'Agensi'},
    'meta_basin': {'th': 'ลุ่มน้ำ', 'en': 'Basin', 'zh': '流域', 'ms': 'Lembangan'},
    'meta_river': {'th': 'แม่น้ำ/ลำน้ำ', 'en': 'River / Canal', 'zh': '河流', 'ms': 'Sungai'},
    'meta_coords': {'th': 'พิกัด', 'en': 'Coordinates', 'zh': '坐标', 'ms': 'Koordinat'},
    'meta_bank_status': {'th': 'สถานะเทียบตลิ่ง', 'en': 'Bank Status', 'zh': '相对堤岸状态', 'ms': 'Status Tebing'},
    'station_alert_history': {
      'th': 'ประวัติแจ้งเตือนของสถานีนี้',
      'en': 'Alert History for This Station',
      'zh': '该监测站预警记录',
      'ms': 'Sejarah Amaran Stesen Ini',
    },
  };

  // ── 8 Amphoes ──────────────────────────────────────────────────────────
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

  // ── 14 Real Station Names (Short & Full) in 4 Languages ────────────────
  static const Map<String, Map<String, String>> _stationShortNames = {
    'PAT002': {'th': 'เมืองยะลา', 'en': 'Mueang Yala', 'zh': '也拉市区', 'ms': 'Mueang Yala'},
    'PAT001': {'th': 'บันนังสตา', 'en': 'Bannang Sata', 'zh': '班南沙达', 'ms': 'Bannang Sata'},
    'BLGTD01': {'th': 'ท้ายเขื่อนบางลาง', 'en': 'Dam Tailrace', 'zh': '邦朗坝下游', 'ms': 'Hilir Empangan'},
    'BLGTD02': {'th': 'สะพานหัวสะพาน', 'en': 'Hua Saphan', 'zh': '华沙攀桥', 'ms': 'Hua Saphan'},
    'BLGTD03': {'th': 'สะพานท่าสาป', 'en': 'Tha Sap Bridge', 'zh': '塔萨大桥', 'ms': 'Jambatan Tha Sap'},
    'BLGTD04': {'th': 'สูบน้ำ กปภ. ยะหา', 'en': 'PWA Yaha', 'zh': '亚哈泵站', 'ms': 'Pam PWA Yaha'},
    'BLGTU02': {'th': 'สะพาน กม.29', 'en': 'Ban KM.29', 'zh': '勿洞29公里桥', 'ms': 'Jambatan KM.29'},
    'BLGTU05': {'th': 'เขื่อนบางลาง', 'en': 'Bang Lang Dam', 'zh': '邦朗水坝', 'ms': 'Empangan Bang Lang'},
    'BLGTU06': {'th': 'ฝายละแอ', 'en': 'La-ae Weir', 'zh': '拉艾堰', 'ms': 'Empang La-ae'},
    'MOU454': {'th': 'คลองเบตง', 'en': 'Khlong Betong', 'zh': '勿洞河', 'ms': 'Sungai Betong'},
    'FOP045': {'th': 'สะพานกรงปินัง', 'en': 'Krong Pinang', 'zh': '功比南桥', 'ms': 'Krong Pinang'},
    'X.40A': {'th': 'บ้านท่าสาป', 'en': 'Ban Tha Sap', 'zh': '班塔萨', 'ms': 'Ban Tha Sap'},
    'X.273': {'th': 'บ้านปายอยือนิ', 'en': 'Ban Payo Yuni', 'zh': '班帕约尤尼', 'ms': 'Ban Payo Yuni'},
    'X.77': {'th': 'บ้านหัวสะพาน', 'en': 'Ban Hua Saphan', 'zh': '班华沙攀', 'ms': 'Ban Hua Saphan'},
  };

  static const Map<String, Map<String, String>> _stationFullNames = {
    'PAT002': {'th': 'เมืองยะลา (ตาเซะ)', 'en': 'Mueang Yala (Ta Se)', 'zh': '也拉市区（塔塞）', 'ms': 'Mueang Yala (Ta Se)'},
    'PAT001': {'th': 'บันนังสตา', 'en': 'Bannang Sata', 'zh': '班南沙达', 'ms': 'Bannang Sata'},
    'BLGTD01': {'th': 'สะพานท้ายเขื่อนบางลาง อ.บันนังสตา', 'en': 'Bang Lang Dam Tailrace Bridge', 'zh': '邦朗水坝下游大桥', 'ms': 'Jambatan Hilir Empangan Bang Lang'},
    'BLGTD02': {'th': 'สะพานหัวสะพาน อ.บันนังสตา', 'en': 'Hua Saphan Bridge (Bannang Sata)', 'zh': '班南沙达华沙攀桥', 'ms': 'Jambatan Hua Saphan (Bannang Sata)'},
    'BLGTD03': {'th': 'สะพานท่าสาป อ.เมืองยะลา', 'en': 'Tha Sap Bridge (Mueang Yala)', 'zh': '也拉塔萨大桥', 'ms': 'Jambatan Tha Sap (Mueang Yala)'},
    'BLGTD04': {'th': 'อาคารสูบน้ำดิบ กปภ. อ.ยะหา', 'en': 'PWA Water Pumping Station Yaha', 'zh': '亚哈自来水原水泵站', 'ms': 'Stesen Pam Air PWA Yaha'},
    'BLGTU02': {'th': 'สะพานบ้าน กม.29 อ.เบตง', 'en': 'Ban KM.29 Bridge (Betong)', 'zh': '勿洞29公里桥', 'ms': 'Jambatan Ban KM.29 (Betong)'},
    'BLGTU05': {'th': 'เขื่อนบางลาง อ.บันนังสตา', 'en': 'Bang Lang Dam (Bannang Sata)', 'zh': '邦朗水坝（班南沙达）', 'ms': 'Empangan Bang Lang (Bannang Sata)'},
    'BLGTU06': {'th': 'ฝายละแอ อ.บันนังสตา', 'en': 'La-ae Weir (Bannang Sata)', 'zh': '班南沙达拉艾堰', 'ms': 'Empang La-ae (Bannang Sata)'},
    'MOU454': {'th': 'คลองเบตง (ชุมชนกุนุงจนอง)', 'en': 'Khlong Betong (Kunung Chanong)', 'zh': '勿洞河（古农查农社区）', 'ms': 'Sungai Betong (Kunung Chanong)'},
    'FOP045': {'th': 'สะพานข้ามแม่น้ำปัตตานี (กรงปินัง)', 'en': 'Pattani River Bridge (Krong Pinang)', 'zh': '功比南北大年河大桥', 'ms': 'Jambatan Sungai Pattani (Krong Pinang)'},
    'X.40A': {'th': 'บ้านท่าสาป', 'en': 'Ban Tha Sap (Pattani River)', 'zh': '班塔萨站（北大年河）', 'ms': 'Ban Tha Sap (Sungai Pattani)'},
    'X.273': {'th': 'บ้านปายอยือนิ', 'en': 'Ban Payo Yuni (Sai Buri River)', 'zh': '班帕约尤尼站（赛武里河）', 'ms': 'Ban Payo Yuni (Sungai Sai Buri)'},
    'X.77': {'th': 'บ้านหัวสะพาน', 'en': 'Ban Hua Saphan (Than To)', 'zh': '班华沙攀站（丹多）', 'ms': 'Ban Hua Saphan (Than To)'},
  };

  static const Map<String, Map<String, String>> _agencies = {
    'สสน.': {'th': 'สสน.', 'en': 'HII', 'zh': '国家水文信息院 (HII)', 'ms': 'HII'},
    'กฟผ.': {'th': 'กฟผ.', 'en': 'EGAT', 'zh': '泰国发电局 (EGAT)', 'ms': 'EGAT'},
    'ชป.': {'th': 'ชป.', 'en': 'RID', 'zh': '皇家灌溉厅 (RID)', 'ms': 'RID'},
    'พพภ': {'th': 'พพภ.', 'en': 'DWR', 'zh': '水资源厅 (DWR)', 'ms': 'DWR'},
  };

  static const Map<String, Map<String, String>> _rivers = {
    'แม่น้ำปัตตานี': {'th': 'แม่น้ำปัตตานี', 'en': 'Pattani River', 'zh': '北大年河', 'ms': 'Sungai Pattani'},
    'แม่น้ำสายบุรี': {'th': 'แม่น้ำสายบุรี', 'en': 'Sai Buri River', 'zh': '赛武里河', 'ms': 'Sungai Sai Buri'},
    'เขื่อนปัตตานี': {'th': 'เขื่อนปัตตานี', 'en': 'Pattani Dam', 'zh': '北大年拦河坝', 'ms': 'Empangan Pattani'},
    'คลองใหญ่': {'th': 'คลองใหญ่', 'en': 'Khlong Yai', 'zh': '大运河 (Khlong Yai)', 'ms': 'Sungai Besar (Khlong Yai)'},
    'คลองเล็ก': {'th': 'คลองเล็ก', 'en': 'Khlong Lek', 'zh': '小运河 (Khlong Lek)', 'ms': 'Sungai Kecil (Khlong Lek)'},
    'คลองตาโล๊ะ': {'th': 'คลองตาโล๊ะ', 'en': 'Khlong Talo', 'zh': '塔洛河', 'ms': 'Sungai Talo'},
    'คลองละแอ': {'th': 'คลองละแอ', 'en': 'Khlong La-ae', 'zh': '拉艾河', 'ms': 'Sungai La-ae'},
    'ลุ่มน้ำภาคใต้ฝั่งตะวันออกตอนล่าง': {
      'th': 'ลุ่มน้ำภาคใต้ฝั่งตะวันออกตอนล่าง',
      'en': 'Lower Southern East Coast Basin',
      'zh': '泰国南部东海岸下游流域',
      'ms': 'Lembangan Pantai Timur Selatan Bawah',
    },
  };

  // ── 5 Alert Levels: Labels, Criteria & Actions (All 4 Languages · formula_version = 4) ──
  static const Map<int, Map<String, Map<String, String>>> _alertLevels = {
    1: {
      'label': {'th': 'ปกติ', 'en': 'Normal', 'zh': '正常', 'ms': 'Normal'},
      'desc': {
        'th': 'ระดับน้ำต่ำกว่าเส้นเฝ้าระวัง ปริมาณฝนและการระบายเขื่อนบางลางอยู่ในเกณฑ์ปกติ',
        'en': 'Water level is below the watch line; rainfall and Bang Lang Dam operations are normal.',
        'zh': '水位低于警戒线，降雨与邦朗水坝调度正常。',
        'ms': 'Paras air di bawah garis waspada; hujan dan operasi Empangan Bang Lang normal.',
      },
      'action': {
        'th': 'ติดตามสถานการณ์ได้ตามปกติ',
        'en': 'Monitor conditions as usual.',
        'zh': '按日常情况关注天气与水情即可。',
        'ms': 'Pantau keadaan seperti biasa.',
      },
    },
    2: {
      'label': {'th': 'เฝ้าระวัง', 'en': 'Watch', 'zh': '关注警戒', 'ms': 'Waspada'},
      'desc': {
        'th': 'ระดับน้ำแตะเส้นเฝ้าระวังและมีแนวโน้มทรงตัว (side way) หรือมีสัญญาณฝน/เขื่อนบางลางให้เฝ้าระวัง',
        'en': 'Water level has reached the watch line with a sideways/steady trend, or early rain/dam watch is active.',
        'zh': '水位触及警戒线且呈横盘平稳走势，或触发降雨/水坝关注信号。',
        'ms': 'Paras air mencecah garis waspada dengan aliran mendatar (side way), atau isyarat awal hujan/empangan aktif.',
      },
      'action': {
        'th': 'ติดตามข่าวใกล้ชิด เตรียมถุงยังชีพและชาร์จแบตเตอรี่โทรศัพท์',
        'en': 'Follow updates closely, prepare an emergency kit and charge phones.',
        'zh': '密切关注预警更新，准备应急包并保持手机电量充足。',
        'ms': 'Ikuti perkembangan rapat, sediakan beg kecemasan dan cas telefon.',
      },
    },
    3: {
      'label': {'th': 'เตือนภัย', 'en': 'Warning', 'zh': '洪水预警', 'ms': 'Amaran'},
      'desc': {
        'th': 'ระดับน้ำมีแนวโน้มสูงขึ้นอยู่ที่เส้นกึ่งกลางระหว่างเฝ้าระวังกับตลิ่ง (หรือเตือนภัยล่วงหน้าจากฝนหนัก/เขื่อนบางลาง สูงสุดระดับ 3)',
        'en': 'Water is rising at the midpoint between watch and bank lines (or non-water early warning from heavy rain/dam spillway, capped at Level 3).',
        'zh': '水位呈上涨趋势并达警戒线与堤岸线中点（或强降雨/邦朗水坝泄洪提前预警，最高3级）。',
        'ms': 'Paras air meningkat di paras pertengahan antara garis waspada dan tebing (atau amaran awal hujan lebat/empangan, had Tahap 3).',
      },
      'action': {
        'th': 'ยกของขึ้นที่สูง เตรียมเส้นทางและแผนอพยพผู้สูงอายุ/ผู้ป่วย',
        'en': 'Move valuables to higher ground and prepare evacuation routes for vulnerable family members.',
        'zh': '立即将贵重物品移至高处，提前规划老人与病患的撤离路线。',
        'ms': 'Alihkan barang ke tempat tinggi dan sediakan laluan pemindahan untuk warga emas/pesakit.',
      },
    },
    4: {
      'label': {'th': 'เตือนภัยสูง', 'en': 'High Alert', 'zh': '高度警报', 'ms': 'Amaran Tinggi'},
      'desc': {
        'th': 'ระดับน้ำสูงกว่าเส้นกึ่งกลางเข้าใกล้เส้นตลิ่ง (75%–99% ของช่วงเฝ้าระวังถึงตลิ่ง) เสี่ยงล้นตลิ่งในไม่ช้า',
        'en': 'Water level is above the midpoint and nearly reaching the bank line (75%–99% of watch-to-bank range); overflow imminent.',
        'zh': '水位高于中点并逼近堤岸线（警戒至堤岸区间的 75%–99%），即将漫堤。',
        'ms': 'Paras air melebihi garisan tengah dan hampir mencecah tebing (75%–99% julat waspada ke tebing).',
      },
      'action': {
        'th': 'พร้อมอพยพทันที ติดตามประกาศ ปภ.ยะลา (073-203559) และตัดไฟชั้นล่างหากน้ำเข้า',
        'en': 'Be ready to evacuate immediately, follow Yala DDPM (073-203559), and turn off ground-floor power if flooded.',
        'zh': '随时准备立即撤离，紧跟也拉防灾办 (073-203559) 通告，如进水立即切断底层电源。',
        'ms': 'Bersedia berpindah segera, ikuti arahan DDPM Yala (073-203559) dan matikan bekalan elektrik tingkat bawah jika dimasuki air.',
      },
    },
    5: {
      'label': {'th': 'อันตราย', 'en': 'Danger / Evacuate', 'zh': '极度危险 / 撤离', 'ms': 'Bahaya / Pindah'},
      'desc': {
        'th': 'ระดับน้ำเลยเส้นตลิ่งแล้ว พื้นที่ลุ่มต่ำและชุมชนริมน้ำกำลังถูกน้ำท่วม',
        'en': 'Water level has exceeded the bank line; low-lying and riverside communities are flooding.',
        'zh': '水位已漫过堤岸线，低洼地区及沿河社区正在受淹。',
        'ms': 'Paras air telah melepasi garis tebing; kawasan rendah dan komuniti tepi sungai sedang dilanda banjir.',
      },
      'action': {
        'th': 'อพยพทันทีไปยังศูนย์พักพิงปลอดภัย หากติดค้างโทร 1784 / 073-203559 / 1669',
        'en': 'Evacuate immediately to a safe shelter. If stranded, call 1784 / 073-203559 / 1669.',
        'zh': '立即撤离至安全避难中心！如被困请立即拨打 1784 / 073-203559 / 1669。',
        'ms': 'Berpindah segera ke pusat pemindahan selamat. Jika terkandas hubungi 1784 / 073-203559 / 1669.',
      },
    },
  };

  // ── 12 Shelters Translation Map (keyed by Thai name) ───────────────────
  static const Map<String, Map<String, List<String>>> _shelters = {
    'อาคารเรียนรู้ TK Park ยะลา (หลังเก่า)': {
      'en': ['TK Park Yala Learning Building (Old Wing)', 'Yala City Municipality, Mueang Yala', 'Main temporary evacuation center in Yala City Municipality'],
      'zh': ['也拉 TK Park 学习大楼（旧楼）', '也拉直辖县也拉市政府辖区', '也拉市政府主要临时避难中心'],
      'ms': ['Bangunan Pembelajaran TK Park Yala (Lama)', 'Perbandaran Bandar Yala, Mueang Yala', 'Pusat pemindahan sementara utama Perbandaran Yala'],
    },
    'โรงเรียนเทศบาล 2 (มลายูบางกอก)': {
      'en': ['Municipal School 2 (Malayu Bangkok)', 'Yala City Municipality, Mueang Yala', 'Temporary evacuation center in Yala City Municipality'],
      'zh': ['也拉市立第二学校 (Malayu Bangkok)', '也拉直辖县也拉市政府辖区', '也拉市政府临时避难中心'],
      'ms': ['Sekolah Perbandaran 2 (Malayu Bangkok)', 'Perbandaran Bandar Yala, Mueang Yala', 'Pusat pemindahan sementara Perbandaran Yala'],
    },
    'โรงเรียนเทศบาล 3 (วัดพุทธภูมิ)': {
      'en': ['Municipal School 3 (Wat Phutthaphum)', 'Yala City Municipality, Mueang Yala', 'Temporary evacuation center in Yala City Municipality'],
      'zh': ['也拉市立第三学校（佛土寺）', '也拉直辖县也拉市政府辖区', '也拉市政府临时避难中心'],
      'ms': ['Sekolah Perbandaran 3 (Wat Phutthaphum)', 'Perbandaran Bandar Yala, Mueang Yala', 'Pusat pemindahan sementara Perbandaran Yala'],
    },
    'มัสยิดกลางประจำจังหวัดยะลา': {
      'en': ['Yala Provincial Central Mosque', 'Sirorot Rd, Sateng, Mueang Yala', 'Temporary evacuation center in Yala City Municipality'],
      'zh': ['也拉府中央清真寺', '也拉直辖县萨登区 Sirorot 路', '也拉市政府临时避难中心'],
      'ms': ['Masjid Besar Wilayah Yala', 'Jalan Sirorot, Sateng, Mueang Yala', 'Pusat pemindahan sementara Perbandaran Yala'],
    },
    'วัดนิโรธสังฆาราม (ต.สะเตง)': {
      'en': ['Wat Nirot Sangkharam (Sateng)', 'Sateng Subdistrict, Mueang Yala', 'Previously opened as flood shelter & relief kitchen (2024)'],
      'zh': ['尼罗僧伽兰寺（萨登区）', '也拉直辖县萨登区', '2024 年洪灾期间曾开设为避难中心与义厨点'],
      'ms': ['Wat Nirot Sangkharam (Sateng)', 'Mukim Sateng, Mueang Yala', 'Pernah dibuka sebagai pusat pemindahan & dapur bantuan banjir (2024)'],
    },
    'วัดรังสิตาวาส (ต.กายูบอเกาะ)': {
      'en': ['Wat Rangsitawas (Kayu Boko)', 'Kayu Boko, Raman, Yala', 'Historical flood shelter & relief kitchen for Raman (2024)'],
      'zh': ['朗西塔瓦寺（加尤波哥区）', '也拉府拉曼县加尤波哥区', '2024 年拉曼县洪灾历史避难中心与义厨点'],
      'ms': ['Wat Rangsitawas (Kayu Boko)', 'Kayu Boko, Raman, Yala', 'Pusat pemindahan & dapur bantuan banjir sejarah Raman (2024)'],
    },
    'อาคารอเนกประสงค์ เทศบาลตำบลยะหา / หอประชุมที่ว่าการอำเภอยะหา': {
      'en': ['Yaha Subdistrict Municipality Hall / Yaha District Hall', 'Yaha Subdistrict, Yaha, Yala', 'Historical command & temporary evacuation site for Yaha'],
      'zh': ['亚哈镇市政多功能厅 / 亚哈县政府礼堂', '也拉府亚哈县亚哈区', '亚哈县应急预案指挥与临时避难点'],
      'ms': ['Dewan Serbaguna Perbandaran Yaha / Dewan Daerah Yaha', 'Mukim Yaha, Yaha, Yala', 'Pusat operasi & pemindahan sementara mengikut pelan kontinjensi Yaha'],
    },
    'อาคารอเนกประสงค์ อบต.กรงปินัง / ที่ว่าการอำเภอกรงปินัง': {
      'en': ['Krong Pinang SAO Hall / Krong Pinang District Office', 'Krong Pinang, Yala', 'Flash flood evacuation site under Krong Pinang contingency plan'],
      'zh': ['功比南地方行政机构礼堂 / 功比南县政府', '也拉府功比南县', '功比南县山洪应急预案指定避难点'],
      'ms': ['Dewan Serbaguna SAO Krong Pinang / Pejabat Daerah Krong Pinang', 'Krong Pinang, Yala', 'Lokasi pemindahan banjir kilat mengikut pelan Krong Pinang'],
    },
    'หอประชุมที่ว่าการอำเภอบันนังสตา / เทศบาลตำบลบันนังสตา': {
      'en': ['Bannang Sata District Hall / Bannang Sata Municipality', 'Bannang Sata, Yala', 'Downstream Bang Lang Dam evacuation site for Bannang Sata'],
      'zh': ['班南沙达县政府礼堂 / 班南沙达镇市政厅', '也拉府班南沙达县', '邦朗水坝下游应急预案避难点'],
      'ms': ['Dewan Daerah Bannang Sata / Perbandaran Bannang Sata', 'Bannang Sata, Yala', 'Lokasi pemindahan hilir Empangan Bang Lang bagi Bannang Sata'],
    },
    'อาคารอเนกประสงค์ เทศบาลเมืองเบตง / ศูนย์เยาวชนเทศบาลเมืองเบตง': {
      'en': ['Betong Town Municipality Hall / Betong Youth Center', 'Betong, Yala', 'Temporary shelter for flash floods & landslides in Betong (2024)'],
      'zh': ['勿洞市多功能礼堂 / 勿洞市青年中心', '也拉府勿洞县', '2024 年勿洞山洪及滑坡临时避难点'],
      'ms': ['Dewan Serbaguna Bandar Betong / Pusat Belia Betong', 'Betong, Yala', 'Pusat pemindahan banjir kilat & tanah runtuh Betong (2024)'],
    },
    'หอประชุมที่ว่าการอำเภอธารโต / อาคารอเนกประสงค์ อบต.ธารโต': {
      'en': ['Than To District Hall / Than To SAO Multipurpose Hall', 'Than To, Yala', 'Safe highland shelter for flash flood zones in Than To'],
      'zh': ['丹多县政府礼堂 / 丹多地方行政机构礼堂', '也拉府丹多县', '丹多县山洪风险区安全避难点'],
      'ms': ['Dewan Daerah Than To / Dewan Serbaguna SAO Than To', 'Than To, Yala', 'Lokasi selamat untuk kawasan berisiko banjir kilat Than To'],
    },
    'หอประชุมที่ว่าการอำเภอกาบัง / อาคารอเนกประสงค์ อบต.กาบัง': {
      'en': ['Kabang District Hall / Kabang SAO Multipurpose Hall', 'Kabang, Yala', 'Safe shelter for flash flood zones in Kabang'],
      'zh': ['加邦县政府礼堂 / 加邦地方行政机构礼堂', '也拉府加邦县', '加邦县山洪风险区安全避难点'],
      'ms': ['Dewan Daerah Kabang / Dewan Serbaguna SAO Kabang', 'Kabang, Yala', 'Lokasi selamat untuk kawasan berisiko banjir kilat Kabang'],
    },
  };

  // ── 9 Emergency Contacts Translation Map ───────────────────────────────
  static const Map<String, Map<String, List<String>>> _contacts = {
    '1784': {
      'th': ['สายด่วนนิรภัย กรม ปภ. (DDPM)', 'โทรฟรี 24 ชม.'],
      'en': ['DDPM Disaster Hotline (1784)', 'Toll-free 24/7'],
      'zh': ['泰国防灾减灾厅热线 (DDPM 1784)', '24小时免费热线'],
      'ms': ['Talian Kecemasan Bencana DDPM (1784)', 'Percuma 24 jam'],
    },
    '073203559': {
      'th': ['สำนักงาน ปภ. จังหวัดยะลา', '073-203559–64 / 073-203562'],
      'en': ['Yala Provincial DDPM Office', '073-203559–64 / 073-203562'],
      'zh': ['也拉府防灾减灾办公室', '073-203559–64 / 073-203562'],
      'ms': ['Pejabat DDPM Wilayah Yala', '073-203559–64 / 073-203562'],
    },
    '073212345': {
      'th': ['งาน ปภ. เทศบาลนครยะลา', 'ช่วยเหลือน้ำท่วมเขตเมืองยะลา 24 ชม.'],
      'en': ['Yala City Municipality Rescue', 'Yala city flood response 24/7'],
      'zh': ['也拉市政府防灾救援队', '也拉市区24小时防洪救援'],
      'ms': ['Unit Bencana Perbandaran Bandar Yala', 'Bantuan banjir bandar Yala 24 jam'],
    },
    '1669': {
      'th': ['สายด่วนการแพทย์ฉุกเฉิน (สพฉ.)', 'เจ็บป่วยฉุกเฉิน / กู้ชีพ 24 ชม.'],
      'en': ['Emergency Medical Services (1669)', 'Ambulance & life support 24/7'],
      'zh': ['泰国紧急医疗急救热线 (1669)', '24小时医疗急救 / 救护车'],
      'ms': ['Perkhidmatan Perubatan Kecemasan (1669)', 'Kecemasan perubatan / ambulans 24 jam'],
    },
    '073228934': {
      'th': ['โรงพยาบาลยะลา', 'ฉุกเฉินทางการแพทย์ 24 ชม.'],
      'en': ['Yala Hospital', '24/7 Medical Emergency'],
      'zh': ['也拉医院', '24小时医疗急诊'],
      'ms': ['Hospital Yala', 'Kecemasan Perubatan 24 jam'],
    },
    '199': {
      'th': ['แจ้งเหตุเพลิงไหม้ / สาธารณภัย', 'สายด่วน 199 (24 ชม.)'],
      'en': ['Fire & Public Disaster (199)', '24/7 Emergency Hotline'],
      'zh': ['消防与公共灾害报警 (199)', '24小时紧急热线'],
      'ms': ['Bomba & Bencana Awam (199)', 'Talian Kecemasan 24 jam'],
    },
    '073340141': {
      'th': ['ศูนย์บรรเทาสาธารณภัย มทบ.46', 'ช่วยเหลือประชาชนช่วงภัยพิบัติ 24 ชม.'],
      'en': ['46th Military Circle Disaster Relief', 'Disaster rescue support 24/7'],
      'zh': ['第46军区救灾指挥中心', '24小时军方抗洪救援'],
      'ms': ['Pusat Bantuan Bencana Tentera MTB 46', 'Bantuan bencana awam 24 jam'],
    },
    '191': {
      'th': ['เหตุด่วนเหตุร้าย (ตำรวจ)', 'สายด่วนตำรวจ 191 (24 ชม.)'],
      'en': ['Emergency Police (191)', '24/7 Police Hotline'],
      'zh': ['泰国报警电话 (191)', '24小时警方急救热线'],
      'ms': ['Polis Kecemasan (191)', 'Talian Kecemasan Polis 24 jam'],
    },
    '1677': {
      'th': ['ร่วมด้วยช่วยกัน (อาสาสมัคร)', 'เครือข่ายอาสาสมัคร 24 ชม. (ไม่ใช่เบอร์ ปภ.)'],
      'en': ['Ruam Duay Chuay Kan (Volunteers)', '24/7 Volunteer Network (non-DDPM)'],
      'zh': ['民间志愿救援热线 (1677)', '24小时志愿者网络（非官方防灾办）'],
      'ms': ['Rangkaian Sukarelawan 1677', 'Sukarelawan 24 jam (bukan DDPM)'],
    },
  };

  // ── SOS Types & Statuses ───────────────────────────────────────────────
  static const Map<String, Map<String, String>> _sosTypes = {
    'น้ำท่วมบ้าน/ชุมชน': {
      'th': 'น้ำท่วมบ้าน/ชุมชน',
      'en': 'Home / Community Flooded',
      'zh': '房屋/社区进水',
      'ms': 'Rumah / Komuniti Dinaiki Air',
    },
    'ต้องการพาตัวอพยพ': {
      'th': 'ต้องการพาตัวอพยพ',
      'en': 'Evacuation Needed',
      'zh': '需要协助撤离',
      'ms': 'Perlukan Bantuan Pemindahan',
    },
    'ต้องการอาหาร/น้ำดื่ม': {
      'th': 'ต้องการอาหาร/น้ำดื่ม',
      'en': 'Food / Drinking Water',
      'zh': '需要食物/饮用水',
      'ms': 'Perlukan Makanan / Air Minuman',
    },
    'ป่วย/ต้องการยา': {
      'th': 'ป่วย/ต้องการยา',
      'en': 'Medical / Medicine Needed',
      'zh': '生病/急需药品',
      'ms': 'Sakit / Perlukan Ubat',
    },
    'อุบัติเหตุบนน้ำ': {
      'th': 'อุบัติเหตุบนน้ำ',
      'en': 'Water / Boat Accident',
      'zh': '水上事故',
      'ms': 'Kemalangan Di Air',
    },
    'อื่น ๆ': {'th': 'อื่น ๆ', 'en': 'Other', 'zh': '其他', 'ms': 'Lain-lain'},
  };

  // ── Flood Mechanism & Confidence Labels ────────────────────────────────
  static const Map<String, Map<String, String>> _mechanisms = {
    'dam_release': {
      'th': 'การระบายน้ำเขื่อนบางลาง',
      'en': 'Bang Lang Dam Release',
      'zh': '邦朗水坝泄洪影响',
      'ms': 'Pelepasan Empangan Bang Lang',
    },
    'urban_pluvial': {
      'th': 'ฝนตกหนักเสี่ยงน้ำท่วมขังเขตเมือง',
      'en': 'Heavy Urban Rain / Drainage Flood',
      'zh': '城区强降雨内涝风险',
      'ms': 'Risiko Banjir Kilat Bandar',
    },
    'flash_flood': {
      'th': 'น้ำป่าไหลหลากจากพื้นที่ลาดเขา',
      'en': 'Mountain Flash Flood Risk',
      'zh': '山区山洪暴发风险',
      'ms': 'Risiko Banjir Kilat / Kepala Air',
    },
    'riverine_overflow': {
      'th': 'ระดับน้ำแม่น้ำใกล้/ล้นตลิ่ง',
      'en': 'River Overflow Risk',
      'zh': '河流水位漫堤风险',
      'ms': 'Risiko Limpahan Sungai',
    },
    'monitoring': {
      'th': 'เฝ้าระวังตามปกติ',
      'en': 'Routine Monitoring',
      'zh': '常规监测中',
      'ms': 'Pemantauan Biasa',
    },
  };

  String get(String key) => _dict[key]?[lang] ?? _dict[key]?['th'] ?? key;

  String amphoe(String thName) => _amphoes[thName]?[lang] ?? thName;

  String amphoePrefixed(String thName) {
    final name = amphoe(thName);
    if (lang == 'th') return 'อ.$name';
    if (lang == 'ms') return 'Daerah $name';
    return name;
  }

  String tumbonName(String thName, [String? enName]) {
    if (lang == 'th') return 'ต.$thName';
    final cleanEn = (enName ?? '').trim();
    if (cleanEn.isEmpty) return thName;
    if (lang == 'ms') return 'Mukim $cleanEn';
    return cleanEn;
  }

  String villageName(int moo, String thName, [String? enName]) {
    if (lang == 'th') return moo > 0 ? 'ม.$moo $thName' : thName;
    final cleanEn = (enName ?? '').trim();
    final base = cleanEn.isNotEmpty ? cleanEn : thName;
    if (lang == 'zh') return moo > 0 ? '第$moo村 $base' : base;
    if (lang == 'ms') return moo > 0 ? 'Kg.$moo $base' : base;
    return moo > 0 ? 'Moo $moo $base' : base;
  }

  String stationShortName(Station station) {
    final mapped = _stationShortNames[station.code]?[lang];
    if (mapped != null && mapped.isNotEmpty) return mapped;
    if (lang != 'th' && station.nameEn.trim().isNotEmpty) return station.nameEn.trim();
    final th = station.nameTh.trim();
    return th.isNotEmpty ? th : station.code;
  }

  String stationFullName(Station station) {
    final mapped = _stationFullNames[station.code]?[lang];
    if (mapped != null && mapped.isNotEmpty) return mapped;
    if (lang != 'th' && station.nameEn.trim().isNotEmpty) return station.nameEn.trim();
    final th = station.nameTh.trim();
    return th.isNotEmpty ? th : station.code;
  }

  String agencyName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return get('unknown');
    final key = raw.trim();
    return _agencies[key]?[lang] ?? key;
  }

  String riverName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return get('unknown');
    final key = raw.trim();
    return _rivers[key]?[lang] ?? key;
  }

  String stationLocation(Station station) {
    final parts = <String>[
      if ((station.amphoeTh ?? '').isNotEmpty) amphoePrefixed(station.amphoeTh!),
      if ((station.tumbonTh ?? '').isNotEmpty && lang == 'th') 'ต.${station.tumbonTh}',
    ];
    return parts.isEmpty ? get('yala_province') : parts.join(' ');
  }

  String alertLevelLabel(int level) {
    final clamped = level.clamp(1, 5);
    return _alertLevels[clamped]?['label']?[lang] ?? AlertLevel.fromValue(clamped).labelTh;
  }

  String alertLevelDesc(int level) {
    final clamped = level.clamp(1, 5);
    return _alertLevels[clamped]?['desc']?[lang] ?? '';
  }

  String alertLevelAction(int level) {
    final clamped = level.clamp(1, 5);
    return _alertLevels[clamped]?['action']?[lang] ?? AlertLevel.fromValue(clamped).guidanceTh;
  }

  String riskLevelLabel(RiskLevel level) {
    return switch (level) {
      RiskLevel.normal => alertLevelLabel(1),
      RiskLevel.watch => alertLevelLabel(2),
      RiskLevel.warning => alertLevelLabel(3),
      RiskLevel.high => alertLevelLabel(4),
      RiskLevel.danger => alertLevelLabel(5),
      RiskLevel.unknown => get('unknown'),
    };
  }

  String waterTrendLabel(WaterTrend trend) {
    return switch (trend) {
      WaterTrend.rising => switch (lang) {
          'en' => 'Rising',
          'zh' => '上涨中',
          'ms' => 'Meningkat',
          _ => 'กำลังขึ้น',
        },
      WaterTrend.falling => switch (lang) {
          'en' => 'Falling',
          'zh' => '下降中',
          'ms' => 'Menurun',
          _ => 'กำลังลง',
        },
      WaterTrend.steady => switch (lang) {
          'en' => 'Steady',
          'zh' => '平稳',
          'ms' => 'Stabil',
          _ => 'คงที่',
        },
      WaterTrend.unknown => get('unknown'),
    };
  }

  String mechanismLabel(String code) => _mechanisms[code]?[lang] ?? _mechanisms['monitoring']![lang]!;

  String shelterName(String thName) =>
      lang == 'th' ? thName : (_shelters[thName]?[lang]?[0] ?? thName);

  String shelterAddress(String thName, String fallbackTh) =>
      lang == 'th' ? fallbackTh : (_shelters[thName]?[lang]?[1] ?? fallbackTh);

  String shelterNotes(String thName, String fallbackTh) =>
      lang == 'th' ? fallbackTh : (_shelters[thName]?[lang]?[2] ?? fallbackTh);

  String contactTitle(String number, String fallbackTh) =>
      _contacts[number]?[lang]?[0] ?? fallbackTh;

  String contactSubtitle(String number, String fallbackTh) =>
      _contacts[number]?[lang]?[1] ?? fallbackTh;

  String sosTypeLabel(String thType) => _sosTypes[thType]?[lang] ?? thType;

  String sosStatusLabel(SosStatus status) {
    return switch (status) {
      SosStatus.pending => switch (lang) {
          'en' => 'Pending',
          'zh' => '待处理',
          'ms' => 'Menunggu',
          _ => 'รอตอบรับ',
        },
      SosStatus.accepted => switch (lang) {
          'en' => 'Received',
          'zh' => '已受理',
          'ms' => 'Diterima',
          _ => 'รับเรื่องแล้ว',
        },
      SosStatus.inProgress => switch (lang) {
          'en' => 'Dispatched',
          'zh' => '救援途中',
          'ms' => 'Bantuan Dihantar',
          _ => 'กำลังส่งช่วยเหลือ',
        },
      SosStatus.resolved => switch (lang) {
          'en' => 'Resolved',
          'zh' => '已获救',
          'ms' => 'Selesai',
          _ => 'ช่วยเหลือแล้ว',
        },
    };
  }

  String remainingToBankText(double remaining) {
    final absVal = remaining.abs().toStringAsFixed(2);
    if (remaining >= 0) {
      return switch (lang) {
        'en' => '$absVal m below bank',
        'zh' => '距堤岸还差 $absVal 米',
        'ms' => '$absVal m di bawah tebing',
        _ => 'เหลือ $absVal ม. ถึงตลิ่ง',
      };
    }
    return switch (lang) {
      'en' => 'Overflowing by $absVal m',
      'zh' => '已漫过堤岸 $absVal 米',
      'ms' => 'Melimpahi tebing $absVal m',
      _ => 'ล้นตลิ่ง $absVal ม.',
    };
  }

  String elevationMarginText(double margin) {
    final absVal = margin.abs().toStringAsFixed(1);
    if (margin <= 0) {
      return switch (lang) {
        'en' => '$absVal m below river level',
        'zh' => '低于参考河流水位 $absVal 米',
        'ms' => '$absVal m di bawah paras sungai',
        _ => 'ต่ำกว่าระดับน้ำ $absVal ม.',
      };
    }
    return switch (lang) {
      'en' => '+$absVal m above river level',
      'zh' => '高于参考河流水位 +$absVal 米',
      'ms' => '+$absVal m di atas paras sungai',
      _ => 'สูงกว่าระดับน้ำ +$absVal ม.',
    };
  }

  String stationGuidance(RiskLevel level, String amphoeTh) {
    final int lv = switch (level) {
      RiskLevel.danger => 5,
      RiskLevel.high => 4,
      RiskLevel.warning => 3,
      RiskLevel.watch => 2,
      RiskLevel.normal => 1,
      RiskLevel.unknown => 1,
    };
    return alertLevelAction(lv);
  }

  String countItems(int n) {
    return switch (lang) {
      'en' => '$n items',
      'zh' => '共 $n 条',
      'ms' => '$n rekod',
      _ => 'มี $n รายการ',
    };
  }

  String formatHourLabel(String hhmm) {
    return switch (lang) {
      'th' => '$hhmm น.',
      _ => hhmm,
    };
  }

  String formatTime(DateTime dt, {bool includeDate = true}) {
    final th = dt.toUtc().add(const Duration(hours: 7));
    final hh = th.hour.toString().padLeft(2, '0');
    final mm = th.minute.toString().padLeft(2, '0');
    final dd = th.day.toString().padLeft(2, '0');
    final mo = th.month.toString().padLeft(2, '0');
    if (lang == 'th') {
      if (!includeDate) return '$hh:$mm น. (UTC+7)';
      return '$dd/$mo $hh:$mm น. (เวลาไทย UTC+7)';
    }
    if (!includeDate) return '$hh:$mm (UTC+7)';
    return '$dd/$mo $hh:$mm (${get('updated_tz')})';
  }

  String relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) {
      return switch (lang) {
        'en' => 'Just now',
        'zh' => '刚刚',
        'ms' => 'Sebentar tadi',
        _ => 'เมื่อสักครู่',
      };
    }
    if (diff.inMinutes < 60) {
      return switch (lang) {
        'en' => '${diff.inMinutes}m ago',
        'zh' => '${diff.inMinutes} 分钟前',
        'ms' => '${diff.inMinutes} minit lalu',
        _ => '${diff.inMinutes} นาทีที่แล้ว',
      };
    }
    if (diff.inHours < 24) {
      return switch (lang) {
        'en' => '${diff.inHours}h ago',
        'zh' => '${diff.inHours} 小时前',
        'ms' => '${diff.inHours} jam lalu',
        _ => '${diff.inHours} ชั่วโมงที่แล้ว',
      };
    }
    return switch (lang) {
      'en' => '${diff.inDays}d ago',
      'zh' => '${diff.inDays} 天前',
      'ms' => '${diff.inDays} hari lalu',
      _ => '${diff.inDays} วันที่แล้ว',
    };
  }

  String communityReportTypeLabel(String type) {
    return switch (type) {
      'water_rising' => switch (lang) {
          'en' => 'Water Rising',
          'zh' => '水位上涨',
          'ms' => 'Air Naik',
          _ => 'น้ำกำลังขึ้น',
        },
      'road_flooded' => switch (lang) {
          'en' => 'Road Flooded',
          'zh' => '道路积水',
          'ms' => 'Jalan Dinaiki Air',
          _ => 'ถนนถูกน้ำท่วม',
        },
      'flash_flood' => switch (lang) {
          'en' => 'Flash Flood / Runoff',
          'zh' => '山洪 / 暴涨',
          'ms' => 'Banjir Kilat',
          _ => 'น้ำป่าไหลหลาก',
        },
      'landslide' => switch (lang) {
          'en' => 'Landslide',
          'zh' => '山体滑坡',
          'ms' => 'Tanah Runtuh',
          _ => 'ดินโคลนถล่ม',
        },
      'shelter_full' => switch (lang) {
          'en' => 'Shelter Full',
          'zh' => '避难所已满',
          'ms' => 'Pusat Pemindahan Penuh',
          _ => 'ศูนย์พักพิงเต็ม',
        },
      _ => type,
    };
  }

  String sosDispatchedViaLabel(String channel) {
    return switch (channel) {
      'sms' => switch (lang) {
          'en' => 'Sent via SMS',
          'zh' => '已通过短信发送',
          'ms' => 'Dihantar melalui SMS',
          _ => 'ส่งผ่าน SMS แล้ว',
        },
      'line' => switch (lang) {
          'en' => 'Shared via LINE',
          'zh' => '已通过 LINE 分享',
          'ms' => 'Dikongsi melalui LINE',
          _ => 'ส่งผ่าน LINE แล้ว',
        },
      'clipboard' => switch (lang) {
          'en' => 'Copied SOS',
          'zh' => '已复制 SOS 信息',
          'ms' => 'SOS Disalin',
          _ => 'คัดลอกข้อความแล้ว',
        },
      'call' => switch (lang) {
          'en' => 'Emergency Called',
          'zh' => '已拨打急救电话',
          'ms' => 'Panggilan Kecemasan',
          _ => 'โทรแจ้งเหตุแล้ว',
        },
      _ => channel,
    };
  }

  /// จัดรูปแบบเบอร์โทรศัพท์จังหวัดยะลาให้อ่านง่าย เช่น `073212345` → `073-212345`
  static String formatPhoneDisplay(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 9 && digits.startsWith('0')) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    if (digits.length == 10 && digits.startsWith('0')) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return raw.trim();
  }

  /// ข้อความปุ่มโทรในหน้าศูนย์พักพิง พร้อมแสดงเบอร์โทรจริง เช่น `กดโทร 073-212345`
  String callShelterWithNumber(String rawPhone) {
    final formatted = formatPhoneDisplay(rawPhone);
    return switch (lang) {
      'en' => 'Call $formatted',
      'zh' => '致电 $formatted',
      'ms' => 'Hubungi $formatted',
      _ => 'กดโทร $formatted',
    };
  }

  /// ข้อความแสดงความถี่อัปเดตของสถานีวัดระดับน้ำ
  String updateCadenceLabel(int minutes) {
    if (minutes <= 10) {
      return switch (lang) {
        'en' => 'Updates every 10 min',
        'zh' => '每10分钟更新',
        'ms' => 'Kemas kini setiap 10 min',
        _ => 'อัปเดตทุก 10 นาที',
      };
    }
    if (minutes < 60) {
      return switch (lang) {
        'en' => 'Updates every $minutes min',
        'zh' => '每$minutes分钟更新',
        'ms' => 'Kemas kini setiap $minutes min',
        _ => 'อัปเดตทุก $minutes นาที',
      };
    }
    return switch (lang) {
      'en' => 'Updates hourly',
      'zh' => '每小时更新',
      'ms' => 'Kemas kini setiap jam',
      _ => 'อัปเดตทุก 1 ชม.',
    };
  }

  /// แปลงเวลาใดๆ เป็นเวลาประเทศไทย (UTC+7) ชัดเจนเสมอ (คงชื่อเดิมเพื่อความเข้ากันย้อนหลัง)
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
