import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/sos_request.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/screens/station_detail_screen.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/risk_badge.dart';

/// แถบที่ 2 "ข้อมูล": รวมข้อมูลพยากรณ์ฝนรายชั่วโมง (เวลาไทย UTC+7),
/// สถานการณ์รายอำเภอทั้ง 8 อำเภอ, สถานีวัดระดับน้ำ 14 แห่ง และการแจ้งเตือนล่าสุด
/// โดยไม่แสดงสูตรคำนวณหรือคะแนนเทคนิคที่ไม่จำเป็นต่อประชาชน
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  bool _rainDrawerOpen = true;
  String? _selectedRainAmphoe;

  AmphoeForecastSummary? _focusAmphoeForecast(AlertProvider provider) {
    final snap = provider.snapshot;
    if (snap == null || snap.amphoes.isEmpty) return null;
    final target = _selectedRainAmphoe ?? provider.settings.selectedAmphoeTh;
    if (target != null) {
      final matched = snap.byAmphoe(target);
      if (matched != null) return matched;
    }
    return snap.amphoes.first;
  }

  List<Station> _sortedStations(AlertProvider provider) {
    final list = [...provider.stations];
    list.sort((a, b) {
      final byRisk = b.riskLevel.severity.compareTo(a.riskLevel.severity);
      if (byRisk != 0) return byRisk;
      final aTime = DateTime.tryParse(a.datetime ?? '');
      final bTime = DateTime.tryParse(b.datetime ?? '');
      if (aTime != null && bTime != null) return bTime.compareTo(aTime);
      return a.nameTh.compareTo(b.nameTh);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final strings = provider.strings;
    final focusAmphoe = _focusAmphoeForecast(provider);
    final amphoeList = provider.snapshot?.amphoes ?? const <AmphoeForecastSummary>[];
    final stations = _sortedStations(provider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.get('info_title')),
        actions: [
          if (provider.alerts.isNotEmpty)
            TextButton.icon(
              onPressed: provider.markAllAlertsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('อ่านทั้งหมด'),
            ),
          IconButton(
            tooltip: 'โหลดข้อมูลใหม่',
            onPressed: provider.loading
                ? null
                : () => provider.refresh(force: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
        children: [
          if (provider.activeAlerts.isEmpty && provider.alerts.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF2E7D32)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ขณะนี้ระดับน้ำทุกสถานีอยู่ในเกณฑ์ปกติ',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // 1. กราฟพยากรณ์ฝนรายชั่วโมง (เวลาไทย UTC+7) แบบแถบเลื่อน
          if (focusAmphoe != null && focusAmphoe.hourlyNext24h.isNotEmpty) ...[
            _RainForecastCard(
              amphoes: amphoeList,
              selected: focusAmphoe,
              expanded: _rainDrawerOpen,
              strings: strings,
              onSelectAmphoe: (amp) => setState(() => _selectedRainAmphoe = amp),
              onToggle: () => setState(() => _rainDrawerOpen = !_rainDrawerOpen),
            ),
            const SizedBox(height: 12),
          ],

          // 2. รายการแจ้งเตือนที่สำคัญ
          if (provider.alerts.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.campaign_outlined,
              title: 'ประกาศแจ้งเตือนล่าสุด (${provider.alerts.length})',
            ),
            const SizedBox(height: 6),
            for (final alert in provider.alerts.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AlertTile(alert: alert),
              ),
            const SizedBox(height: 8),
          ],

          // 3. สรุปสถานการณ์ทั้ง 8 อำเภอ (ไม่แสดงสูตร/คะแนนเทคนิค)
          if (amphoeList.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.location_city_outlined,
              title: 'สถานการณ์รายอำเภอ (${amphoeList.length} อำเภอ)',
            ),
            const SizedBox(height: 6),
            for (final amp in amphoeList)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AmphoeStatusCard(amphoe: amp, strings: strings),
              ),
            const SizedBox(height: 8),
          ],

          // 4. สถานีวัดระดับน้ำทั้งหมด
          _SectionHeader(
            icon: Icons.water_outlined,
            title: '${strings.get('latest_stations')} (${stations.length} แห่ง)',
          ),
          const SizedBox(height: 6),
          for (final station in stations)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StationRowCard(
                station: station,
                onTap: () {
                  provider.setSelectedStation(station.code);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => StationDetailScreen(stationCode: station.code),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0E5FA6)),
        const SizedBox(width: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B2545),
              ),
        ),
      ],
    );
  }
}

class _RainForecastCard extends StatelessWidget {
  const _RainForecastCard({
    required this.amphoes,
    required this.selected,
    required this.expanded,
    required this.strings,
    required this.onSelectAmphoe,
    required this.onToggle,
  });

  final List<AmphoeForecastSummary> amphoes;
  final AmphoeForecastSummary selected;
  final bool expanded;
  final AppStrings strings;
  final ValueChanged<String> onSelectAmphoe;
  final VoidCallback onToggle;

  Color _barColor(double mm) {
    if (mm >= 20) return const Color(0xFFB71C1C);
    if (mm >= 10) return const Color(0xFFEF6C00);
    if (mm >= 3) return const Color(0xFFF59E0B);
    if (mm > 0) return const Color(0xFF0284C7);
    return const Color(0xFF94A3B8);
  }

  @override
  Widget build(BuildContext context) {
    final maxMm = selected.hourlyNext24h.fold<double>(
      10.0,
      (prev, e) => e.mm > prev ? e.mm : prev,
    );

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  const Icon(Icons.water_drop_outlined, size: 18, color: Color(0xFF0E5FA6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expanded
                              ? strings.get('rain_drawer_open')
                              : strings.get('rain_drawer_closed'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0E5FA6),
                          ),
                        ),
                        Text(
                          '${strings.amphoe(selected.amphoeTh)} · พยากรณ์ฝน 24 ชม. ${selected.forecast24hMm.toStringAsFixed(1)} มม.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF0E5FA6),
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            if (amphoes.length > 1)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: amphoes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, idx) {
                    final a = amphoes[idx];
                    return ChoiceChip(
                      label: Text(
                        strings.amphoe(a.amphoeTh),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected: a.amphoeTh == selected.amphoeTh,
                      onSelected: (_) => onSelectAmphoe(a.amphoeTh),
                    );
                  },
                ),
              ),
            const SizedBox(height: 6),
            SizedBox(
              height: 190,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                itemCount: selected.hourlyNext24h.length,
                itemBuilder: (context, idx) {
                  final pt = selected.hourlyNext24h[idx];
                  final ratio = (pt.mm / maxMm).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 62,
                          child: Text(
                            '${pt.hourMinute} น.',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: pt.mm > 0 ? ratio.clamp(0.06, 1.0) : 0.02,
                              minHeight: 10,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(_barColor(pt.mm)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 82,
                          child: Text(
                            '${pt.mm.toStringAsFixed(1)} มม. · ${pt.probPct}%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmphoeStatusCard extends StatelessWidget {
  const _AmphoeStatusCard({required this.amphoe, required this.strings});

  final AmphoeForecastSummary amphoe;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final lv = AlertLevel.fromValue(amphoe.level);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.amphoe(amphoe.amphoeTh),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: lv.color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    amphoe.labelTh,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'ฝน 24 ชม. ${amphoe.rain24hMaxMm.toStringAsFixed(1)} มม. · '
              'พยากรณ์ฝน 24 ชม. ${amphoe.forecast24hMm.toStringAsFixed(1)} มม.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (amphoe.actionTh.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(amphoe.actionTh, style: const TextStyle(fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}

class _StationRowCard extends StatelessWidget {
  const _StationRowCard({required this.station, required this.onTap});

  final Station station;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final level = station.riskLevel;
    final remaining = station.remainingToBank;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: level.color.withValues(alpha: 0.14),
          child: Icon(station.trend.icon, color: level.color),
        ),
        title: Text(
          station.nameTh,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          '${station.locationLabel}'
          '${remaining != null ? (remaining >= 0 ? ' · เหลือ ${remaining.toStringAsFixed(2)} ม. ถึงตลิ่ง' : ' · ล้นตลิ่ง ${(-remaining).toStringAsFixed(2)} ม.') : ''}'
          '${station.datetime != null ? '\n${station.datetime} (เวลาไทย UTC+7)' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              station.displayLevel != null
                  ? '${station.displayLevel!.toStringAsFixed(2)} ม.'
                  : '—',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: level.color,
              ),
            ),
            RiskBadge(level: level, compact: true),
          ],
        ),
        isThreeLine: station.datetime != null,
      ),
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
                              fontSize: 14.5,
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
                    Text(alert.message, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
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
