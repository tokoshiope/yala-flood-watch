import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/sos_request.dart';
import 'package:yala_flood_app/screens/station_detail_screen.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/risk_badge.dart';

/// หน้ารายการแจ้งเตือนย้อนหลัง
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

enum _AlertFilter { all, danger, warning }

class _AlertsScreenState extends State<AlertsScreen> {
  _AlertFilter _filter = _AlertFilter.all;

  List<AlertItem> _applyFilter(List<AlertItem> alerts) {
    switch (_filter) {
      case _AlertFilter.all:
        return alerts;
      case _AlertFilter.danger:
        return alerts.where((a) => a.level == RiskLevel.danger).toList();
      case _AlertFilter.warning:
        return alerts
            .where((a) => a.level == RiskLevel.warning)
            .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final alerts = _applyFilter(provider.alerts);

    return Scaffold(
      appBar: AppBar(
        title: const Text('การแจ้งเตือน'),
        actions: [
          if (provider.alerts.isNotEmpty)
            TextButton.icon(
              onPressed: provider.markAllAlertsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('อ่านทั้งหมด'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (provider.activeAlerts.isEmpty && provider.alerts.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFE8F5E9),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF2E7D32)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ตอนนี้ไม่มีสถานีไหนอยู่ในเกณฑ์เตือนภัย สถานการณ์ดีขึ้นแล้ว',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip('ทั้งหมด', _AlertFilter.all, provider.alerts.length),
                  const SizedBox(width: 8),
                  _chip(
                    'อันตราย',
                    _AlertFilter.danger,
                    provider.alerts
                        .where((a) => a.level == RiskLevel.danger)
                        .length,
                  ),
                  const SizedBox(width: 8),
                  _chip(
                    'เตือนภัย',
                    _AlertFilter.warning,
                    provider.alerts
                        .where((a) => a.level == RiskLevel.warning)
                        .length,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: alerts.isEmpty
                ? _EmptyView(
                    hasHistory: provider.alerts.isNotEmpty,
                    onRefresh: () => provider.refresh(force: true),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: alerts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _AlertTile(alert: alerts[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, _AlertFilter value, int count) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final AlertItem alert;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AlertProvider>();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          provider.markAlertRead(alert.id);
          final station = provider.stationByCode(alert.stationCode);
          if (station != null) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    StationDetailScreen(stationCode: alert.stationCode),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 46,
                decoration: BoxDecoration(
                  color: alert.level.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (!alert.read)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Color(0xFFC62828),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      alert.message,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        RiskBadge(level: alert.level, compact: true),
                        const Spacer(),
                        Text(
                          thaiRelativeTime(alert.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.hasHistory, required this.onRefresh});

  final bool hasHistory;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              size: 52,
              color: Color(0xFF0E5FA6),
            ),
            const SizedBox(height: 14),
            Text(
              hasHistory ? 'ไม่มีแจ้งเตือนในหมวดนี้' : 'ยังไม่มีการแจ้งเตือน',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'เมื่อระดับน้ำถึงเกณฑ์เตือนภัย แอพจะแจ้งเตือนทันที\n'
              'และเก็บประวัติไว้ให้คุณย้อนดูได้',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('โหลดข้อมูลล่าสุด'),
            ),
          ],
        ),
      ),
    );
  }
}
