import 'package:material_ui/material_ui.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// หน้าตั้งค่าครั้งแรกภายใน 15 วินาที (เลือกภาษา + เลือกอำเภอบ้านของฉัน)
/// ทำให้ผู้ใช้ใหม่ได้รับ Push แจ้งเตือนตั้งแต่ระดับ 2 (เฝ้าระวัง) ของอำเภอตัวเองทันที
Future<void> showOnboardingSheet(
  BuildContext context,
  AlertProvider provider,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _OnboardingSheetBody(provider: provider),
  );
}

class _OnboardingSheetBody extends StatefulWidget {
  const _OnboardingSheetBody({required this.provider});

  final AlertProvider provider;

  @override
  State<_OnboardingSheetBody> createState() => _OnboardingSheetBodyState();
}

class _OnboardingSheetBodyState extends State<_OnboardingSheetBody> {
  late String _lang;
  String? _selectedAmphoe;

  @override
  void initState() {
    super.initState();
    _lang = widget.provider.settings.languageCode;
    _selectedAmphoe = widget.provider.settings.selectedAmphoeTh ?? 'เมืองยะลา';
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(_lang);
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop_rounded, color: cs.primary, size: 26),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.get('onboarding_sheet_title'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              strings.get('onboarding_step_lang'),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in AppStrings.supportedLanguages)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _lang == entry.key,
                    onSelected: (_) => setState(() => _lang = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              strings.get('onboarding_step_amphoe'),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(strings.get('whole_province')),
                  selected: _selectedAmphoe == null,
                  onSelected: (_) => setState(() => _selectedAmphoe = null),
                ),
                for (final amp in AppConfig.riskAmphoeTh)
                  ChoiceChip(
                    label: Text(strings.amphoe(amp)),
                    selected: _selectedAmphoe == amp,
                    onSelected: (_) => setState(() => _selectedAmphoe = amp),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                TextButton(
                  onPressed: () async {
                    await widget.provider.completeOnboarding(
                      languageCode: _lang,
                      homeAmphoeTh: null,
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Text(strings.get('onboarding_skip_btn')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await widget.provider.completeOnboarding(
                        languageCode: _lang,
                        homeAmphoeTh: _selectedAmphoe,
                        homeLabel: strings.get('place_preset_home'),
                      );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(
                      strings.get('onboarding_done_btn'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
