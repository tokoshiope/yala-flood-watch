import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// หน้าตั้งค่า: อำเภอ/ตำบล, เกณฑ์แจ้งเตือน, โหมดเงียบ และการโหลดข้อมูล
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final settings = provider.settings;
    final amphoes = provider.amphoes.isNotEmpty
        ? provider.amphoes
        : AppConfig.riskAmphoeTh;
    final tumbons = <String>[...provider.tumbonsInSelectedAmphoe];
    if (settings.selectedTumbonTh != null &&
        !tumbons.contains(settings.selectedTumbonTh)) {
      tumbons.add(settings.selectedTumbonTh!);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่า')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SectionTitle('พื้นที่ที่ติดตาม'),
          DropdownButtonFormField<String?>(
            initialValue: settings.selectedAmphoeTh,
            decoration: const InputDecoration(
              labelText: 'อำเภอ',
              prefixIcon: Icon(Icons.location_city),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('ทั้งจังหวัดยะลา')),
              for (final amphoe in amphoes)
                DropdownMenuItem(value: amphoe, child: Text(amphoe)),
            ],
            onChanged: (value) => provider.updateSettings(
              settings.copyWith(selectedAmphoeTh: value, selectedTumbonTh: null),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: settings.selectedTumbonTh,
            decoration: const InputDecoration(
              labelText: 'ตำบล',
              prefixIcon: Icon(Icons.map_outlined),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('ทุกตำบล')),
              for (final tumbon in tumbons)
                if (tumbon.isNotEmpty)
                  DropdownMenuItem(value: tumbon, child: Text(tumbon)),
            ],
            onChanged: (value) => provider.updateSettings(
              settings.copyWith(selectedTumbonTh: value),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle('เกณฑ์การแจ้งเตือน'),
          DropdownButtonFormField<int>(
            initialValue: settings.warningLevel,
            decoration: const InputDecoration(
              labelText: 'เริ่มแจ้งเตือนเมื่อระดับสถานการณ์',
              prefixIcon: Icon(Icons.warning_amber),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 2, child: Text('ระดับ 2 — เฝ้าระวัง')),
              DropdownMenuItem(value: 3, child: Text('ระดับ 3 — เตือนภัย')),
              DropdownMenuItem(value: 4, child: Text('ระดับ 4 — อันตราย')),
            ],
            onChanged: (value) => provider.updateSettings(
              settings.copyWith(warningLevel: value ?? 3),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: settings.dangerLevel,
            decoration: const InputDecoration(
              labelText: 'ถือว่าอันตรายเมื่อระดับสถานการณ์',
              prefixIcon: Icon(Icons.dangerous_outlined),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 3, child: Text('ระดับ 3 ขึ้นไป')),
              DropdownMenuItem(value: 4, child: Text('ระดับ 4')),
            ],
            onChanged: (value) => provider.updateSettings(
              settings.copyWith(dangerLevel: value ?? 4),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle('การแจ้งเตือน'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_off_outlined),
            title: const Text('โหมดเงียบ'),
            subtitle: const Text('แสดงสถานะตามปกติ แต่ไม่เล่นเสียง/สั่น'),
            value: settings.quietMode,
            onChanged: (value) =>
                provider.updateSettings(settings.copyWith(quietMode: value)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Push แจ้งเตือน'),
            subtitle: const Text('เปิดรับข้อความจาก ศูนย์ปภ.ยะลา'),
            value: settings.pushEnabled,
            onChanged: (value) =>
                provider.updateSettings(settings.copyWith(pushEnabled: value)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_outlined),
            title: const Text('คำนวณค่าฝนร่วมด้วย'),
            subtitle: const Text('ปรับระดับเตือนตามค่าฝนในอนาคต'),
            value: settings.rainScoreEnabled,
            onChanged: (value) =>
                provider.updateSettings(settings.copyWith(rainScoreEnabled: value)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: settings.refreshMinutes,
            decoration: const InputDecoration(
              labelText: 'รีเฟรชข้อมูลทุก ๆ',
              prefixIcon: Icon(Icons.update),
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 5, child: Text('5 นาที')),
              DropdownMenuItem(value: 10, child: Text('10 นาที')),
              DropdownMenuItem(value: 15, child: Text('15 นาที')),
              DropdownMenuItem(value: 30, child: Text('30 นาที')),
            ],
            onChanged: (value) => provider.updateSettings(
              settings.copyWith(refreshMinutes: value ?? 15),
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle('ข้อมูล'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('ล้างข้อมูลสำรอง'),
            subtitle: const Text('บังคับโหลดค่าใหม่จากเซิร์ฟเวอร์'),
            onTap: () async {
              await provider.clearCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ล้างข้อมูลสำรองแล้ว')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('ล้างประวัติแจ้งเตือน'),
            subtitle: Text('มี ${provider.alerts.length} รายการ'),
            onTap: provider.clearAlerts,
          ),
          const SizedBox(height: 20),
          _SectionTitle('เกี่ยวกับ'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('น้ำท่วมยะลา'),
            subtitle: Text(
              'เวอร์ชัน ${AppConfig.appVersion}\n'
              'ข้อมูลระดับน้ำ: ThaiWater (สสน.) จ.ยะลา (รหัส ${AppConfig.provinceCode})\n'
              'แผนที่: OpenStreetMap\n'
              'แอพฟรีเพื่อประชาชน',
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: const Color(AppConfig.colorPrimary),
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
