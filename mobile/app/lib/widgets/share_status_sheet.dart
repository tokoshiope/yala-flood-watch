import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// สร้างข้อความสรุปสถานการณ์น้ำแบบ 4 ภาษาสมบูรณ์ (ไม่รั่วภาษาไทยใน en/zh/ms)
String buildFloodShareText({
  required AppStrings strings,
  required AlertProvider provider,
  required String placeLabel,
  required String amphoeTh,
  required int level,
  String? exposureZone,
}) =>
    _ShareStatusBody.composeShareText(
      strings: strings,
      provider: provider,
      placeLabel: placeLabel,
      amphoeTh: amphoeTh,
      level: level,
      exposureZone: exposureZone,
    );

/// การ์ดแชร์รายงานสถานการณ์น้ำแบบ Zero-UGC / Zero-Server PII (แชร์เข้ากลุ่ม LINE ครอบครัว/หมู่บ้านใน 1 แตะ)
Future<void> showShareStatusSheet(
  BuildContext context, {
  required AlertProvider provider,
  required String placeLabel,
  required String amphoeTh,
  required int level,
  String? exposureZone,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _ShareStatusBody(
      provider: provider,
      placeLabel: placeLabel,
      amphoeTh: amphoeTh,
      level: level,
      exposureZone: exposureZone,
    ),
  );
}

class _ShareStatusBody extends StatelessWidget {
  const _ShareStatusBody({
    required this.provider,
    required this.placeLabel,
    required this.amphoeTh,
    required this.level,
    this.exposureZone,
  });

  final AlertProvider provider;
  final String placeLabel;
  final String amphoeTh;
  final int level;
  final String? exposureZone;

  /// สร้างข้อความสรุปสถานการณ์น้ำแบบ 4 ภาษาสมบูรณ์ (ไม่รั่วภาษาไทยใน en/zh/ms)
  static String composeShareText({
    required AppStrings strings,
    required AlertProvider provider,
    required String placeLabel,
    required String amphoeTh,
    required int level,
    String? exposureZone,
  }) {
    final ampDisplay = strings.amphoe(amphoeTh);
    final lvLabel = strings.alertLevelLabel(level);
    final action = strings.alertLevelAction(level);
    final dam = provider.snapshot?.bangLangDam;
    final ampSummary = provider.snapshot?.byAmphoe(amphoeTh);
    final updated = provider.lastUpdated != null
        ? strings.formatTime(provider.lastUpdated!)
        : '';
    final leadRaw = ampSummary?.leadTimeHours;
    final leadFormatted = (leadRaw != null && leadRaw.isNotEmpty)
        ? strings.formatLeadTime(leadRaw)
        : '';

    final lines = <String>[
      '🌊 ${strings.get('app_title')} ($ampDisplay)',
      '📍 $placeLabel · ${strings.get('share_level_prefix')} $level ($lvLabel)',
      if (exposureZone != null && exposureZone.isNotEmpty)
        '🗺️ ${strings.get('exposure_zone_label')}: ${strings.zoneBadgeText(exposureZone)}',
      if (dam?.storagePercent != null)
        '🏞️ ${strings.get('dam_title')}: ${dam!.storagePercent!.toStringAsFixed(1)}%',
      if (leadFormatted.isNotEmpty)
        '⏱️ ${strings.get('share_lead_time_label')}: $leadFormatted',
      '✅ $action',
      if (updated.isNotEmpty) '🕒 $updated',
      strings.get('share_emergency_line'),
      '🔗 ${AppConfig.webGuideUrl}',
    ];
    return lines.join('\n');
  }

  Future<void> _shareViaLine(BuildContext context, String text, AppStrings strings) async {
    final encoded = Uri.encodeComponent(text);
    final uri = Uri.parse('https://line.me/R/share?text=$encoded');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.get('share_copied_snack'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = provider.strings;
    final lv = AlertLevel.fromValue(level);
    final cs = Theme.of(context).colorScheme;
    final dam = provider.snapshot?.bangLangDam;
    final ampSummary = provider.snapshot?.byAmphoe(amphoeTh);
    final shareText = composeShareText(
      strings: strings,
      provider: provider,
      placeLabel: placeLabel,
      amphoeTh: amphoeTh,
      level: level,
      exposureZone: exposureZone,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.get('share_sheet_title'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            // Official-grade Visual Status Card Preview
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: lv.color, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: lv.color,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$placeLabel · ${strings.amphoe(amphoeTh)}',
                            style: TextStyle(
                              color: lv.onSolidColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${lv.value} · ${strings.alertLevelLabel(lv.value)}',
                            style: TextStyle(
                              color: lv.onSolidColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.alertLevelAction(lv.value),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            if (dam?.storagePercent != null)
                              Text(
                                '${strings.get('dam_title')}: ${dam!.storagePercent!.toStringAsFixed(1)}%',
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                              ),
                            if (ampSummary?.leadTimeHours != null &&
                                ampSummary!.leadTimeHours!.isNotEmpty)
                              Text(
                                '⏱ ${strings.formatLeadTime(ampSummary.leadTimeHours!)}',
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                              ),
                            if (provider.lastUpdated != null)
                              Text(
                                strings.formatTime(provider.lastUpdated!),
                                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      // WCAG AA >= 4.5:1 contrast with white foreground text
                      backgroundColor: const Color(0xFF00883A),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _shareViaLine(context, shareText, strings),
                    icon: const Icon(Icons.send_rounded, size: 17),
                    label: Text(
                      strings.get('share_line_btn'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: shareText));
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(strings.get('share_copied_snack'))),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    label: Text(
                      strings.get('share_copy_btn'),
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
