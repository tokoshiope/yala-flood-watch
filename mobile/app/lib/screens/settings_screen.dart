import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// หน้าตั้งค่า: เลือกภาษา 4 ภาษา (ไทย/อังกฤษ/จีน/มาเลเซีย), อำเภอ/ตำบล, เกณฑ์แจ้งเตือน, PDPA และสถานะ CDN
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmDeleteAll(BuildContext context, AlertProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลบข้อมูลทั้งหมดในเครื่อง (PDPA)'),
        content: const Text(
          'การดำเนินการนี้จะลบประวัติแจ้งเตือน, ประวัติ SOS/พิกัดในเครื่อง, ความยินยอม GPS, '
          'ข้อมูลแคช และการตั้งค่าทั้งหมดของคุณทันที ยืนยันหรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(AppConfig.colorDanger),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ลบข้อมูลทั้งหมด'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteAllUserData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบข้อมูลส่วนบุคคลและประวัติในเครื่องทั้งหมดแล้ว')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final settings = provider.settings;
    final strings = provider.strings;
    final amphoes = AppConfig.riskAmphoeTh;
    final tumbons = <String>[...provider.tumbonsInSelectedAmphoe];
    if (settings.selectedTumbonTh != null &&
        !tumbons.contains(settings.selectedTumbonTh)) {
      tumbons.add(settings.selectedTumbonTh!);
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.get('settings_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SectionTitle(strings.get('language_section')),
          DropdownButtonFormField<String>(
            initialValue: settings.languageCode,
            decoration: const InputDecoration(
              labelText: 'ภาษา / Language / 语言 / Bahasa',
              prefixIcon: Icon(Icons.language),
              border: OutlineInputBorder(),
            ),
            items: [
              for (final entry in AppStrings.supportedLanguages)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (value) {
              if (value != null) {
                provider.updateSettings(settings.copyWith(languageCode: value));
              }
            },
          ),
          const SizedBox(height: 20),
          const _SectionTitle('พื้นที่ที่ติดตาม'),
          DropdownButtonFormField<String?>(
            initialValue: settings.selectedAmphoeTh,
            decoration: const InputDecoration(
              labelText: 'อำเภอ (ครบทั้ง 8 อำเภอของยะลา)',
              prefixIcon: Icon(Icons.location_city),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('ทั้งจังหวัดยะลา')),
              for (final amphoe in amphoes)
                DropdownMenuItem(value: amphoe, child: Text(strings.amphoe(amphoe))),
            ],
            onChanged: (value) {
              if (value == null) {
                provider.updateSettings(settings.clearAmphoe());
              } else {
                provider.updateSettings(
                  settings.copyWith(selectedAmphoeTh: value, clearTumbon: true),
                );
              }
            },
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
              value == null
                  ? settings.copyWith(clearTumbon: true)
                  : settings.copyWith(selectedTumbonTh: value),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('เกณฑ์การแจ้งเตือน'),
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
              DropdownMenuItem(value: 4, child: Text('ระดับ 4 — เตือนภัยสูง/อันตราย')),
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
              DropdownMenuItem(value: 4, child: Text('ระดับ 4 ขึ้นไป')),
            ],
            onChanged: (value) => provider.updateSettings(
              settings.copyWith(dangerLevel: value ?? 4),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('การแจ้งเตือน'),
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
            title: const Text('แจ้งเตือนระดับน้ำในเครื่อง'),
            subtitle: const Text('แจ้งเตือนอัตโนมัติเมื่อระดับความเสี่ยงเพิ่มสูงขึ้น (Cooldown 30 นาที)'),
            value: settings.pushEnabled,
            onChanged: (value) =>
                provider.updateSettings(settings.copyWith(pushEnabled: value)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_outlined),
            title: const Text('คำนวณฝนจริง & พยากรณ์ฝนร่วมด้วย'),
            subtitle: const Text('ใช้สูตร formula_version = 2 (ระดับน้ำ + ฝน 87 สถานี + เขื่อนบางลาง)'),
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
          const _SectionTitle('ความเป็นส่วนตัวและข้อมูล (PDPA)'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('ล้างข้อมูลสำรอง (Cache)'),
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
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Color(AppConfig.colorDanger)),
            title: const Text(
              'ลบข้อมูลของฉันทั้งหมด (PDPA)',
              style: TextStyle(color: Color(AppConfig.colorDanger), fontWeight: FontWeight.w700),
            ),
            subtitle: const Text('ลบประวัติ SOS, พิกัดในเครื่อง, ความยินยอม GPS และแจ้งเตือนทั้งหมด'),
            onTap: () => _confirmDeleteAll(context, provider),
          ),
          const SizedBox(height: 20),
          const _SectionTitle('แหล่งข้อมูลและคำชี้แจง'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('น้ำท่วมยะลา (Yala Flood Watch) v${AppConfig.appVersion}'),
            subtitle: Text(
              'สูตรเตือนภัย: formula_version = ${AppConfig.formulaVersion}\n'
              'โหมดข้อมูล: ${provider.snapshot?.sourceLabel ?? 'ThaiWater Live 14 สถานี'}\n'
              'แผนที่ฐาน: Google Maps + ขอบเขต 8 อำเภอ จ.ยะลา · เวลามาตรฐาน: ประเทศไทย (UTC+7)\n'
              '5 ฐานข้อมูล: ThaiWater น้ำ 14 สถานี + ฝน 87 สถานี + เขื่อนบางลาง + Open-Meteo 72h + GloFAS 7d\n\n'
              '${AppConfig.lifeSafetyDisclaimerTh}',
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
