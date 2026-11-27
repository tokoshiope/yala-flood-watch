import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/screens/guide_screen.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// หน้าตั้งค่า: เลือกภาษา 4 ภาษา (ไทย/อังกฤษ/จีน/มาเลเซีย), คำอธิบายระดับการแจ้งเตือน 1–5,
/// พื้นที่ติดตาม, เกณฑ์แจ้งเตือน, โหมดตัวอักษรใหญ่, PDPA และแหล่งข้อมูล
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmDeleteAll(
    BuildContext context,
    AlertProvider provider,
    AppStrings strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.get('delete_dialog_title')),
        content: Text(strings.get('delete_dialog_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.get('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(AppConfig.colorDanger),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.get('delete_confirm_btn')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteAllUserData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.get('delete_done_snack'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final settings = provider.settings;
    final strings = provider.strings;
    final cs = Theme.of(context).colorScheme;
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

          // คู่มือการใช้งานแอปและคู่มืออพยพหนีน้ำท่วม (ออฟไลน์ 100%)
          _SectionTitle(strings.get('guide_title')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.get('guide_card_sub'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const GuideScreen(initialTab: 0),
                          ),
                        ),
                        icon: const Icon(Icons.menu_book_outlined, size: 17),
                        label: Text(strings.get('guide_tab_app')),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const GuideScreen(initialTab: 1),
                          ),
                        ),
                        icon: const Icon(Icons.directions_run_rounded, size: 17),
                        label: Text(strings.get('guide_tab_evac')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // คำอธิบายระดับการแจ้งเตือน 1–5 เพื่อความเข้าใจชัดเจนของประชาชน
          _SectionTitle(strings.get('alert_guide_section')),
          _AlertLevelGuideCard(strings: strings),
          const SizedBox(height: 20),

          _SectionTitle(strings.get('area_section')),
          DropdownButtonFormField<String?>(
            initialValue: settings.selectedAmphoeTh,
            decoration: InputDecoration(
              labelText: strings.get('amphoe_dropdown_label'),
              prefixIcon: const Icon(Icons.location_city),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(strings.get('whole_province')),
              ),
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
            decoration: InputDecoration(
              labelText: strings.get('tumbon_dropdown_label'),
              prefixIcon: const Icon(Icons.map_outlined),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(strings.get('all_tumbons')),
              ),
              for (final tumbon in tumbons)
                if (tumbon.isNotEmpty)
                  DropdownMenuItem(
                    value: tumbon,
                    child: Text(
                      strings.tumbonName(
                        tumbon,
                        provider.tumbonEnOf(settings.selectedAmphoeTh, tumbon),
                      ),
                    ),
                  ),
            ],
            onChanged: (value) => provider.updateSettings(
              value == null
                  ? settings.copyWith(clearTumbon: true)
                  : settings.copyWith(selectedTumbonTh: value),
            ),
          ),
          const SizedBox(height: 20),

          _SectionTitle(strings.get('threshold_section')),
          DropdownButtonFormField<int>(
            initialValue: settings.warningLevel.clamp(2, 4),
            decoration: InputDecoration(
              labelText: strings.get('warn_level_label'),
              prefixIcon: const Icon(Icons.warning_amber),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: 2,
                child: Text('2 — ${strings.alertLevelLabel(2)}'),
              ),
              DropdownMenuItem(
                value: 3,
                child: Text('3 — ${strings.alertLevelLabel(3)}'),
              ),
              DropdownMenuItem(
                value: 4,
                child: Text('4 — ${strings.alertLevelLabel(4)}'),
              ),
            ],
            onChanged: (value) => provider.updateSettings(
              settings.copyWith(warningLevel: value ?? 3),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: settings.dangerLevel.clamp(3, 5),
            decoration: InputDecoration(
              labelText: strings.get('danger_level_label'),
              prefixIcon: const Icon(Icons.dangerous_outlined),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: 3,
                child: Text('3+ — ${strings.alertLevelLabel(3)}'),
              ),
              DropdownMenuItem(
                value: 4,
                child: Text('4+ — ${strings.alertLevelLabel(4)}'),
              ),
              DropdownMenuItem(
                value: 5,
                child: Text('5 — ${strings.alertLevelLabel(5)}'),
              ),
            ],
            onChanged: (value) => provider.updateSettings(
              settings.copyWith(dangerLevel: value ?? AppConfig.defaultDangerLevel),
            ),
          ),
          const SizedBox(height: 20),

          _SectionTitle(strings.get('notifications_section')),
          SwitchListTile(
            secondary: Icon(
              settings.quietMode
                  ? Icons.volume_off_outlined
                  : Icons.volume_up_outlined,
            ),
            title: Text(strings.get('sound_toggle')),
            subtitle: Text(strings.get('sound_toggle_sub')),
            value: !settings.quietMode,
            onChanged: (soundOn) =>
                provider.updateSettings(settings.copyWith(quietMode: !soundOn)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: Text(strings.get('notif_toggle')),
            subtitle: Text(strings.get('notif_toggle_sub')),
            value: settings.pushEnabled,
            onChanged: (value) =>
                provider.updateSettings(settings.copyWith(pushEnabled: value)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.text_fields),
            title: Text(strings.get('large_text_toggle')),
            subtitle: Text(strings.get('large_text_sub')),
            value: settings.largeTextMode,
            onChanged: (value) =>
                provider.updateSettings(settings.copyWith(largeTextMode: value)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_outlined),
            title: Text(strings.get('rain_score_toggle')),
            subtitle: Text(strings.get('rain_score_sub')),
            value: settings.rainScoreEnabled,
            onChanged: (value) =>
                provider.updateSettings(settings.copyWith(rainScoreEnabled: value)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: settings.refreshMinutes,
            decoration: InputDecoration(
              labelText: strings.get('refresh_interval_label'),
              prefixIcon: const Icon(Icons.update),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final mins in const [5, 10, 15, 30])
                DropdownMenuItem(
                  value: mins,
                  child: Text('$mins ${strings.get('minutes_unit')}'),
                ),
            ],
            onChanged: (value) => provider.updateSettings(
              settings.copyWith(refreshMinutes: value ?? 15),
            ),
          ),
          const SizedBox(height: 20),

          _SectionTitle(strings.get('pdpa_section')),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(strings.get('clear_cache_title')),
            subtitle: Text(strings.get('clear_cache_sub')),
            onTap: () async {
              await provider.clearCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(strings.get('cache_cleared_snack'))),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: Text(strings.get('clear_alerts_title')),
            subtitle: Text(strings.countItems(provider.alerts.length)),
            onTap: provider.clearAlerts,
          ),
          ListTile(
            leading: Icon(Icons.delete_forever, color: cs.error),
            title: Text(
              strings.get('delete_all_title'),
              style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(strings.get('delete_all_sub')),
            onTap: () => _confirmDeleteAll(context, provider, strings),
          ),
          const SizedBox(height: 20),

          _SectionTitle(strings.get('sources_section')),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text('${strings.get('app_title')} v${AppConfig.appVersion}'),
            subtitle: Text(
              '${strings.get('sources_desc')}\n\n${strings.get('life_safety_disclaimer')}',
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }
}

/// การ์ดคำอธิบายระดับการแจ้งเตือนทั้ง 5 ระดับ + หลักการไล่สีตามความสูงภูมิประเทศบนแผนที่
class _AlertLevelGuideCard extends StatelessWidget {
  const _AlertLevelGuideCard({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final lv in AlertLevel.values) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lv.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${lv.value}',
                      style: TextStyle(
                        color: lv.onSolidColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.alertLevelLabel(lv.value),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: lv.colorFor(brightness),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          strings.alertLevelDesc(lv.value),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '→ ${strings.alertLevelAction(lv.value)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (lv != AlertLevel.danger) const Divider(height: 16),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.terrain, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.get('alert_guide_map_note'),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface,
                        height: 1.35,
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
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
