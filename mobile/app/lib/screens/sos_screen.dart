import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';
import 'package:yala_flood_app/models/sos_request.dart';
import 'package:yala_flood_app/services/community_report_service.dart';
import 'package:yala_flood_app/services/sos_dispatch_service.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// หน้า SOS ขอความช่วยเหลือ (Option C — v1.0):
/// 1) เบอร์ฉุกเฉินยืนยันแล้ว (1784 / 073-203559 / 073-212345 / 1669) + LINE/Facebook
/// 2) ปลดล็อคส่ง SOS จริงแบบ Zero-Server PII (SMS ใช้ได้แม้เน็ตล่ม · LINE Share · คัดลอกพร้อมพิกัด · โทรด่วน)
/// 3) รายงานสถานการณ์น้ำชุมชน (Tier C · ไม่ระบุตัวตน · ปัดเศษพิกัด ~110 ม. · ลบอัตโนมัติ 90 วัน)
class SosScreen extends StatefulWidget {
  const SosScreen({
    super.key,
    @visibleForTesting this.initialPositionOverride,
  });

  final Position? initialPositionOverride;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _communityDepthController = TextEditingController();
  final TextEditingController _communityNoteController = TextEditingController();

  String _type = kSosTypes.first;
  Position? _position;
  LocationStatus _locationStatus = LocationStatus.idle;
  String? _locationError;
  bool _sending = false;

  String _communityAmphoe = AppConfig.riskAmphoeTh.first;
  String _communityType = kCommunityReportTypes.first;
  bool _communityAmphoeUserPicked = false;
  bool _submittingCommunity = false;
  int _lastHandledResetVersion = 0;

  @override
  void initState() {
    super.initState();
    _lastHandledResetVersion = context.read<AlertProvider>().dataResetVersion;
    if (widget.initialPositionOverride != null) {
      _position = widget.initialPositionOverride;
      _locationStatus = LocationStatus.ready;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<AlertProvider>();
    if (!_communityAmphoeUserPicked) {
      final selected = provider.settings.selectedAmphoeTh;
      if (selected != null && AppConfig.riskAmphoeTh.contains(selected)) {
        _communityAmphoe = selected;
      }
    }
    final resetVer = provider.dataResetVersion;
    if (resetVer != _lastHandledResetVersion) {
      _lastHandledResetVersion = resetVer;
      _position = null;
      _locationStatus = LocationStatus.idle;
      _locationError = null;
      _phoneController.clear();
      _noteController.clear();
      _communityDepthController.clear();
      _communityNoteController.clear();
      _communityAmphoeUserPicked = false;
      _communityAmphoe = AppConfig.riskAmphoeTh.first;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _noteController.dispose();
    _communityDepthController.dispose();
    _communityNoteController.dispose();
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
      if (!mounted) return;
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
      final provider = context.read<AlertProvider>();
      final assessed = provider.evaluateCoordinates(
        position.latitude,
        position.longitude,
        isGps: true,
      );
      setState(() {
        _position = position;
        _locationStatus = LocationStatus.ready;
        if (!_communityAmphoeUserPicked &&
            assessed.amphoeTh != null &&
            AppConfig.riskAmphoeTh.contains(assessed.amphoeTh)) {
          _communityAmphoe = assessed.amphoeTh!;
        }
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

  Future<bool> _call(String number, AppStrings strings, {bool showSnack = true}) async {
    final sanitized = number.replaceAll(RegExp(r'[^0-9+*#]'), '');
    if (sanitized.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: sanitized);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${strings.get('cannot_call')} ($number)')),
      );
    }
    return ok;
  }

  Future<bool> _openExternalUrl(String url, AppStrings strings, {bool showSnack = true}) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.get('cannot_open_link'))),
      );
    }
    return ok;
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
    final provider = context.read<AlertProvider>();
    final now = DateTime.now();
    final pinAssessment = provider.evaluateCoordinates(
      _position!.latitude,
      _position!.longitude,
      isGps: true,
    );
    final note = _noteController.text.trim();
    final request = SosRequest(
      id: 'sos-${now.millisecondsSinceEpoch}',
      typeTh: _type,
      createdAt: now,
      lat: _position!.latitude,
      lng: _position!.longitude,
      phone: phone,
      note: note,
      amphoeTh: pinAssessment.amphoeTh,
      status: SosStatus.pending,
      statusHistory: const [SosStatus.pending],
    );
    provider.addSosRequest(request);
    if (!mounted) return;
    setState(() => _sending = false);

    await _openDispatchSheet(
      request: request,
      strings: strings,
      accuracyMeters: _position!.accuracy,
      pinAssessment: pinAssessment,
    );
  }

  Future<void> _openDispatchSheet({
    required SosRequest request,
    required AppStrings strings,
    double? accuracyMeters,
    UserPinAssessment? pinAssessment,
  }) async {
    final provider = context.read<AlertProvider>();
    final assessment = pinAssessment ??
        provider.evaluateCoordinates(request.lat, request.lng, isGps: true);
    final message = SosDispatchService.buildSosMessage(
      strings: strings,
      typeTh: request.typeTh,
      lat: request.lat,
      lng: request.lng,
      timestamp: request.createdAt,
      accuracyMeters: accuracyMeters,
      phone: request.phone,
      note: request.note,
      pinAssessment: assessment,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) => _SosDispatchSheet(
        strings: strings,
        request: request,
        message: message,
        assessment: assessment,
        onSendSms: () async {
          final uri = SosDispatchService.buildSmsUri(message);
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (ok) {
            provider.updateSosDispatchedVia(request.id, 'sms');
            return strings.sosDispatchedViaLabel('sms');
          }
          await Clipboard.setData(ClipboardData(text: message));
          provider.updateSosDispatchedVia(request.id, 'clipboard');
          return strings.get('sos_cannot_open_sms');
        },
        onShareLine: () async {
          await Clipboard.setData(ClipboardData(text: message));
          final uri = SosDispatchService.buildLineShareUri(message);
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          provider.updateSosDispatchedVia(request.id, ok ? 'line' : 'clipboard');
          return ok
              ? strings.sosDispatchedViaLabel('line')
              : strings.get('sos_dispatch_copied');
        },
        onCopy: () async {
          await Clipboard.setData(ClipboardData(text: message));
          provider.updateSosDispatchedVia(request.id, 'clipboard');
          return strings.get('sos_dispatch_copied');
        },
        onCopyAndOpenLine: (url) async {
          await Clipboard.setData(ClipboardData(text: message));
          final ok = await _openExternalUrl(url, strings, showSnack: false);
          provider.updateSosDispatchedVia(request.id, ok ? 'line' : 'clipboard');
          return strings.get('sos_dispatch_copied');
        },
        onCall: (number) async {
          final ok = await _call(number, strings, showSnack: false);
          if (ok) {
            provider.updateSosDispatchedVia(request.id, 'call');
            return strings.sosDispatchedViaLabel('call');
          }
          return '${strings.get('cannot_call')} ($number)';
        },
      ),
    );
  }

  Future<void> _submitCommunityReport(AppStrings strings) async {
    final provider = context.read<AlertProvider>();
    final rawDepth = _communityDepthController.text.trim();
    int? depthCm;
    if (rawDepth.isNotEmpty) {
      depthCm = int.tryParse(rawDepth);
      if (depthCm == null || depthCm < 0 || depthCm > 1000) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.get('community_report_invalid_depth'))),
        );
        return;
      }
    }

    // ใช้พิกัด GPS เฉพาะเมื่อตรงกับอำเภอที่เลือก มิฉะนั้นใช้จุดศูนย์กลางของอำเภอที่เลือก (ปัดเศษ ~110 ม. ใน Service เสมอ)
    double lat;
    double lng;
    final gpsMatchesSelectedAmphoe = _position != null &&
        CommunityReportService.isWithinYalaBbox(
          _position!.latitude,
          _position!.longitude,
        ) &&
        provider
                .evaluateCoordinates(
                  _position!.latitude,
                  _position!.longitude,
                  isGps: true,
                )
                .amphoeTh ==
            _communityAmphoe;
    if (gpsMatchesSelectedAmphoe) {
      lat = _position!.latitude;
      lng = _position!.longitude;
    } else {
      AmphoeBoundary? matchedBoundary;
      for (final b in provider.boundaries) {
        if (b.amphoeTh == _communityAmphoe) {
          matchedBoundary = b;
          break;
        }
      }
      if (matchedBoundary != null) {
        lat = matchedBoundary.centroid.latitude;
        lng = matchedBoundary.centroid.longitude;
      } else {
        lat = AppConfig.defaultLat;
        lng = AppConfig.defaultLng;
      }
    }

    setState(() => _submittingCommunity = true);
    final result = await provider.submitCommunityReport(
      amphoeTh: _communityAmphoe,
      reportType: _communityType,
      lat: lat,
      lng: lng,
      waterDepthCm: depthCm,
      noteTh: _communityNoteController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submittingCommunity = false);

    final snackKey = switch (result.status) {
      CommunitySubmitStatus.success => 'community_report_success',
      CommunitySubmitStatus.rateLimited => 'community_report_rate_limited',
      CommunitySubmitStatus.outsideYala => 'community_report_outside_yala',
      CommunitySubmitStatus.notConfigured => 'community_report_not_configured',
      CommunitySubmitStatus.invalidInput => 'community_report_invalid_depth',
      CommunitySubmitStatus.networkError => 'community_report_error',
    };
    if (result.ok) {
      _communityDepthController.clear();
      _communityNoteController.clear();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.get(snackKey))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final strings = provider.strings;
    final gpsAssessment = _position == null
        ? null
        : provider.evaluateCoordinates(
            _position!.latitude,
            _position!.longitude,
            isGps: true,
          );

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
            assessment: gpsAssessment,
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
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLength: 200,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: strings.get('sos_note_label'),
              hintText: strings.get('sos_note_hint'),
              prefixIcon: const Icon(Icons.notes),
              border: const OutlineInputBorder(),
            ),
          ),
          if (provider.sosRequests.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RequestList(
              strings: strings,
              requests: provider.sosRequests,
              onAdvance: provider.advanceSosStatus,
              onResend: (req) => _openDispatchSheet(
                request: req,
                strings: strings,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _CommunityReportCard(
            strings: strings,
            selectedAmphoe: _communityAmphoe,
            selectedType: _communityType,
            depthController: _communityDepthController,
            noteController: _communityNoteController,
            submitting: _submittingCommunity,
            configured: provider.communityReportConfigured,
            recentReports: provider.recentCommunityReports,
            onAmphoeChanged: (val) {
              if (val == null) return;
              setState(() {
                _communityAmphoe = val;
                _communityAmphoeUserPicked = true;
              });
            },
            onTypeChanged: (val) => setState(() => _communityType = val),
            onSubmit: () => _submitCommunityReport(strings),
          ),
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
            color: isDark ? const Color(0xFFFF8A80) : const Color(AppConfig.colorDanger),
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
      height: 136,
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
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosDispatchSheet extends StatefulWidget {
  const _SosDispatchSheet({
    required this.strings,
    required this.request,
    required this.message,
    required this.assessment,
    required this.onSendSms,
    required this.onShareLine,
    required this.onCopy,
    required this.onCopyAndOpenLine,
    required this.onCall,
  });

  final AppStrings strings;
  final SosRequest request;
  final String message;
  final UserPinAssessment assessment;
  final Future<String?> Function() onSendSms;
  final Future<String?> Function() onShareLine;
  final Future<String?> Function() onCopy;
  final Future<String?> Function(String url) onCopyAndOpenLine;
  final Future<String?> Function(String number) onCall;

  @override
  State<_SosDispatchSheet> createState() => _SosDispatchSheetState();
}

class _SosDispatchSheetState extends State<_SosDispatchSheet> {
  String? _statusFeedback;

  Future<void> _runAction(Future<String?> Function() action) async {
    final msg = await action();
    if (!mounted || msg == null || msg.isEmpty) return;
    setState(() => _statusFeedback = msg);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // WCAG AA >= 4.5:1 on both Light (#04783A = 5.60:1) & Dark (#4ADE80 = 9.80:1)
    final lineColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF04783A);
    final dangerIconColor =
        isDark ? const Color(0xFFFF8A80) : const Color(AppConfig.colorDanger);
    final previewBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final previewText = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final bannerBg = isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5);
    final bannerBorder = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    final bannerText = isDark ? const Color(0xFFECFDF5) : const Color(0xFF064E3B);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.sos, color: dangerIconColor, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.strings.get('sos_dispatch_title'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                if (_statusFeedback != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: bannerBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: bannerBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle_outline, size: 18, color: bannerText),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusFeedback!,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: bannerText,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
              children: [
                Text(
                  widget.strings.get('sos_dispatch_sub'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                // พิกัดตัวใหญ่สำหรับอ่านออกเสียงให้เจ้าหน้าที่ 1784 ฟังระหว่างคุยสาย
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: previewBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.request.lat.toStringAsFixed(6)}, ${widget.request.lng.toStringAsFixed(6)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: previewText,
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (widget.assessment.amphoeTh != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (widget.assessment.tumbonTh != null)
                              widget.strings.tumbonName(
                                widget.assessment.tumbonTh!,
                                widget.assessment.tumbonEn,
                              ),
                            widget.strings.amphoe(widget.assessment.amphoeTh!),
                          ].join(', '),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: previewText,
                          ),
                        ),
                      ],
                      const Divider(height: 16),
                      SelectableText(
                        widget.message,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: previewText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // 1. ส่ง SMS จริง (ทำงานได้แม้เน็ตล่ม)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(AppConfig.colorDanger),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _runAction(widget.onSendSms),
                    icon: const Icon(Icons.sms),
                    label: Text(
                      widget.strings.get('sos_dispatch_sms'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // 2. ส่งต่อผ่าน LINE (ใช้สีเขียวเข้ม #04783A เพื่อให้คอนทราสต์ขาว >= 4.5:1 ตาม WCAG AA)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF04783A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _runAction(widget.onShareLine),
                    icon: const Icon(Icons.chat),
                    label: Text(
                      widget.strings.get('sos_dispatch_line'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // 3. คัดลอกข้อความ + พิกัด
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _runAction(widget.onCopy),
                    icon: const Icon(Icons.copy),
                    label: Text(widget.strings.get('sos_dispatch_copy')),
                  ),
                ),
                const SizedBox(height: 8),
                // ปุ่มลัดคัดลอกแล้วเปิด LINE ทางการทันที
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: lineColor,
                        side: BorderSide(color: lineColor),
                      ),
                      onPressed: () =>
                          _runAction(() => widget.onCopyAndOpenLine(AppConfig.lineDdpmUrl)),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: Text(
                        widget.strings.get('sos_dispatch_copy_ddpm'),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: lineColor,
                        side: BorderSide(color: lineColor),
                      ),
                      onPressed: () => _runAction(
                        () => widget.onCopyAndOpenLine(AppConfig.lineYalaCityUrl),
                      ),
                      icon: const Icon(Icons.chat_bubble_outline, size: 16),
                      label: Text(
                        widget.strings.get('sos_dispatch_copy_city'),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  widget.strings.get('sos_dispatch_call_section'),
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
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _runAction(() => widget.onCall(AppConfig.emergencyDDPM)),
                      icon: const Icon(Icons.call, size: 16),
                      label: const Text('1784'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _runAction(() => widget.onCall(AppConfig.emergencyYalaCenter)),
                      icon: const Icon(Icons.call, size: 16),
                      label: const Text(AppConfig.emergencyYalaCenterDisplay),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () =>
                          _runAction(() => widget.onCall(AppConfig.emergencyMedical)),
                      icon: const Icon(Icons.local_hospital, size: 16),
                      label: const Text('1669'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
    required this.assessment,
    required this.errorText,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final AppStrings strings;
  final LocationStatus status;
  final Position? position;
  final UserPinAssessment? assessment;
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
                [
                  '±${position!.accuracy.toStringAsFixed(0)} ${strings.get('unit_m')}',
                  if (assessment?.amphoeTh != null)
                    strings.amphoe(assessment!.amphoeTh!),
                  if (assessment?.elevationMsl != null)
                    '${assessment!.elevationMsl!.toStringAsFixed(1)} ${strings.get('unit_msl')}',
                ].join(' · '),
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
    // WCAG AA >= 4.5:1 on both Light & Dark surfaces
    final lineColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF04783A);
    final fbColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF145DBF);
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
    required this.onResend,
  });

  final AppStrings strings;
  final List<SosRequest> requests;
  final ValueChanged<String> onAdvance;
  final ValueChanged<SosRequest> onResend;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
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
                          color: request.status.colorFor(brightness),
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
                            color: request.status.colorFor(brightness),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        '${request.lat.toStringAsFixed(5)}, ${request.lng.toStringAsFixed(5)}',
                        if (request.amphoeTh != null)
                          strings.amphoe(request.amphoeTh!),
                        strings.relativeTime(request.createdAt),
                        if (request.dispatchedVia != null)
                          strings.sosDispatchedViaLabel(request.dispatchedVia!),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => onResend(request),
                          icon: const Icon(Icons.send, size: 15),
                          label: Text(strings.get('sos_dispatch_resend')),
                        ),
                        if (request.status.next != null)
                          TextButton(
                            onPressed: () => onAdvance(request.id),
                            child: Text('→ ${strings.sosStatusLabel(request.status.next!)}'),
                          ),
                      ],
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

class _CommunityReportCard extends StatelessWidget {
  const _CommunityReportCard({
    required this.strings,
    required this.selectedAmphoe,
    required this.selectedType,
    required this.depthController,
    required this.noteController,
    required this.submitting,
    required this.configured,
    required this.recentReports,
    required this.onAmphoeChanged,
    required this.onTypeChanged,
    required this.onSubmit,
  });

  final AppStrings strings;
  final String selectedAmphoe;
  final String selectedType;
  final TextEditingController depthController;
  final TextEditingController noteController;
  final bool submitting;
  final bool configured;
  final List<CommunityReport> recentReports;
  final ValueChanged<String?> onAmphoeChanged;
  final ValueChanged<String> onTypeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final infoBg = isDark ? const Color(0xFF0F2942) : const Color(0xFFEFF6FF);
    final infoBorder = isDark ? const Color(0xFF38BDF8) : const Color(0xFF93C5FD);
    final infoText = isDark ? const Color(0xFFE0F2FE) : const Color(0xFF1E3A8A);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.campaign_outlined,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(AppConfig.colorPrimary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.get('community_report_title'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              strings.get('community_report_sub'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: infoBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: infoBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: infoText),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      strings.get('community_report_pdpa_note'),
                      style: TextStyle(fontSize: 12, color: infoText, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('community-amphoe-$selectedAmphoe'),
              initialValue: AppConfig.riskAmphoeTh.contains(selectedAmphoe)
                  ? selectedAmphoe
                  : AppConfig.riskAmphoeTh.first,
              decoration: InputDecoration(
                labelText: strings.get('community_report_amphoe'),
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
              onChanged: onAmphoeChanged,
            ),
            const SizedBox(height: 10),
            Text(
              strings.get('community_report_type'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final type in kCommunityReportTypes)
                  ChoiceChip(
                    label: Text(strings.communityReportTypeLabel(type)),
                    selected: selectedType == type,
                    onSelected: (_) => onTypeChanged(type),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: depthController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: strings.get('community_report_depth_label'),
                hintText: strings.get('community_report_depth_hint'),
                prefixIcon: const Icon(Icons.water),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              maxLength: 280,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: strings.get('community_report_note_label'),
                hintText: strings.get('community_report_note_hint'),
                prefixIcon: const Icon(Icons.edit_note),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: submitting ? null : onSubmit,
                icon: submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  submitting
                      ? strings.get('community_report_submitting')
                      : strings.get('community_report_submit_btn'),
                ),
              ),
            ),
            if (!configured) ...[
              const SizedBox(height: 8),
              Text(
                strings.get('community_report_not_configured'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (recentReports.isNotEmpty) ...[
              const Divider(height: 22),
              Text(
                strings.get('community_recent_title'),
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              for (final rep in recentReports.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.water_drop_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                strings.amphoe(rep.amphoeTh),
                                strings.communityReportTypeLabel(rep.reportType),
                                if (rep.waterDepthCm != null)
                                  '~${rep.waterDepthCm} ${strings.get('unit_cm')}',
                              ].join(' · '),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (rep.noteTh != null && rep.noteTh!.isNotEmpty)
                              Text(
                                rep.noteTh!,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            Text(
                              strings.relativeTime(rep.createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
