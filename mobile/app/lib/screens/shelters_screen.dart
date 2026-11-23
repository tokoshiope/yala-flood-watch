import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/shelter.dart';

/// ข้อมูลตัวอย่างจุดอพยพ 8 อำเภอของจังหวัดยะลา
///
/// ตัวเลขจำนวนคนและพิกัดเป็นค่าตัวอย่างเพื่อให้ UI ใช้งานได้ครบ
/// เมื่อจังหวัดยะลาเปิดตัวฐานข้อมูลจุดอพยพจริง ให้ดึงจาก API แทน
const List<Shelter> kSampleShelters = [
  Shelter(
    nameTh: 'วัดเมืองยะลา',
    amphoeTh: 'เมืองยะลา',
    addressTh: 'ต.ตาเซะ อ.เมืองยะลา',
    lat: 6.5420,
    lng: 101.2810,
    capacity: 250,
    phone: '073212345',
    notesTh: 'มีลานจอดรถ และห้องน้ำ',
  ),
  Shelter(
    nameTh: 'โรงเรียนบ้านสะพานท่าสาป',
    amphoeTh: 'เมืองยะลา',
    addressTh: 'ต.สะเตง อ.เมืองยะลา',
    lat: 6.5527,
    lng: 101.2662,
    capacity: 150,
    notesTh: 'อาคาร 2 ชั้น รับได้ ~150 คน',
  ),
  Shelter(
    nameTh: 'วัดรามัน',
    amphoeTh: 'รามัน',
    addressTh: 'ต.ตะโล๊ะหะลอ อ.รามัน',
    lat: 6.4785,
    lng: 101.4238,
    capacity: 200,
    notesTh: 'อยู่เชิงเขา เหมาะกับน้ำท่วมลุ่มน้ำปัตตานี',
  ),
  Shelter(
    nameTh: 'โรงเรียนยะหาวิทยา',
    amphoeTh: 'ยะหา',
    addressTh: 'ต.บาโร๊ะ อ.ยะหา',
    lat: 6.4767,
    lng: 101.1400,
    capacity: 180,
    notesTh: 'มีห้องพยาบาลเบื้องต้น',
  ),
  Shelter(
    nameTh: 'สนามกีฬากรงปินัง',
    amphoeTh: 'กรงปินัง',
    addressTh: 'ต.กรงปินัง อ.กรงปินัง',
    lat: 6.4167,
    lng: 101.2833,
    capacity: 300,
    notesTh: 'พื้นที่กว้าง รับได้หลายร้อยคน',
  ),
  Shelter(
    nameTh: 'วัดเบตง',
    amphoeTh: 'เบตง',
    addressTh: 'ต.เบตง อ.เบตง',
    lat: 5.9206,
    lng: 101.1821,
    capacity: 220,
    notesTh: 'ใกล์จังหวัดใหม่',
  ),
  Shelter(
    nameTh: 'โรงเรียนบ้านบันนังสตา',
    amphoeTh: 'บันนังสตา',
    addressTh: 'ต.บันนังสตา อ.บันนังสตา',
    lat: 6.2620,
    lng: 101.2680,
    capacity: 160,
    notesTh: 'อาคาร 3 ชั้น',
  ),
  Shelter(
    nameTh: 'ศาลาประชาคมธารโต',
    amphoeTh: 'ธารโต',
    addressTh: 'ต.คีรีเขต อ.ธารโต',
    lat: 6.1525,
    lng: 101.0809,
    capacity: 120,
    notesTh: 'มีเสบียงและน้ำดื่มสำรอง',
  ),
  Shelter(
    nameTh: 'โรงเรียนกาบัง',
    amphoeTh: 'กาบัง',
    addressTh: 'ต.กาบัง อ.กาบัง',
    lat: 6.4590,
    lng: 101.0230,
    capacity: 140,
    notesTh: 'จุดสูง เข้าถึงได้ทางหลวง',
  ),
];

/// หน้าจุดอพยพ
class SheltersScreen extends StatefulWidget {
  const SheltersScreen({super.key});

  @override
  State<SheltersScreen> createState() => _SheltersScreenState();
}

class _SheltersScreenState extends State<SheltersScreen> {
  String? _amphoe;

  List<String> get _amphoes {
    final set = kSampleShelters.map((s) => s.amphoeTh).toSet().toList()..sort();
    return set;
  }

  List<Shelter> get _filtered {
    if (_amphoe == null) return kSampleShelters;
    return kSampleShelters.where((s) => s.amphoeTh == _amphoe).toList();
  }

  Future<void> _openMap(Shelter shelter) async {
    final uri = Uri.parse(
      '${AppConfig.googleMapsUrl}${shelter.lat},${shelter.lng}'
      '&query=${Uri.encodeComponent(shelter.nameTh)}',
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
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('จุดอพยพ')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFE3F2FD),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF0E5FA6)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'ข้อมูลตัวอย่าง ก่อนใช้จริงควรสอบถามเส้นทางกับ ศูนย์ปภ.ยะลา',
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
                    label: const Text('ทั้งหมด'),
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
                        Text(shelter.addressTh),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.groups, size: 16),
                            const SizedBox(width: 4),
                            Text(shelter.capacityLabel),
                          ],
                        ),
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
                                label: const Text('เส้นทาง'),
                              ),
                            ),
                            if (shelter.phone != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _call(shelter.phone!),
                                  icon: const Icon(Icons.phone, size: 18),
                                  label: const Text('โทร'),
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
