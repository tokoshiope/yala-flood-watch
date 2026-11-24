import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/sos_request.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// หน้า SOS ขอความช่วยเหลือ: เบอร์ฉุกเฉินยืนยันแล้ว (1784 / 073-203559 / 073-212345 / 1669),
/// PDPA Consent ก่อนขอพิกัด GPS และบันทึกคำขอในเครื่อง รองรับ iOS Dark Mode & 4 ภาษาเต็มรูปแบบ
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _type = kSosTypes.first;
  Position? _position;
  LocationStatus _locationStatus = LocationStatus.idle;
  String? _locationError;
  bool _sending = false;
  int _lastHandledResetVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final resetVer = context.watch<AlertProvider>().dataResetVersion;
    if (resetVer != _lastHandledResetVersion) {
      _lastHandledResetVersion = resetVer;
      _position = null;
      _locationStatus = LocationStatus.idle;
      _locationError = null;
      _phoneController.clear();
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _requestConsentAndLocate() async {
    final provider = context.read<AlertProvider>();
    final strings = provider.strings;
    if (!provider.gpsConsentGranted) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.get('gps_consent_title')),
          content: Text(strings.get('gps_consent_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.get('gps_decline')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.get('gps_accept')),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      await provider.setGpsConsent(true);
    }
    await _locate(strings);
  }

  Future<void> _locate(AppStrings strings) async {
    setState(() {
      _locationStatus = LocationStatus.searching;
      _locationError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationStatus = LocationStatus.denied;
          _locationError = strings.get('gps_permission_denied');
        });
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationStatus = LocationStatus.denied;
          _locationError = strings.get('gps_service_disabled');
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _locationStatus = LocationStatus.ready;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _locationStatus = LocationStatus.error;
        _locationError = '$error';
      });
    }
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _call(String number, AppStrings strings) async {
    final sanitized = number.replaceAll(RegExp(r'[^0-9+*#]'), '');
    if (sanitized.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: sanitized);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.get('cannot_call')} ($number)')),
      );
    }
  }

  Future<void> _openExternalUrl(String url, AppStrings strings) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.get('cannot_open_link'))),
      );
    }
  }

  Future<void> _sendSos(AppStrings strings) async {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && phone.replaceAll(RegExp(r'[^0-9]'), '').length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.get('phone_invalid'))),
      );
      return;
    }
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.get('sos_need_gps'))),
      );
      return;
    }

    setState(() => _sending = true);
    final now = DateTime.now();
    final request = SosRequest(
      id: 'sos-${now.millisecondsSinceEpoch}',
      typeTh: _type,
      createdAt: now,
      lat: _position!.latitude,
      lng: _position!.longitude,
      phone: phone,
      note: '',
      status: SosStatus.pending,
      statusHistory: const [SosStatus.pending],
    );
    context.read<AlertProvider>().addSosRequest(request);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.get('sos_saved_snack'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final strings = provider.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.get('sos_title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _SafetyBanner(strings: strings),
          const SizedBox(height: 12),
          _CallButtons(
            strings: strings,
            onCall: (phone) => _call(phone, strings),
            onOpenUrl: (u) => _openExternalUrl(u, strings),
          ),
          const SizedBox(height: 12),
          _SosButton(
            strings: strings,
            onPressed: _sending ? null : () => _sendSos(strings),
          ),
          const SizedBox(height: 12),
          _TypeSelector(
            strings: strings,
            selected: _type,
            onChanged: (value) => setState(() => _type = value),
          ),
          const SizedBox(height: 12),
          _LocationCard(
            strings: strings,
            status: _locationStatus,
            position: _position,
            errorText: _locationError,
            onRetry: _requestConsentAndLocate,
            onOpenSettings: _openLocationSettings,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: strings.get('phone_input_label'),
              hintText: strings.get('phone_input_hint'),
              prefixIcon: const Icon(Icons.phone),
              border: const OutlineInputBorder(),
            ),
          ),
          if (provider.sosRequests.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RequestList(
              strings: strings,
              requests: provider.sosRequests,
              onAdvance: provider.advanceSosStatus,
            ),
          ],
        ],
      ),
    );
  }
}

enum LocationStatus { idle, searching, ready, denied, error }

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
            color: isDark ? const Color(0xFFFF8A80) : const Color(0xFFB71C1C),
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

class _SosButton extends StatelessWidget {
  const _SosButton({required this.strings, required this.onPressed});

  final AppStrings strings;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(AppConfig.colorDanger),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sos, size: 42),
            const SizedBox(height: 4),
            Text(
              strings.get('sos_save_btn'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              strings.get('sos_save_sub'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({
    required this.strings,
    required this.selected,
    required this.onChanged,
  });

  final AppStrings strings;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.get('sos_help_type'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in kSosTypes)
                  ChoiceChip(
                    label: Text(strings.sosTypeLabel(type)),
                    selected: selected == type,
                    onSelected: (_) => onChanged(type),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.strings,
    required this.status,
    required this.position,
    required this.errorText,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final AppStrings strings;
  final LocationStatus status;
  final Position? position;
  final String? errorText;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.my_location, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.get('gps_card_title'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (status == LocationStatus.searching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.my_location, size: 16),
                    label: Text(strings.get('gps_locate_btn')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (status == LocationStatus.ready && position != null) ...[
              Text(
                '${position!.latitude.toStringAsFixed(6)}, ${position!.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '±${position!.accuracy.toStringAsFixed(0)} ${strings.get('unit_m')} (1784)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (status == LocationStatus.searching) ...[
              Text(strings.get('gps_searching')),
            ] else if (status == LocationStatus.idle) ...[
              Text(
                strings.get('gps_idle_hint'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              Text(
                errorText ?? strings.get('gps_permission_denied'),
                style: TextStyle(color: cs.error),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings),
                label: Text(strings.get('gps_open_settings')),
              ),
            ],
          ],
        ),
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
              style: Theme.of(context).textTheme.titleSmall,
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
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lineColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF06C755);
    final fbColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1877F2);
    final dangerIconColor = isDark ? const Color(0xFFFF8A80) : const Color(AppConfig.colorDanger);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    Text(
                      strings.contactSubtitle(number, ''),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => onCall(number),
                child: Text(display),
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
                      label: Text(lineLabel ?? 'LINE', style: const TextStyle(fontSize: 12)),
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
                      label: Text(fbLabel ?? 'Facebook', style: const TextStyle(fontSize: 12)),
                    ),
                ],
              ),
            ),
          ],
          const Divider(height: 14),
        ],
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({
    required this.strings,
    required this.requests,
    required this.onAdvance,
  });

  final AppStrings strings;
  final List<SosRequest> requests;
  final ValueChanged<String> onAdvance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.get('sos_local_history'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final request in requests)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          request.status.icon,
                          size: 18,
                          color: request.status.colorFor(Theme.of(context).brightness),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            strings.sosTypeLabel(request.typeTh),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          strings.sosStatusLabel(request.status),
                          style: TextStyle(
                            color: request.status.colorFor(Theme.of(context).brightness),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${request.lat.toStringAsFixed(5)}, ${request.lng.toStringAsFixed(5)}'
                      ' · ${strings.relativeTime(request.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (request.status.next != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => onAdvance(request.id),
                          child: Text('→ ${strings.sosStatusLabel(request.status.next!)}'),
                        ),
                      ),
                    const Divider(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
