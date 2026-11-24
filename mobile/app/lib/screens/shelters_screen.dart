import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/shelter.dart';

/// ศูนย์พักพิงชั่วคราว จ.ยะลา ตรงกับ backend/registry/shelters.yaml (v2)
/// แยกชัดเจนระหว่างจุดที่อ้างอิงชื่อทางการเทศบาลนครยะลา กับจุดประสานงานอำเภอที่รอยืนยันพิกัด ปภ.ยะลา
const List<Shelter> kYalaShelters = [
  Shelter(
    nameTh: 'อาคารเรียนรู้ TK Park ยะลา (หลังเก่า)',
    amphoeTh: 'เมืองยะลา',
    addressTh: 'เขตเทศบาลนครยะลา อ.เมืองยะลา · [ชื่อทางการ · รอตรวจพิกัดละเอียด]',
    lat: 6.5415,
    lng: 101.2812,
    phone: AppConfig.emergencyYalaMunicipality,
    notesTh: 'ศูนย์พักพิงชั่วคราวหลักเทศบาลนครยะลา (ที่มา: กรมประชาสัมพันธ์/เทศบาลนครยะลา)',
  ),
  Shelter(
    nameTh: 'โรงเรียนเทศบาล 2 (มลายูบางกอก)',
    amphoeTh: 'เมืองยะลา',
    addressTh: 'เขตเทศบาลนครยะลา อ.เมืองยะลา · [ชื่อทางการ · รอตรวจพิกัดละเอียด]',
    lat: 6.5468,
    lng: 101.2896,
    phone: AppConfig.emergencyYalaMunicipality,
    notesTh: 'ศูนย์พักพิงชั่วคราวเขตเทศบาลนครยะลา โทร 073-212345 ตรวจสถานะเปิดรับ',
  ),
  Shelter(
    nameTh: 'โรงเรียนเทศบาล 3 (วัดพุทธภูมิ)',
    amphoeTh: 'เมืองยะลา',
    addressTh: 'เขตเทศบาลนครยะลา อ.เมืองยะลา · [ชื่อทางการ · รอตรวจพิกัดละเอียด]',
    lat: 6.5398,
    lng: 101.2775,
    phone: AppConfig.emergencyYalaMunicipality,
    notesTh: 'ศูนย์พักพิงชั่วคราวเขตเทศบาลนครยะลา',
  ),
  Shelter(
    nameTh: 'มัสยิดกลางประจำจังหวัดยะลา',
    amphoeTh: 'เมืองยะลา',
    addressTh: 'ถ.สิโรรส ต.สะเตง อ.เมืองยะลา · [ชื่อทางการ · รอตรวจพิกัดละเอียด]',
    lat: 6.5482,
    lng: 101.2837,
    phone: AppConfig.emergencyYalaMunicipality,
    notesTh: 'ศูนย์พักพิงชั่วคราวเขตเทศบาลนครยะลา',
  ),
  Shelter(
    nameTh: 'จุดประสานงานที่ว่าการอำเภอรามัน',
    amphoeTh: 'รามัน',
    addressTh: 'อ.รามัน จ.ยะลา · [รอตรวจพิกัดรายตำบลจาก ปภ.ยะลา]',
    lat: 6.4785,
    lng: 101.4238,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'โทร ปภ.ยะลา 073-203559 หรือ 1784 เพื่อตรวจสอบศูนย์พักพิงที่เปิดรับล่าสุด',
  ),
  Shelter(
    nameTh: 'จุดประสานงานที่ว่าการอำเภอยะหา',
    amphoeTh: 'ยะหา',
    addressTh: 'อ.ยะหา จ.ยะลา · [รอตรวจพิกัดรายตำบลจาก ปภ.ยะลา]',
    lat: 6.4767,
    lng: 101.1400,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'โทร ปภ.ยะลา 073-203559 หรือ 1784',
  ),
  Shelter(
    nameTh: 'จุดประสานงานที่ว่าการอำเภอกรงปินัง',
    amphoeTh: 'กรงปินัง',
    addressTh: 'อ.กรงปินัง จ.ยะลา · [รอตรวจพิกัดรายตำบลจาก ปภ.ยะลา]',
    lat: 6.4167,
    lng: 101.2833,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'โทร ปภ.ยะลา 073-203559 หรือ 1784',
  ),
  Shelter(
    nameTh: 'จุดประสานงานที่ว่าการอำเภอบันนังสตา',
    amphoeTh: 'บันนังสตา',
    addressTh: 'อ.บันนังสตา จ.ยะลา · [รอตรวจพิกัดรายตำบลจาก ปภ.ยะลา]',
    lat: 6.2620,
    lng: 101.2680,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'โทร ปภ.ยะลา 073-203559 หรือ 1784',
  ),
  Shelter(
    nameTh: 'จุดประสานงานเทศบาลเมืองเบตง',
    amphoeTh: 'เบตง',
    addressTh: 'อ.เบตง จ.ยะลา · [รอตรวจพิกัดรายตำบลจาก ปภ.ยะลา]',
    lat: 5.7743,
    lng: 101.0723,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'โทร ปภ.ยะลา 073-203559 หรือ 1784',
  ),
  Shelter(
    nameTh: 'จุดประสานงานที่ว่าการอำเภอธารโต',
    amphoeTh: 'ธารโต',
    addressTh: 'อ.ธารโต จ.ยะลา · [รอตรวจพิกัดรายตำบลจาก ปภ.ยะลา]',
    lat: 6.1525,
    lng: 101.0809,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'โทร ปภ.ยะลา 073-203559 หรือ 1784',
  ),
  Shelter(
    nameTh: 'จุดประสานงานที่ว่าการอำเภอกาบัง',
    amphoeTh: 'กาบัง',
    addressTh: 'อ.กาบัง จ.ยะลา · [รอตรวจพิกัดรายตำบลจาก ปภ.ยะลา]',
    lat: 6.4590,
    lng: 101.0230,
    phone: AppConfig.emergencyYalaCenter,
    notesTh: 'โทร ปภ.ยะลา 073-203559 หรือ 1784',
  ),
];

/// Alias คงไว้เพื่อความเข้ากันย้อนหลังกับโค้ดเดิม
const List<Shelter> kSampleShelters = kYalaShelters;

/// หน้าจุดอพยพ
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

  Future<void> _openMap(Shelter shelter) async {
    final uri = Uri.parse(
      '${AppConfig.googleMapsUrl}${shelter.lat},${shelter.lng}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปิดแผนที่ได้จากเครื่องนี้')),
      );
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถโทรได้จากเครื่องนี้ ($phone)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ศูนย์พักพิง / จุดอพยพ')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFE3F2FD),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: const Row(
              children: [
                Icon(Icons.verified_outlined, size: 16, color: Color(0xFF0E5FA6)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'จุดเขตเทศบาลนครยะลาอ้างอิงประกาศทางการ · ก่อนเดินทางโปรดโทร ปภ.ยะลา 073-203559 หรือ 073-212345 ตรวจสถานะเปิดรับ',
                    style: TextStyle(fontSize: 12),
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
                    label: const Text('ทั้ง 8 อำเภอ'),
                    selected: _amphoe == null,
                    onSelected: (_) => setState(() => _amphoe = null),
                  ),
                ),
                for (final amphoe in _amphoes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(amphoe),
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
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shelter.nameTh,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(shelter.addressTh, style: const TextStyle(fontSize: 12.5)),
                        if (shelter.notesTh.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            shelter.notesTh,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _openMap(shelter),
                                icon: const Icon(Icons.map_outlined, size: 18),
                                label: const Text('เปิดแผนที่'),
                              ),
                            ),
                            if (shelter.phone != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _call(shelter.phone!),
                                  icon: const Icon(Icons.phone, size: 18),
                                  label: const Text('โทรสอบถาม'),
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
