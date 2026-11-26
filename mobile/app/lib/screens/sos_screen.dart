import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// หน้าช่องทางฉุกเฉิน: คงเฉพาะช่องทางติดต่อทางการที่ยืนยันแล้ว (เบอร์โทร · LINE · Facebook)
/// ไม่มีฟอร์มส่งข้อความ SOS และไม่มีระบบโพสต์เนื้อหาสาธารณะ (0% UGC · 0% Server PII)
class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  Future<bool> _call(
    BuildContext context,
    String number,
    AppStrings strings,
  ) async {
    final sanitized = number.replaceAll(RegExp(r'[^0-9+*#]'), '');
    if (sanitized.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: sanitized);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.get('cannot_call')} ($number)')),
      );
    }
    return ok;
  }

  Future<bool> _openExternalUrl(
    BuildContext context,
    String url,
    AppStrings strings,
  ) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.get('cannot_open_link'))),
      );
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AlertProvider>().strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.get('sos_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SafetyBanner(strings: strings),
          const SizedBox(height: 12),
          _CallButtons(
            strings: strings,
            onCall: (phone) => _call(context, phone, strings),
            onOpenUrl: (u) => _openExternalUrl(context, u, strings),
          ),
        ],
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3B1219) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFFEF5350) : const Color(0xFFEF9A9A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.health_and_safety,
            color: isDark
                ? const Color(0xFFFF8A80)
                : const Color(AppConfig.colorDanger),
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.get('life_safety_disclaimer'),
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? const Color(0xFFFFCDD2) : const Color(0xFF7F0000),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButtons extends StatelessWidget {
  const _CallButtons({
    required this.strings,
    required this.onCall,
    required this.onOpenUrl,
  });

  final AppStrings strings;
  final ValueChanged<String> onCall;
  final ValueChanged<String> onOpenUrl;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.get('emergency_channels'),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _callTile(
              context,
              number: AppConfig.emergencyDDPM,
              display: '1784',
              icon: Icons.sos,
              lineLabel: 'LINE @1784DDPM',
              lineUrl: AppConfig.lineDdpmUrl,
              fbLabel: 'Facebook DDPM',
              fbUrl: AppConfig.fbDdpmUrl,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyYalaCenter,
              display: AppConfig.emergencyYalaCenterDisplay,
              icon: Icons.account_balance,
              lineLabel: 'LINE @1784DDPM',
              lineUrl: AppConfig.lineDdpmUrl,
              fbLabel: 'Facebook DDPM',
              fbUrl: AppConfig.fbDdpmUrl,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyYalaMunicipality,
              display: AppConfig.emergencyYalaMunicipalityDisplay,
              icon: Icons.fire_truck,
              lineLabel: 'LINE @yalacity',
              lineUrl: AppConfig.lineYalaCityUrl,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyMedical,
              display: '1669',
              icon: Icons.local_hospital,
              fbLabel: 'Facebook 1669',
              fbUrl: AppConfig.fbNiemsUrl,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyYalaHospital,
              display: AppConfig.emergencyYalaHospitalDisplay,
              icon: Icons.local_hospital_outlined,
              fbLabel: 'Facebook Yala Hospital',
              fbUrl: AppConfig.fbYalaHospitalUrl,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyDisaster,
              display: '199',
              icon: Icons.emergency,
              lineLabel: 'LINE @1784DDPM',
              lineUrl: AppConfig.lineDdpmUrl,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyArmyMtb46,
              display: AppConfig.emergencyArmyMtb46Display,
              icon: Icons.shield_outlined,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyPolice,
              display: '191',
              icon: Icons.local_police,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyVolunteer,
              display: '1677',
              icon: Icons.volunteer_activism,
              fbLabel: 'Facebook 1677',
              fbUrl: AppConfig.fbRuamduayUrl,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _callTile(
    BuildContext context, {
    required String number,
    required String display,
    required IconData icon,
    String? lineLabel,
    String? lineUrl,
    String? fbLabel,
    String? fbUrl,
    bool isLast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // WCAG AA >= 4.5:1 on both Light & Dark surfaces
    final lineColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF04783A);
    final fbColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF145DBF);
    final dangerIconColor = isDark
        ? const Color(0xFFFF8A80)
        : const Color(AppConfig.colorDanger);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: dangerIconColor.withValues(alpha: 0.16),
                child: Icon(icon, color: dangerIconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.contactTitle(number, number),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      strings.contactSubtitle(number, ''),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => onCall(number),
                icon: const Icon(Icons.call, size: 15),
                label: Text(display),
              ),
            ],
          ),
          if (lineUrl != null || fbUrl != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 50),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (lineUrl != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: lineColor,
                        side: BorderSide(color: lineColor),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => onOpenUrl(lineUrl),
                      icon: const Icon(Icons.chat_bubble_outline, size: 15),
                      label: Text(
                        lineLabel ?? 'LINE',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  if (fbUrl != null)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: fbColor,
                        side: BorderSide(color: fbColor),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => onOpenUrl(fbUrl),
                      icon: const Icon(Icons.facebook, size: 15),
                      label: Text(
                        fbLabel ?? 'Facebook',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (!isLast) const Divider(height: 14),
        ],
      ),
    );
  }
}
