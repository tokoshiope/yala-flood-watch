import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/sos_request.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// หน้า SOS ขอความช่วยเหลือ: เบอร์ฉุกเฉินยืนยันแล้ว (1784 / 073-203559 / 073-212345 / 1669),
/// PDPA Consent ก่อนขอพิกัด GPS และบันทึกคำขอในเครื่องแบบโปร่งใส
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// ขออนุญาตและแสดงคำชี้แจง PDPA ก่อนเรียก GPS (ไม่ดึงอัตโนมัติใน initState)
  Future<void> _requestConsentAndLocate() async {
    final provider = context.read<AlertProvider>();
    if (!provider.gpsConsentGranted) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('ขอความยินยอมใช้พิกัด GPS (PDPA)'),
          content: const Text(
            'แอปจะอ่านพิกัดของคุณเฉพาะขณะเปิดหน้านี้เท่านั้น เพื่อบันทึกประกอบคำขอ SOS ในเครื่องของคุณ '
            'โดยไม่มีการส่งออกหรือติดตามตำแหน่งพื้นหลัง คุณสามารถลบประวัติได้ทุกเมื่อในหน้าตั้งค่า',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('ไม่ยินยอม'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('ยินยอมและค้นหาพิกัด'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      await provider.setGpsConsent(true);
    }
    await _locate();
  }

  Future<void> _locate() async {
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
          _locationError =
              'ยังไม่ได้รับสิทธิ์ตำแหน่ง กด "เปิดการตั้งค่าตำแหน่ง" เพื่ออนุญาตเฉพาะขณะใช้งาน (When In Use)';
        });
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationStatus = LocationStatus.denied;
          _locationError = 'GPS ของเครื่องยังปิดอยู่ กรุณาเปิดบริการตำแหน่ง';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _position = position;
        _locationStatus = LocationStatus.ready;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _locationStatus = LocationStatus.error;
        _locationError = 'อ่านพิกัดไม่สำเร็จ: $error';
      });
    }
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถโทรได้จากเครื่องนี้ ($number)')),
      );
    }
  }

  Future<void> _sendSos() async {
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty && phone.replaceAll(RegExp(r'[^0-9]'), '').length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกเบอร์โทรที่ติดต่อได้ให้ถูกต้อง')),
      );
      return;
    }
    if (_position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากด "ค้นหาพิกัด GPS" เพื่อยืนยันตำแหน่งก่อนบันทึกคำขอ'),
        ),
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
      const SnackBar(
        content: Text(
          'บันทึกคำขอและพิกัดไว้ในเครื่องแล้ว (ยังไม่ส่งตรงถึงศูนย์) กรุณาโทร 1784 หรือ 073-203559 ทันที',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    // LOW-1 fix: หากผู้ใช้กด "ลบข้อมูลทั้งหมดของฉัน (PDPA)" ในหน้าตั้งค่า ให้ล้างพิกัด/เบอร์ในหน่วยความจำทันที
    if (!provider.gpsConsentGranted &&
        (_position != null || _phoneController.text.isNotEmpty)) {
      _position = null;
      _locationStatus = LocationStatus.idle;
      _locationError = null;
      _phoneController.clear();
    }
    return Scaffold(
      appBar: AppBar(title: const Text('ขอความช่วยเหลือ (SOS)')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const _SafetyBanner(),
          const SizedBox(height: 12),
          _CallButtons(onCall: _call),
          const SizedBox(height: 12),
          _SosButton(onPressed: _sending ? null : _sendSos),
          const SizedBox(height: 12),
          _TypeSelector(
            selected: _type,
            onChanged: (value) => setState(() => _type = value),
          ),
          const SizedBox(height: 12),
          _LocationCard(
            status: _locationStatus,
            position: _position,
            errorTh: _locationError,
            onRetry: _requestConsentAndLocate,
            onOpenSettings: _openLocationSettings,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'เบอร์โทรที่ติดต่อได้ (เก็บในเครื่องเท่านั้น)',
              hintText: 'เช่น 0812345678',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
          if (provider.sosRequests.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RequestList(
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
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.health_and_safety, color: Color(0xFFB71C1C), size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              AppConfig.lifeSafetyDisclaimerTh,
              style: TextStyle(fontSize: 12.5, color: Color(0xFF7F0000), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onPressed});

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
              'บันทึกคำขอ SOS พร้อมพิกัด (ในเครื่อง)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'โหมดทดลองยังไม่ส่งตรงถึงศูนย์ · เหตุด่วนให้กดโทร 1784 / 073-203559 ด้านบน',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

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
            Text('ประเภทความช่วยเหลือ', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in kSosTypes)
                  ChoiceChip(
                    label: Text(type),
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
    required this.status,
    required this.position,
    required this.errorTh,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final LocationStatus status;
  final Position? position;
  final String? errorTh;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
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
                    'พิกัด GPS ของคุณ (ขอสิทธิ์เมื่อกดเท่านั้น)',
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
                    label: const Text('ค้นหาพิกัด GPS'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (status == LocationStatus.ready && position != null) ...[
              Text(
                'ละติจูด ${position!.latitude.toStringAsFixed(6)}  '
                'ลองจิจูด ${position!.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'ความแม่นยำประมาณ ${position!.accuracy.toStringAsFixed(0)} เมตร (แจ้งเจ้าหน้าที่เมื่อโทร 1784)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (status == LocationStatus.searching) ...[
              const Text('กำลังค้นหาสัญญาณ GPS…'),
            ] else if (status == LocationStatus.idle) ...[
              Text(
                'กดปุ่ม "ค้นหาพิกัด GPS" เพื่อให้แสดงพิกัดสำหรับแจ้งเจ้าหน้าที่กู้ภัย (ไม่เก็บพิกัดพื้นหลัง)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else ...[
              Text(
                errorTh ?? 'ยังไม่สามารถระบุตำแหน่งได้',
                style: const TextStyle(color: Color(0xFFB71C1C)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings),
                label: const Text('เปิดการตั้งค่าตำแหน่ง'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CallButtons extends StatelessWidget {
  const _CallButtons({required this.onCall});

  final ValueChanged<String> onCall;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('โทรศัพท์ฉุกเฉิน (ตรวจสอบยืนยันแล้ว)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            _callTile(
              context,
              number: AppConfig.emergencyDDPM,
              display: '1784',
              title: 'สายด่วนนิรภัย กรม ปภ. (DDPM)',
              subtitle: 'โทรฟรี 24 ชม. · LINE @1784DDPM',
              icon: Icons.sos,
              onCall: onCall,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyYalaCenter,
              display: AppConfig.emergencyYalaCenterDisplay,
              title: AppConfig.emergencyYalaCenterLabel,
              subtitle: '073-203559–64 / 073-203562',
              icon: Icons.account_balance,
              onCall: onCall,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyYalaMunicipality,
              display: AppConfig.emergencyYalaMunicipalityDisplay,
              title: 'ปภ. เทศบาลนครยะลา',
              subtitle: 'ช่วยเหลือน้ำท่วมเขตเมืองยะลา 24 ชม.',
              icon: Icons.fire_truck,
              onCall: onCall,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyMedical,
              display: '1669',
              title: 'สายด่วนการแพทย์ฉุกเฉิน (สพฉ.)',
              subtitle: 'เจ็บป่วยฉุกเฉิน / กู้ชีพ 24 ชม.',
              icon: Icons.local_hospital,
              onCall: onCall,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyDisaster,
              display: '199',
              title: 'แจ้งเหตุเพลิงไหม้ / สาธารณภัย',
              subtitle: 'สายด่วน 199 (24 ชม.)',
              icon: Icons.emergency,
              onCall: onCall,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyPolice,
              display: '191',
              title: 'เหตุด่วนเหตุร้าย (ตำรวจ)',
              subtitle: 'สายด่วนตำรวจ 191 (24 ชม.)',
              icon: Icons.local_police,
              onCall: onCall,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyVolunteer,
              display: '1677',
              title: 'ร่วมด้วยช่วยกัน (อาสาสมัคร)',
              subtitle: 'เครือข่ายอาสาสมัคร 24 ชม. (ไม่ใช่เบอร์ ปภ.)',
              icon: Icons.volunteer_activism,
              onCall: onCall,
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
    required String title,
    required String subtitle,
    required IconData icon,
    required ValueChanged<String> onCall,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0x14B71C1C),
        child: Icon(icon, color: const Color(AppConfig.colorDanger)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: FilledButton(
        onPressed: () => onCall(number),
        child: Text(display),
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  const _RequestList({required this.requests, required this.onAdvance});

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
            Text('บันทึกคำขอในเครื่อง (จำลอง)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (final request in requests)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(request.status.icon, size: 18, color: request.status.color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            request.typeTh,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          request.status.labelTh,
                          style: TextStyle(
                            color: request.status.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${request.lat.toStringAsFixed(5)}, ${request.lng.toStringAsFixed(5)}'
                      ' · ${thaiRelativeTime(request.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (request.status.next != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => onAdvance(request.id),
                          child: Text('จำลองอัปเดตเป็น "${request.status.next!.labelTh}"'),
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
