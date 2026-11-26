import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/shelter.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// ศูนย์พักพิงชั่วคราว จ.ยะลา ตรงกับ backend/registry/shelters.yaml (v3)
/// - ไม่มีป้าย "ชื่อทางการ (พิกัดโดยประมาณ)"
/// - ศูนย์ต่างอำเภอระบุ "อ้างอิงจากข้อมูลเดิม รอยืนยัน" ชัดเจน
/// - รองรับ iOS Dark Mode และแปลครบ 4 ภาษา (ไทย/อังกฤษ/จีน/มาเลเซีย)
const List<Shelter> kYalaShelters = [
  Shelter(
    nameTh: 'อาคารเรียนรู้ TK Park ยะลา (หลังเก่า)',
    amphoeTh: 'เมืองยะลา',
    addressTh: 'เขตเทศบาลนครยะลา อ.เมืองยะลา',
    lat: 6.5415,
    lng: 101.2812,
    phone: AppConfig.emergencyYalaMunicipality,
    notesTh: 'ศูนย์พักพิงชั่วคราวหลักเขตเทศบาลนครยะลา',
  ),
  Shelter(
    nameTh: 'โรงเรียนเทศบาล 2 (มลายูบางกอก)',
    amphoeTh: 'เมืองยะลา',
    addressTh: 'เขตเทศบาลนครยะลา อ.เมืองยะลา',
    lat: 6.5468,
    lng: 101.2896,
    phone: AppConfig.emergencyYalaMunicipality,
    notesTh: 'ศูนย์พักพิงชั่วคราวเขตเทศบาลนครยะลา',
  ),
  Shelter(
    nameTh: 'โรงเรียนเทศบาล 3 (วัดพุทธภูมิ)',
    amphoeTh: 'เมืองยะลา',
    addressTh: 'เขตเทศบาลนครยะลา อ.เมืองยะลา',
    lat: 6.5398,
    lng: 101.2775,
    phone: AppConfig.emergencyYalaMunicipality,
    notesTh: 'ศูนย์พักพิงชั่วคราวเขตเทศบาลนครยะลา',
  ),
  Shelter(
    nameTh: 'มัสยิดกลางประจำจังหวัดยะลา',
    amphoeTh: 'เมืองยะลา',
    addressTh: 'ถนนสิโรรส ต.สะเตง อ.เมืองยะลา',
    lat: 6.5482,
    lng: 101.2837,
    phone: AppConfig.emergencyYalaMunicipality,
    notesTh: 'ศูนย์พักพิงชั่วคราวเขตเทศบาลนครยะลา',
  ),
  Shelter(
    nameTh: 'วัดนิโรธสังฆาราม (ต.สะเตง)',
    amphoeTh: 'เมืองยะลา',
    addressTh: 'ต.สะเตง อ.เมืองยะลา',
    lat: 6.5378,
    lng: 101.2874,
    phone: AppConfig.emergencyYalaMunicipality,
    notesTh: 'เคยเปิดเป็นศูนย์พักพิงและโรงทานช่วยเหลือผู้ประสบภัยน้ำท่วมยะลา พ.ศ. 2567',
  ),
  Shelter(
    nameTh: 'วัดรังสิตาวาส (ต.กายูบอเกาะ)',
    amphoeTh: 'รามัน',
    addressTh: 'ต.กายูบอเกาะ อ.รามัน จ.ยะลา',
    lat: 6.4792,
    lng: 101.4254,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'เคยเปิดเป็นศูนย์พักพิงและโรงทานรับผู้ประสบภัยน้ำท่วมใหญ่ อ.รามัน พ.ศ. 2567',
    isHistoricalUnconfirmed: true,
  ),
  Shelter(
    nameTh: 'อาคารอเนกประสงค์ เทศบาลตำบลยะหา / หอประชุมที่ว่าการอำเภอยะหา',
    amphoeTh: 'ยะหา',
    addressTh: 'ต.ยะหา อ.ยะหา จ.ยะลา',
    lat: 6.4767,
    lng: 101.1398,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'เคยใช้เป็นศูนย์บัญชาการและจุดพักพิงชั่วคราวตามแผนเผชิญเหตุ อ.ยะหา',
    isHistoricalUnconfirmed: true,
  ),
  Shelter(
    nameTh: 'อาคารอเนกประสงค์ อบต.กรงปินัง / ที่ว่าการอำเภอกรงปินัง',
    amphoeTh: 'กรงปินัง',
    addressTh: 'ต.กรงปินัง อ.กรงปินัง จ.ยะลา',
    lat: 6.4167,
    lng: 101.2833,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'จุดรองรับผู้ประสบภัยน้ำป่าไหลหลากตามแผนเผชิญเหตุ อ.กรงปินัง',
    isHistoricalUnconfirmed: true,
  ),
  Shelter(
    nameTh: 'หอประชุมที่ว่าการอำเภอบันนังสตา / เทศบาลตำบลบันนังสตา',
    amphoeTh: 'บันนังสตา',
    addressTh: 'ต.บันนังสตา อ.บันนังสตา จ.ยะลา',
    lat: 6.2620,
    lng: 101.2680,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'จุดรองรับผู้ประสบภัยท้ายเขื่อนบางลางตามแผนเผชิญเหตุ อ.บันนังสตา',
    isHistoricalUnconfirmed: true,
  ),
  Shelter(
    nameTh: 'อาคารอเนกประสงค์ เทศบาลเมืองเบตง / ศูนย์เยาวชนเทศบาลเมืองเบตง',
    amphoeTh: 'เบตง',
    addressTh: 'ต.เบตง อ.เบตง จ.ยะลา',
    lat: 5.7743,
    lng: 101.0723,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'จุดพักพิงชั่วคราวกรณีน้ำป่าและดินสไลด์ อ.เบตง (พ.ศ. 2567)',
    isHistoricalUnconfirmed: true,
  ),
  Shelter(
    nameTh: 'หอประชุมที่ว่าการอำเภอธารโต / อาคารอเนกประสงค์ อบต.ธารโต',
    amphoeTh: 'ธารโต',
    addressTh: 'ต.ธารโต อ.ธารโต จ.ยะลา',
    lat: 6.1525,
    lng: 101.0809,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'จุดปลอดภัยสำหรับพื้นที่เสี่ยงน้ำป่าไหลหลาก อ.ธารโต',
    isHistoricalUnconfirmed: true,
  ),
  Shelter(
    nameTh: 'หอประชุมที่ว่าการอำเภอกาบัง / อาคารอเนกประสงค์ อบต.กาบัง',
    amphoeTh: 'กาบัง',
    addressTh: 'ต.กาบัง อ.กาบัง จ.ยะลา',
    lat: 6.4590,
    lng: 101.0230,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'จุดปลอดภัยสำหรับพื้นที่เสี่ยงน้ำป่าไหลหลาก อ.กาบัง',
    isHistoricalUnconfirmed: true,
  ),
];

const List<Shelter> kSampleShelters = kYalaShelters;

/// หน้าศูนย์พักพิง: นำทางด้วย Google Maps Turn-by-Turn Directions
class SheltersScreen extends StatefulWidget {
  const SheltersScreen({super.key});

  @override
  State<SheltersScreen> createState() => _SheltersScreenState();
}

class _SheltersScreenState extends State<SheltersScreen> {
  String? _amphoe;

  List<String> get _amphoes {
    final set = kYalaShelters.map((s) => s.amphoeTh).toSet().toList()..sort();
    return set;
  }

  List<Shelter> get _filtered {
    if (_amphoe == null) return kYalaShelters;
    return kYalaShelters.where((s) => s.amphoeTh == _amphoe).toList();
  }

  Future<void> _openGoogleMaps(Shelter shelter, AppStrings strings) async {
    final uri = Uri.tryParse(
      AppConfig.googleMapsDirectionsUrl(shelter.lat, shelter.lng),
    );
    if (uri == null || uri.scheme != 'https') return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.get('cannot_open_maps'))),
      );
    }
  }

  Future<void> _call(String phone, AppStrings strings) async {
    final sanitized = phone.replaceAll(RegExp(r'[^0-9+*#]'), '');
    if (sanitized.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: sanitized);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.get('cannot_call')} ($phone)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AlertProvider>().strings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(strings.get('shelters_title'))),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: isDark ? const Color(0xFF0F2942) : const Color(0xFFE3F2FD),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: isDark ? const Color(0xFF90CAF9) : const Color(0xFF0E5FA6),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    strings.get('shelters_call_notice'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFE3F2FD) : const Color(0xFF0B2545),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(strings.get('all_amphoes')),
                    selected: _amphoe == null,
                    onSelected: (_) => setState(() => _amphoe = null),
                  ),
                ),
                for (final amphoe in _amphoes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(strings.amphoe(amphoe)),
                      selected: _amphoe == amphoe,
                      onSelected: (_) => setState(() => _amphoe = amphoe),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: _filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final shelter = _filtered[index];
                final displayName = strings.shelterName(shelter.nameTh);
                final displayAddress =
                    strings.shelterAddress(shelter.nameTh, shelter.addressTh);
                final displayNotes =
                    strings.shelterNotes(shelter.nameTh, shelter.notesTh);

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          displayAddress,
                          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                        ),
                        if (shelter.isHistoricalUnconfirmed) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF422006)
                                  : const Color(0xFFFFF7ED),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                            child: Text(
                              strings.get('hist_shelter_badge'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? const Color(0xFFFDE68A)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                        ],
                        if (displayNotes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            displayNotes,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openGoogleMaps(shelter, strings),
                                icon: const Icon(Icons.directions, size: 18),
                                label: Text(strings.get('nav_google_maps')),
                              ),
                            ),
                            if (shelter.phone != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _call(shelter.phone!, strings),
                                  icon: const Icon(Icons.phone, size: 17),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      strings.callShelterWithNumber(shelter.phone!),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
