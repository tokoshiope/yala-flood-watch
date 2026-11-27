import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// หน้าคู่มือการใช้งานแอปและคู่มือการเตรียมพร้อมอพยพหนีน้ำท่วม (Offline-First 100%)
/// - ฝังข้อมูลหลักไว้ในแอปเพื่อให้ประชาชนเปิดอ่านได้ทันทีแม้เครือข่ายอินเทอร์เน็ตล่มระหว่างอุทกภัย
/// - เสริมปุ่มเปิดฉบับเว็บ (web/guide.html) สำหรับแชร์หรือพิมพ์แจกจ่ายในชุมชน
/// - แนวทางปฏิบัติอ้างอิงหลักการทางการจากกรมป้องกันและบรรเทาสาธารณภัย (ปภ.) และ สพฉ. 1669
class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, this.initialTab = 0});

  /// 0 = คู่มือการใช้งานแอป, 1 = คู่มือการเตรียมพร้อมและอพยพ
  final int initialTab;

  Future<void> _call(BuildContext context, String number, AppStrings strings) async {
    final sanitized = number.replaceAll(RegExp(r'[^0-9+*#]'), '');
    if (sanitized.isEmpty) return;
    final ok = await launchUrl(
      Uri(scheme: 'tel', path: sanitized),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.get('cannot_call')} ($number)')),
      );
    }
  }

  Future<void> _openWebGuide(BuildContext context, AppStrings strings) async {
    final uri = Uri.tryParse(AppConfig.webGuideUrl);
    if (uri == null || uri.scheme != 'https') return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.get('cannot_open_link'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AlertProvider>().strings;
    final safeInitial = initialTab.clamp(0, 1);

    return DefaultTabController(
      length: 2,
      initialIndex: safeInitial,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.get('guide_title')),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                text: strings.get('guide_tab_app'),
              ),
              Tab(
                icon: const Icon(Icons.directions_run_rounded, size: 18),
                text: strings.get('guide_tab_evac'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _AppGuideTab(
              strings: strings,
              onOpenWeb: () => _openWebGuide(context, strings),
            ),
            _EvacuationGuideTab(
              strings: strings,
              onCall: (numStr) => _call(context, numStr, strings),
              onOpenWeb: () => _openWebGuide(context, strings),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppGuideTab extends StatelessWidget {
  const _AppGuideTab({required this.strings, required this.onOpenWeb});

  final AppStrings strings;
  final VoidCallback onOpenWeb;

  @override
  Widget build(BuildContext context) {
    final lang = strings.lang;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final steps = _appGuideSteps(lang);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _OfflineNoticeBanner(strings: strings, isDark: isDark),
        const SizedBox(height: 12),
        for (final step in steps) ...[
          _GuideSectionCard(
            icon: step.icon,
            accentColor: cs.primary,
            title: step.title,
            bullets: step.bullets,
          ),
          const SizedBox(height: 10),
        ],
        _AlertScaleCompactCard(strings: strings),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpenWeb,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(strings.get('guide_open_web')),
        ),
      ],
    );
  }
}

class _EvacuationGuideTab extends StatelessWidget {
  const _EvacuationGuideTab({
    required this.strings,
    required this.onCall,
    required this.onOpenWeb,
  });

  final AppStrings strings;
  final ValueChanged<String> onCall;
  final VoidCallback onOpenWeb;

  @override
  Widget build(BuildContext context) {
    final lang = strings.lang;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sections = _evacuationSections(lang);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _OfflineNoticeBanner(strings: strings, isDark: isDark),
        const SizedBox(height: 12),
        for (final sec in sections) ...[
          _GuideSectionCard(
            icon: sec.icon,
            accentColor: sec.color,
            title: sec.title,
            bullets: sec.bullets,
          ),
          const SizedBox(height: 10),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.phone_in_talk_rounded,
                      color: isDark
                          ? const Color(0xFFFF8A80)
                          : const Color(AppConfig.colorDanger),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _quickCallHeading(lang),
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickCallButton(
                      label: _quickCallLabel(lang, 'ddpm'),
                      onTap: () => onCall(AppConfig.emergencyDDPM),
                    ),
                    _QuickCallButton(
                      label: _quickCallLabel(lang, 'yala_ddpm'),
                      onTap: () => onCall(AppConfig.emergencyYalaCenter),
                    ),
                    _QuickCallButton(
                      label: _quickCallLabel(lang, 'yala_city'),
                      onTap: () => onCall(AppConfig.emergencyYalaMunicipality),
                    ),
                    _QuickCallButton(
                      label: _quickCallLabel(lang, 'niems'),
                      onTap: () => onCall(AppConfig.emergencyMedical),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _SourceAttributionNote(lang: lang),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onOpenWeb,
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(strings.get('guide_open_web')),
        ),
      ],
    );
  }
}

class _OfflineNoticeBanner extends StatelessWidget {
  const _OfflineNoticeBanner({required this.strings, required this.isDark});

  final AppStrings strings;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF102A43) : const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF7DD3FC),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.offline_pin_outlined,
            size: 20,
            color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.get('guide_offline_badge'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFE0F2FE) : const Color(0xFF0C4A6E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSectionCard extends StatelessWidget {
  const _GuideSectionCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.bullets,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final b in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        b,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlertScaleCompactCard extends StatelessWidget {
  const _AlertScaleCompactCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.get('alert_guide_section'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            for (final lv in AlertLevel.values) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lv.color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${lv.value}',
                      style: TextStyle(
                        color: lv.onSolidColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.alertLevelLabel(lv.value),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: lv.colorFor(brightness),
                          ),
                        ),
                        Text(
                          strings.alertLevelDesc(lv.value),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (lv != AlertLevel.danger) const Divider(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickCallButton extends StatelessWidget {
  const _QuickCallButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(AppConfig.colorDanger),
        foregroundColor: Colors.white,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onTap,
      icon: const Icon(Icons.call, size: 15),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _SourceAttributionNote extends StatelessWidget {
  const _SourceAttributionNote({required this.lang});

  final String lang;

  @override
  Widget build(BuildContext context) {
    final text = switch (lang) {
      'en' =>
        'Reference: Department of Disaster Prevention and Mitigation (DDPM, Hotline 1784) & National Institute for Emergency Medicine (NIEMS 1669), Thailand.',
      'zh' =>
        '参考来源：泰国防灾减灾厅 (DDPM 热线 1784) 及国家急救医学研究所 (NIEMS 1669) 官方洪灾应对指南。',
      'ms' =>
        'Rujukan: Jabatan Pencegahan dan Mitigasi Bencana Thailand (DDPM 1784) & Institut Perubatan Kecemasan Kebangsaan (NIEMS 1669).',
      _ =>
        'แหล่งอ้างอิงแนวทางปฏิบัติ: คู่มือปฏิบัติตนเมื่อเกิดอุทกภัย กรมป้องกันและบรรเทาสาธารณภัย (ปภ. สายด่วน 1784) กระทรวงมหาดไทย และสถาบันการแพทย์ฉุกเฉินแห่งชาติ (สพฉ. 1669)',
    };
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
    );
  }
}

class _GuideItem {
  const _GuideItem({
    required this.icon,
    required this.title,
    required this.bullets,
    this.color = const Color(AppConfig.colorPrimary),
  });

  final IconData icon;
  final String title;
  final List<String> bullets;
  final Color color;
}

String _quickCallHeading(String lang) => switch (lang) {
      'en' => 'Verified Emergency Hotlines (1-Tap Call)',
      'zh' => '已核实官方紧急求助热线（一键拨打）',
      'ms' => 'Talian Kecemasan Rasmi Disahkan (Panggilan 1 Sentuhan)',
      _ => 'หมายเลขโทรศัพท์ฉุกเฉินที่ตรวจสอบยืนยันแล้ว (กดโทรได้ทันที)',
    };

String _quickCallLabel(String lang, String key) {
  return switch (key) {
    'ddpm' => switch (lang) {
        'en' => '1784 (DDPM)',
        'zh' => '1784 (防灾热线)',
        'ms' => '1784 (DDPM)',
        _ => '1784 (ปภ.)',
      },
    'yala_ddpm' => switch (lang) {
        'en' => '${AppConfig.emergencyYalaCenterDisplay} (Yala DDPM)',
        'zh' => '${AppConfig.emergencyYalaCenterDisplay} (也拉防灾办)',
        'ms' => '${AppConfig.emergencyYalaCenterDisplay} (DDPM Yala)',
        _ => '${AppConfig.emergencyYalaCenterDisplay} (ปภ.ยะลา)',
      },
    'yala_city' => switch (lang) {
        'en' => '${AppConfig.emergencyYalaMunicipalityDisplay} (Yala City)',
        'zh' => '${AppConfig.emergencyYalaMunicipalityDisplay} (也拉市政府)',
        'ms' => '${AppConfig.emergencyYalaMunicipalityDisplay} (Bandar Yala)',
        _ => '${AppConfig.emergencyYalaMunicipalityDisplay} (เทศบาลยะลา)',
      },
    _ => switch (lang) {
        'en' => '1669 (EMS)',
        'zh' => '1669 (急救)',
        'ms' => '1669 (Kecemasan)',
        _ => '1669 (สพฉ.)',
      },
  };
}

List<_GuideItem> _appGuideSteps(String lang) {
  if (lang == 'en') {
    return const [
      _GuideItem(
        icon: Icons.map_outlined,
        title: '1. Interactive 3-Level Yala Map & Bang Lang Dam Bar',
        bullets: [
          'The top blue bar tracks live Bang Lang Dam storage, volume, and daily release (EGAT/RID).',
          'Tap any of Yala\'s 8 districts to drill down into 58 subdistricts and 449 villages.',
          'Map colors combine river hazard with real Copernicus DEM terrain elevation (Zones A/B/C): lowlands shift color earlier while high ground stays green.',
        ],
      ),
      _GuideItem(
        icon: Icons.my_location,
        title: '2. Compare Your Home Elevation (GPS / Manual Pin)',
        bullets: [
          'Tap the GPS button (only reads location while using the map after PDPA consent) or long-press anywhere in Yala to drop a pin.',
          'The card displays your ground elevation (m MSL), nearest telemetry station, local alert level, and high-ground road/utility advisories.',
        ],
      ),
      _GuideItem(
        icon: Icons.bar_chart_rounded,
        title: '3. Info Tab: Hourly Rain Chart & 7-Day Water Graphs',
        bullets: [
          'Swipe the hourly rainfall bar chart to inspect both rainfall volume (mm) and rain probability (%) for all 24 hours in Thailand time (UTC+7).',
          'Tap any of the 14 water stations to view 24h / 3d / 7d water-level trends with watch, midpoint, and bank overflow reference lines.',
        ],
      ),
      _GuideItem(
        icon: Icons.tune,
        title: '4. Shelters, Emergency Contacts & Settings',
        bullets: [
          'Use the Shelters tab to navigate via Google Maps and call Yala DDPM (073-203559) or Yala Municipality (073-212345) to confirm opening status before departing.',
          'In Settings, pick your district for targeted alerts, switch between 4 languages, enable Large Text Mode for seniors, or wipe all local data (PDPA).',
        ],
      ),
    ];
  }
  if (lang == 'zh') {
    return const [
      _GuideItem(
        icon: Icons.map_outlined,
        title: '1. 也拉府三级地图与邦朗水坝实时监测栏',
        bullets: [
          '顶部蓝色卡片实时显示邦朗水坝蓄水率、蓄水量与日泄洪量（泰国发电局/灌溉厅）。',
          '点击 8 个县可逐级查看 58 个乡镇与 449 个村庄的精细边界。',
          '地图色阶结合河道风险与 Copernicus DEM 地形高程分区（A/B/C 区），低洼区优先预警，高地保持绿色。',
        ],
      ),
      _GuideItem(
        icon: Icons.my_location,
        title: '2. 对比自家地势高度（GPS / 手动标点）',
        bullets: [
          '点击定位按钮（经 PDPA 授权，仅使用期间读取）或在地图任意位置长按标点。',
          '系统将在本地离线计算该点海拔（米 MSL）、最近水文站距离及局部预警等级。',
        ],
      ),
      _GuideItem(
        icon: Icons.bar_chart_rounded,
        title: '3. 数据页：逐时降雨柱状图与 7 天水位曲线',
        bullets: [
          '左右滑动逐时降雨图，可完整查看未来 24 小时每小时的降雨量（毫米）与降雨概率（%）。',
          '点击 14 座水文站中任意一站，可切换查看 24 小时 / 3 天 / 7 天水位趋势及警戒线/堤岸线。',
        ],
      ),
      _GuideItem(
        icon: Icons.tune,
        title: '4. 避难中心、紧急联络与无障碍设置',
        bullets: [
          '在“避难中心”页可一键使用 Google 地图导航，出发前请致电 073-203559 或 073-212345 确认开放情况。',
          '在“设置”页可选择关注县区、切换 4 种语言、开启长辈大字模式，或一键清除本机所有数据。',
        ],
      ),
    ];
  }
  if (lang == 'ms') {
    return const [
      _GuideItem(
        icon: Icons.map_outlined,
        title: '1. Peta 3 Peringkat Yala & Status Empangan Bang Lang',
        bullets: [
          'Kad biru di bahagian atas memaparkan kapasiti, isipadu dan pelepasan harian Empangan Bang Lang.',
          'Tekan mana-mana 8 daerah untuk meneliti 58 mukim dan 449 kampung dengan sempadan melengkung sebenar.',
          'Warna peta menggabungkan tahap bahaya sungai dengan ketinggian tanah Copernicus DEM (Zon A/B/C).',
        ],
      ),
      _GuideItem(
        icon: Icons.my_location,
        title: '2. Semak Ketinggian Rumah Anda (GPS / Pin Peta)',
        bullets: [
          'Tekan butang GPS (selepas persetujuan PDPA) atau tekan lama pada peta untuk meletakkan pin.',
          'Kad ringkasan menunjukkan ketinggian tanah (m MSL), stesen terdekat dan tahap amaran setempat secara luar talian.',
        ],
      ),
      _GuideItem(
        icon: Icons.bar_chart_rounded,
        title: '3. Tab Info: Carta Hujan 24 Jam & Graf Air 7 Hari',
        bullets: [
          'Leret carta bar hujan untuk melihat jumlah hujan (mm) serta peratusan peluang hujan (%) bagi setiap jam (UTC+7).',
          'Tekan mana-mana 14 stesen paras air untuk graf 24j / 3h / 7h dengan garis waspada, tengah dan tebing.',
        ],
      ),
      _GuideItem(
        icon: Icons.tune,
        title: '4. Pusat Pemindahan, Talian Kecemasan & Tetapan',
        bullets: [
          'Gunakan tab Pusat Pemindahan untuk navigasi Google Maps dan hubungi 073-203559 atau 073-212345 sebelum bertolak.',
          'Di Tetapan, pilih daerah pantauan, tukar 4 bahasa, aktifkan Mod Teks Besar atau padam semua data tempatan (PDPA).',
        ],
      ),
    ];
  }
  return const [
    _GuideItem(
      icon: Icons.map_outlined,
      title: '1. แผนที่เตือนภัย 3 ระดับ และกรอบสถานะเขื่อนบางลาง',
      bullets: [
        'กรอบสีน้ำเงินด้านบนแสดงความจุ ปริมาณน้ำ และปริมาณการระบายน้ำรายวันของเขื่อนบางลาง (กฟผ. / กรมชลประทาน)',
        'แตะเลือกพื้นที่บนแผนที่ได้ครบทั้ง 3 ระดับ: 8 อำเภอ → 58 ตำบล → 449 หมู่บ้าน ด้วยเส้นขอบเว้าโค้งตามเขตการปกครองจริง',
        'สีบนแผนที่ประเมินร่วมระหว่างสถานการณ์ลุ่มน้ำกับระดับความสูงภูมิประเทศจริง (Copernicus DEM แบ่งโซน A ที่ลุ่มต่ำ / โซน B ขอบที่ราบลุ่ม / โซน C ที่สูง)',
      ],
    ),
    _GuideItem(
      icon: Icons.my_location,
      title: '2. ตรวจสอบตำแหน่งบ้านของท่าน (GPS หรือปักหมุดแผนที่)',
      bullets: [
        'กดปุ่มตำแหน่ง GPS (อ่านพิกัดเฉพาะขณะเปิดใช้งานหลังได้รับความยินยอม PDPA) หรือกดค้างบนแผนที่เพื่อปักหมุดจุดที่ต้องการ',
        'ระบบคำนวณความสูงพื้นที่ (ม.รทก.) สถานีวัดระดับน้ำที่ใกล้ที่สุด และระดับการแจ้งเตือนเฉพาะจุดได้ทันทีแบบออฟไลน์',
      ],
    ),
    _GuideItem(
      icon: Icons.bar_chart_rounded,
      title: '3. แถบข้อมูล: กราฟพยากรณ์ฝน 24 ชม. และกราฟระดับน้ำ 7 วัน',
      bullets: [
        'เลื่อนดูกราฟแท่งพยากรณ์ฝนรายชั่วโมง (เวลาไทย UTC+7) แสดงทั้งปริมาณฝน (มม.) และโอกาสฝนตก (%) ครบทุกชั่วโมง',
        'แตะสถานีวัดระดับน้ำ 14 แห่ง เพื่อดูระยะเหลือถึงตลิ่งและกราฟแนวโน้มย้อนหลัง 24 ชม. / 3 วัน / 7 วัน พร้อมเส้นเฝ้าระวัง เส้นกึ่งกลาง และเส้นตลิ่ง',
      ],
    ),
    _GuideItem(
      icon: Icons.tune,
      title: '4. ศูนย์พักพิง ช่องทางฉุกเฉิน และการตั้งค่าผู้สูงอายุ',
      bullets: [
        'แถบศูนย์พักพิงมีปุ่มนำทาง Google Maps และปุ่มโทรสอบถาม 073-203559 / 073-212345 เพื่อยืนยันสถานะการเปิดรับก่อนเดินทาง',
        'ในหน้าตั้งค่า สามารถเลือกอำเภอที่ติดตาม สลับได้ 4 ภาษา เปิดโหมดตัวอักษรใหญ่สำหรับผู้สูงอายุ หรือลบข้อมูลทั้งหมดในเครื่องได้ทันทีตามสิทธิ PDPA',
      ],
    ),
  ];
}

List<_GuideItem> _evacuationSections(String lang) {
  if (lang == 'en') {
    return const [
      _GuideItem(
        icon: Icons.backpack_outlined,
        color: Color(AppConfig.colorWatch),
        title: 'Phase 1: Prepare Before Flooding (Levels 2–3)',
        bullets: [
          'Pack a 72-hour emergency kit: clean drinking water, dry food, 7-day supply of personal medications, flashlight, power bank, whistle, and waterproof copies of ID cards/house registration.',
          'Move electrical appliances, vehicles, and hazardous chemicals above expected flood levels.',
          'Plan early transport and shelter routes for elderly relatives, bedridden patients, young children, and pregnant family members.',
        ],
      ),
      _GuideItem(
        icon: Icons.warning_amber_rounded,
        color: Color(AppConfig.colorWarning),
        title: 'Phase 2: Before Leaving Home (Level 4 — High Alert)',
        bullets: [
          'Turn off the main electrical circuit breaker and shut off cooking gas valves BEFORE floodwater reaches outlets or appliances.',
          'Call Yala DDPM (073-203559) or Yala Municipality (073-212345) to verify active shelters and safe open roads.',
          'If living in a sloped mountain district (Betong, Than To, Bannang Sata, Krong Pinang, Kabang), watch for muddy creek surges or rumbling hillsides and evacuate uphill immediately.',
        ],
      ),
      _GuideItem(
        icon: Icons.directions_run_rounded,
        color: Color(AppConfig.colorDanger),
        title: 'Phase 3: During Evacuation & Flooding (Level 5 — Danger)',
        bullets: [
          'Evacuate immediately to higher ground or a verified temporary shelter — do NOT wait for water to rise further.',
          'NEVER walk through fast-flowing floodwater or drive across submerged roads and bridges.',
          'Avoid downed power lines, submerged transformers, and venomous animals seeking dry shelter. If stranded, move to the highest safe floor and call 1784, 073-203559, or 1669.',
        ],
      ),
      _GuideItem(
        icon: Icons.cleaning_services_outlined,
        color: Color(AppConfig.colorSafe),
        title: 'Phase 4: Returning Home Safely After Floods',
        bullets: [
          'Inspect building structure, electrical wiring, and outlets with a qualified technician before restoring main power.',
          'Wear boots and gloves while cleaning mud; wash hands thoroughly and consume only clean boiled/bottled water to prevent waterborne diseases.',
        ],
      ),
    ];
  }
  if (lang == 'zh') {
    return const [
      _GuideItem(
        icon: Icons.backpack_outlined,
        color: Color(AppConfig.colorWatch),
        title: '第一阶段：洪前准备（2–3 级预警）',
        bullets: [
          '准备 72 小时应急包：饮用水、干粮、至少 7 天常用药品、手电筒、充电宝、口哨及防水袋装好的身份证件副本。',
          '将家用电器、车辆及化学品转移至高处。',
          '提前规划老人、卧床病患、儿童及孕妇的优先转移方案与安全路线。',
        ],
      ),
      _GuideItem(
        icon: Icons.warning_amber_rounded,
        color: Color(AppConfig.colorWarning),
        title: '第二阶段：撤离前安全处置（4 级高度警报）',
        bullets: [
          '在积水接触插座前，务必先拉下总电源开关并关闭燃气总阀。',
          '出发前致电也拉防灾办 (073-203559) 或也拉市政府 (073-212345) 确认避难中心开放及道路通行情况。',
          '山区县居民如发现溪水变浑、水位暴涨或山坡异响，应立即向高地撤离。',
        ],
      ),
      _GuideItem(
        icon: Icons.directions_run_rounded,
        color: Color(AppConfig.colorDanger),
        title: '第三阶段：紧急撤离与避险（5 级极度危险）',
        bullets: [
          '立即撤离至安全避难中心或高地，切勿等待水位继续上涨。',
          '严禁涉水通过湍急水流，严禁驾车强行通过被淹道路或桥梁。',
          '远离电线杆、浸水配电设施并防范蛇虫；如被困请移至高处并立即拨打 1784、073-203559 或 1669。',
        ],
      ),
      _GuideItem(
        icon: Icons.cleaning_services_outlined,
        color: Color(AppConfig.colorSafe),
        title: '第四阶段：退水后安全返家',
        bullets: [
          '恢复供电前须先检查房屋结构与电路是否干燥安全。',
          '清理淤泥时佩戴靴子与手套，饮用洁净水以防感染水媒疾病。',
        ],
      ),
    ];
  }
  if (lang == 'ms') {
    return const [
      _GuideItem(
        icon: Icons.backpack_outlined,
        color: Color(AppConfig.colorWatch),
        title: 'Fasa 1: Persediaan Sebelum Banjir (Tahap 2–3)',
        bullets: [
          'Sediakan beg kecemasan 72 jam: air minuman, makanan kering, ubat-ubatan 7 hari, lampu suluh, power bank, wisel serta salinan dokumen penting dalam bekas kalis air.',
          'Pindahkan peralatan elektrik, kenderaan dan bahan kimia ke tempat tinggi.',
          'Rancang pemindahan awal bagi warga emas, pesakit terlantar, kanak-kanak dan ibu mengandung.',
        ],
      ),
      _GuideItem(
        icon: Icons.warning_amber_rounded,
        color: Color(AppConfig.colorWarning),
        title: 'Fasa 2: Sebelum Meninggalkan Rumah (Tahap 4 — Amaran Tinggi)',
        bullets: [
          'Matikan suis utama elektrik dan tutup injap gas SEBELUM air banjir mencecah soket atau perkakas.',
          'Hubungi DDPM Yala (073-203559) atau Perbandaran Yala (073-212345) untuk mengesahkan pusat pemindahan dan laluan selamat.',
          'Di daerah berbukit, awasi air sungai keruh deras atau bunyi tanah runtuh dan berpindah segera ke tempat tinggi.',
        ],
      ),
      _GuideItem(
        icon: Icons.directions_run_rounded,
        color: Color(AppConfig.colorDanger),
        title: 'Fasa 3: Semasa Pemindahan & Banjir (Tahap 5 — Bahaya)',
        bullets: [
          'Berpindah segera ke pusat pemindahan selamat — jangan tunggu paras air terus meningkat.',
          'JANGAN meredah arus banjir deras atau memandu melalui jalan dan jambatan yang ditenggelami air.',
          'Jauhi tiang elektrik dan haiwan berbisa. Jika terkandas, naik ke tingkat selamat tertinggi dan hubungi 1784, 073-203559 atau 1669.',
        ],
      ),
      _GuideItem(
        icon: Icons.cleaning_services_outlined,
        color: Color(AppConfig.colorSafe),
        title: 'Fasa 4: Selepas Banjir Surut',
        bullets: [
          'Periksa struktur rumah dan pendawaian elektrik sebelum menghidupkan semula bekalan kuasa utama.',
          'Pakai kasut but dan sarung tangan semasa membersihkan lumpur serta minum air bersih sahaja.',
        ],
      ),
    ];
  }
  return const [
    _GuideItem(
      icon: Icons.backpack_outlined,
      color: Color(AppConfig.colorWatch),
      title: 'ระยะที่ 1: การเตรียมความพร้อมก่อนเกิดอุทกภัย (ระดับ 2–3)',
      bullets: [
        'จัดเตรียมถุงยังชีพฉุกเฉินสำหรับ 72 ชั่วโมง ได้แก่ น้ำดื่มสะอาด อาหารแห้ง ยาประจำตัวสำรองอย่างน้อย 7 วัน ไฟฉาย แบตเตอรี่สำรอง นกหวีด และเอกสารสำคัญใส่ซองกันน้ำ',
        'ขนย้ายเครื่องใช้ไฟฟ้า ทรัพย์สินมีค่า ยานพาหนะ และสารเคมีขึ้นสู่ที่สูงพ้นระดับน้ำ',
        'วางแผนเส้นทางอพยพและยานพาหนะล่วงหน้า โดยให้ความสำคัญอันดับแรกกับผู้สูงอายุ ผู้ป่วยติดเตียง เด็กเล็ก และสตรีมีครรภ์',
      ],
    ),
    _GuideItem(
      icon: Icons.warning_amber_rounded,
      color: Color(AppConfig.colorWarning),
      title: 'ระยะที่ 2: การปฏิบัติก่อนออกจากที่พักอาศัย (ระดับ 4 — เตือนภัยสูง)',
      bullets: [
        'สับคัตเอาต์ตัดกระแสไฟฟ้าและปิดวาล์วถังแก๊สหุงต้มทันที ก่อนที่ระดับน้ำจะท่วมถึงปลั๊กไฟหรือเครื่องใช้ไฟฟ้า',
        'ตรวจสอบสถานะการเปิดรับของศูนย์พักพิงและเส้นทางที่สัญจรได้ทาง ปภ.ยะลา (073-203559) หรือเทศบาลนครยะลา (073-212345)',
        'พื้นที่ลาดเชิงเขา (เบตง ธารโต บันนังสตา กรงปินัง กาบัง) หากสังเกตเห็นน้ำป่าสีขุ่นแดงไหลเชี่ยวหรือมีเสียงดังผิดปกติจากภูเขา ให้รีบอพยพขึ้นที่สูงทันที',
      ],
    ),
    _GuideItem(
      icon: Icons.directions_run_rounded,
      color: Color(AppConfig.colorDanger),
      title: 'ระยะที่ 3: การอพยพและเอาชีวิตรอดขณะเกิดอุทกภัย (ระดับ 5 — อันตราย)',
      bullets: [
        'อพยพทันทีไปยังศูนย์พักพิงชั่วคราวหรือพื้นที่สูงปลอดภัย ห้ามรอดูสถานการณ์จนน้ำท่วมตัดขาดเส้นทาง',
        'ห้ามเดินลุยกระแสน้ำไหลเชี่ยว และห้ามขับขี่ยานพาหนะฝ่าเส้นทางหรือสะพานที่มีน้ำท่วมสูงและไหลแรง',
        'หลีกเลี่ยงการเข้าใกล้เสาไฟฟ้า สายไฟที่ขาด และระมัดระวังสัตว์มีพิษ หากติดค้างในอาคารให้ขึ้นสู่ชั้นสูงสุดที่ปลอดภัยและโทร. 1784, 073-203559 หรือ 1669',
      ],
    ),
    _GuideItem(
      icon: Icons.cleaning_services_outlined,
      color: Color(AppConfig.colorSafe),
      title: 'ระยะที่ 4: ข้อควรปฏิบัติหลังน้ำลดก่อนกลับเข้าที่พักอาศัย',
      bullets: [
        'ตรวจสอบความมั่นคงของตัวอาคารและให้ช่างตรวจสอบระบบไฟฟ้าให้แห้งสนิทก่อนสับคัตเอาต์เปิดใช้งาน',
        'สวมรองเท้าบูตและถุงมือขณะทำความสะอาดคราบโคลน ล้างมือให้สะอาด และบริโภคน้ำดื่มและอาหารที่ปรุงสุกสะอาดเพื่อป้องกันโรคมากับน้ำท่วม',
      ],
    ),
  ];
}
