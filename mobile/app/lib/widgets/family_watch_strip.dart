import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/saved_place.dart';
import 'package:yala_flood_app/services/voice_briefing_service.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/onboarding_sheet.dart';
import 'package:yala_flood_app/widgets/share_status_sheet.dart';

/// แถบสถานะ "บ้านและครอบครัว" ด้านบนของหน้าแผนที่:
/// - หากยังไม่เคยตั้งค่า แสดงการ์ด Onboarding 15 วินาทีแบบไม่บล็อกการใช้งาน
/// - เมื่อมีจุดเฝ้าระวัง แสดงคำตอบใน 3 วินาที (ระดับสี 1–5 + Zone + ปุ่มฟังเสียงออฟไลน์ + ปุ่มแชร์ LINE + เพิ่มจุดครอบครัวสูงสุด 5 จุด)
class FamilyWatchStrip extends StatelessWidget {
  const FamilyWatchStrip({
    super.key,
    required this.provider,
    required this.onFocusPoint,
  });

  final AlertProvider provider;
  final void Function(LatLng point, String amphoeTh) onFocusPoint;

  Future<void> _showAddPlaceDialog(BuildContext context) async {
    final strings = provider.strings;
    final labelCtrl = TextEditingController(
      text: provider.savedPlaces.isEmpty
          ? strings.get('place_preset_home')
          : strings.get('place_preset_parents'),
    );
    String selectedAmphoe =
        provider.settings.selectedAmphoeTh ?? AppConfig.riskAmphoeTh.first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(strings.get('family_add_dialog_title')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final key in const [
                      'place_preset_home',
                      'place_preset_parents',
                      'place_preset_school',
                    ])
                      ActionChip(
                        label: Text(
                          strings.get(key),
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => labelCtrl.text = strings.get(key),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: labelCtrl,
                  decoration: InputDecoration(
                    hintText: strings.get('family_label_hint'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedAmphoe,
                  decoration: InputDecoration(
                    labelText: strings.get('amphoe_dropdown_label'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final amp in AppConfig.riskAmphoeTh)
                      DropdownMenuItem(
                        value: amp,
                        child: Text(strings.amphoe(amp)),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => selectedAmphoe = v);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  strings.get('family_limit_note'),
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.get('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final text = labelCtrl.text.trim();
                if (text.isEmpty) return;
                await provider.addSavedPlace(
                  label: text,
                  amphoeTh: selectedAmphoe,
                );
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              child: Text(strings.get('family_save_btn')),
            ),
          ],
        ),
      ),
    );
    labelCtrl.dispose();
  }

  Future<void> _speakForPlace(
    BuildContext context,
    SavedPlace place,
    int level,
  ) async {
    final voice = VoiceBriefingService.instance;
    if (voice.isSpeaking.value) {
      await voice.stop();
      return;
    }
    final strings = provider.strings;
    final dam = provider.snapshot?.bangLangDam;
    final ampSummary = provider.snapshot?.byAmphoe(place.amphoeTh);
    final text = strings.voiceBriefingText(
      placeLabel: place.label,
      amphoeTh: place.amphoeTh,
      level: level,
      damPercent: dam?.storagePercent,
      leadTime: ampSummary?.leadTimeHours,
    );
    final ok = await voice.speak(text: text, langCode: strings.lang);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.get('voice_unavailable_snack'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = provider.strings;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final places = provider.savedPlaces;

    // 1. First-Time 15-second Onboarding Banner (non-blocking, skippable)
    if (!provider.onboardingDone && places.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F2744) : const Color(0xFFEAF4FF),
          border: Border(
            bottom: BorderSide(
              color: isDark ? const Color(0xFF1E3A5F) : const Color(0xFFBFDBFE),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.home_rounded, color: cs.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    strings.get('onboarding_banner_title'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    strings.get('onboarding_banner_sub'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            FilledButton(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              onPressed: () => showOnboardingSheet(context, provider),
              child: Text(
                strings.get('onboarding_start_btn'),
                style: const TextStyle(fontSize: 11.5),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: strings.get('onboarding_skip_btn'),
              onPressed: () => provider.completeOnboarding(
                languageCode: provider.settings.languageCode,
              ),
              icon: const Icon(Icons.close, size: 17),
            ),
          ],
        ),
      );
    }

    // 2. Compact Family Watchlist Strip (or "+ Add Home/Family" prompt if user skipped onboarding)
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: VoiceBriefingService.instance.isSpeaking,
        builder: (context, speaking, _) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final place in places) ...[
                  _buildPlaceChip(context, place, speaking),
                  const SizedBox(width: 8),
                ],
                if (places.length < SavedPlace.maxSavedPlaces)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _showAddPlaceDialog(context),
                    icon: const Icon(Icons.add_location_alt_outlined, size: 15),
                    label: Text(
                      places.isEmpty
                          ? strings.get('family_watch_title')
                          : strings.get('family_add_btn'),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmRemovePlace(BuildContext context, SavedPlace place) async {
    final strings = provider.strings;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.get('remove_place_title')),
        content: Text('${place.label} · ${strings.amphoe(place.amphoeTh)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.get('remove_place_confirm')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await provider.removeSavedPlace(place.id);
    }
  }

  Widget _buildPlaceChip(BuildContext context, SavedPlace place, bool speaking) {
    final strings = provider.strings;
    final cs = Theme.of(context).colorScheme;
    final eval = provider.assessSavedPlace(place);
    final lv = AlertLevel.fromValue(eval.level);

    return Material(
      color: cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onFocusPoint(place.point, place.amphoeTh),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: lv.colorFor(Theme.of(context).brightness),
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: lv.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${place.label} · ${strings.amphoe(place.amphoeTh)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  Text(
                    '${strings.alertLevelLabel(lv.value)} · ${strings.zoneBadgeText(eval.exposureZone)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: lv.colorFor(Theme.of(context).brightness),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: speaking
                    ? strings.get('voice_stop_btn')
                    : strings.get('voice_listen_btn'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _speakForPlace(context, place, lv.value),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(
                      speaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
                      size: 18,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: strings.get('share_status_btn'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => showShareStatusSheet(
                    context,
                    provider: provider,
                    placeLabel: place.label,
                    amphoeTh: place.amphoeTh,
                    level: lv.value,
                    exposureZone: eval.exposureZone,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(Icons.share_rounded, size: 17, color: cs.primary),
                  ),
                ),
              ),
              Tooltip(
                message: strings.get('remove_place_confirm'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _confirmRemovePlace(context, place),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Icon(Icons.close, size: 16, color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
