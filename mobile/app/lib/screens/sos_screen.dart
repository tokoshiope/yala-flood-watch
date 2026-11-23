import 'package:material_ui/material_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/sos_request.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// หน้า SOS ขอความช่วยเหลือ: ปุ่มใหญ่, พิกัด GPS, เบอร์ฉุกเฉิน และสถานะคำขอ
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
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
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
        setState(() {
          _locationStatus = LocationStatus.denied;
          _locationError =
              'ยังไม่ได้รับสิทธิ์ตำแหน่ง กดปุ่ม "เปิดการตั้งค่าตำแหน่ง" '
              'แล้วอนุญาตแอพนี้ เพื่อให้เราส่งพิกัดไปพร้อมคำขอ';
        });
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
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
          content: Text('ยังไม่มีพิกัด กรุณารอดึงตำแหน่ง หรือกด "ค้นหาตำแหน่งอีกครั้ง"'),
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
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'บันทึกคำขอแล้ว กรุณาโทร 1677 ด้วยตนเองด้วย เพื่อยืนยันและแจ้งพิกัด',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('ขอความช่วยเหลือ (SOS)')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
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
            onRetry: _locate,
            onOpenSettings: _openLocationSettings,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'เบอร์โทรที่ติดต่อได้ (ถ้ามี)',
              hintText: 'เช่น 0812345678',
              prefixIcon: Icon(Icons.phone),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _CallButtons(onCall: _call),
          const SizedBox(height: 12),
          const _SosNote(),
          if (provider.sosRequests.isNotEmpty) ...[
            const SizedBox(height: 8),
            _RequestList(requests: provider.sosRequests, onAdvance: provider.advanceSosStatus),
          ],
        ],
      ),
    );
  }
}

enum LocationStatus { idle, searching, ready, denied, error }

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(AppConfig.colorDanger),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: onPressed,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.sos, size: 54),
            const SizedBox(height: 6),
            Text(
              'กดขอความช่วยเหลือ',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'ระบบจะแนบพิกัด GPS ของคุณไปด้วย',
              style: TextStyle(color: Colors.white70, fontSize: 13),
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
                    'พิกัดของคุณ',
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
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('ค้นหา'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (status == LocationStatus.ready && position != null) ...[
              Text(
                'ละติจูด ${position!.latitude.toStringAsFixed(6)}  '
                'ลองจิจูด ${position!.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'ความแม่นยำประมาณ ${position!.accuracy.toStringAsFixed(0)} เมตร',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (status == LocationStatus.searching) ...[
              const Text('กำลังค้นหาสัญญาณ GPS…'),
            ] else ...[
              Text(
                errorTh ?? 'ยังไม่สามารถระบุตำแหน่งได้',
                style: const TextStyle(color: Color(0xFFC62828)),
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
            Text('โทรศัพท์ฉุกเฉิน', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            _callTile(
              context,
              number: AppConfig.emergencyDDPM,
              title: 'กรมป้องกันและบรรเทาสาธารณภัย',
              subtitle: 'ศูนย์เอราวัณ 1677 (24 ชม.)',
              icon: Icons.local_hospital,
              onCall: onCall,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyDisaster,
              title: 'หน่วยงานป้องกันภัยพิบัติ',
              subtitle: 'สายด่วน 199',
              icon: Icons.emergency,
              onCall: onCall,
            ),
            _callTile(
              context,
              number: AppConfig.emergencyYalaCenter,
              title: AppConfig.emergencyYalaCenterLabel,
              subtitle: 'เบอร์ติดต่อฉุกเฉินของจังหวัด',
              icon: Icons.account_balance,
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
    required String title,
    required String subtitle,
    required IconData icon,
    required ValueChanged<String> onCall,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0x14C62828),
        child: Icon(icon, color: const Color(AppConfig.colorDanger)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: FilledButton(
        onPressed: () => onCall(number),
        child: Text(number),
      ),
    );
  }
}

class _SosNote extends StatelessWidget {
  const _SosNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: Color(0xFF6D4C00)),
              SizedBox(width: 6),
              Text(
                'สำคัญ',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'การกดปุ่ม SOS บันทึกคำขอและพิกัดไว้ในเครื่องของคุณ แต่ยังไม่ได้ส่งไปยัง'
            'ศูนย์ปภ.ยะลาโดยตรง กรุณาโทร 1677 ด้วยตนเองเพื่อยืนยัน '
            'สถานะในแอพเป็นการจำลองไว้ก่อน เมื่อเชื่อมระบบจริงจะได้สถานะจากเครื่องศูนย์',
            style: TextStyle(fontSize: 13, color: Color(0xFF6D4C00)),
          ),
        ],
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
            Text('คำขอของคุณ', style: Theme.of(context).textTheme.titleSmall),
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
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final status in request.statusHistory)
                          Chip(
                            label: Text(
                              status.labelTh,
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    if (request.status.next != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => onAdvance(request.id),
                          child: Text(
                            'จำลองอัปเดตเป็น "${request.status.next!.labelTh}"',
                          ),
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
