import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/screens/station_detail_screen.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/risk_badge.dart';

/// แถบที่ 2 "ข้อมูล":
/// 1) กราฟแท่งพยากรณ์ฝนรายชั่วโมงแนว iOS Weather (เวลาไทย UTC+7)
/// 2) ประกาศแจ้งเตือนล่าสุดพร้อมระบุหมู่บ้าน/ตำบลที่ได้รับผลกระทบ
/// 3) สรุปสถานการณ์ทั้ง 8 อำเภอ เน้นระบุชื่อหมู่บ้านและตำบลที่ต้องเฝ้าระวังชัดเจน
/// 4) สถานีวัดระดับน้ำ 14 แห่ง เน้นแสดง "ระยะเหลือถึงตลิ่ง" เป็นหลัก + ป้ายความถี่อัปเดตจริง
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
      // เน้นเรียงสถานีที่เหลือระยะถึงตลิ่งน้อยที่สุด (ใกล้ล้นตลิ่ง) ขึ้นก่อน
      final aRem = a.remainingToBank;
      final bRem = b.remainingToBank;
      if (aRem != null && bRem != null) {
        final byRem = aRem.compareTo(bRem);
        if (byRem != 0) return byRem;
      } else if (aRem != null) {
        return -1;
      } else if (bRem != null) {
        return 1;
      }
      return a.nameTh.compareTo(b.nameTh);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final strings = provider.strings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final focusAmphoe = _focusAmphoeForecast(provider);
    final amphoeList =
        provider.snapshot?.amphoes ?? const <AmphoeForecastSummary>[];
    final stations = _sortedStations(provider);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.get('info_title')),
        actions: [
          if (provider.alerts.isNotEmpty)
            TextButton.icon(
              onPressed: provider.markAllAlertsRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: Text(strings.get('mark_all_read')),
            ),
          IconButton(
            tooltip: strings.get('refresh_tooltip'),
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
                color: isDark ? const Color(0xFF1B3A26) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? const Color(0xFF4CAF50) : const Color(0xFFA5D6A7),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: isDark
                        ? const Color(0xFF81C784)
                        : const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      strings.get('all_stations_normal'),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFF1B5E20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 1. กราฟแท่งพยากรณ์ฝนรายชั่วโมงแนว iOS Weather (เวลาไทย UTC+7)
          if (focusAmphoe != null && focusAmphoe.hourlyNext24h.isNotEmpty) ...[
            _RainForecastCard(
              amphoes: amphoeList,
              selected: focusAmphoe,
              expanded: _rainDrawerOpen,
              strings: strings,
              onSelectAmphoe: (amp) =>
                  setState(() => _selectedRainAmphoe = amp),
              onToggle: () =>
                  setState(() => _rainDrawerOpen = !_rainDrawerOpen),
            ),
            const SizedBox(height: 12),
          ],

          // 2. รายการแจ้งเตือนที่สำคัญ พร้อมระบุตำบล/หมู่บ้าน
          if (provider.alerts.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.campaign_outlined,
              title:
                  '${strings.get('latest_alerts_header')} (${provider.alerts.length})',
            ),
            const SizedBox(height: 6),
            for (final alert in provider.alerts.take(8))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AlertTile(alert: alert, strings: strings),
              ),
            const SizedBox(height: 8),
          ],

          // 3. สถานีวัดระดับน้ำทั้งหมด — เน้นแสดงระยะเหลือถึงตลิ่งเป็นหลัก
          _SectionHeader(
            icon: Icons.water_outlined,
            title:
                '${strings.get('latest_stations')} (${stations.length} ${strings.get('stations_unit')})',
          ),
          const SizedBox(height: 6),
          for (final station in stations)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _StationRowCard(
                station: station,
                strings: strings,
                onTap: () {
                  provider.setSelectedStation(station.code);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          StationDetailScreen(stationCode: station.code),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),

          // 4. สรุปสถานการณ์ทั้ง 8 อำเภอ — เน้นเตือนชัดเจนระดับหมู่บ้านและตำบล
          if (amphoeList.isNotEmpty) ...[
            _SectionHeader(
              icon: Icons.location_city_outlined,
              title:
                  '${strings.get('district_summary_header')} (${amphoeList.length} ${strings.get('districts_unit')})',
            ),
            const SizedBox(height: 6),
            for (final amp in amphoeList)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AmphoeStatusCard(
                  amphoe: amp,
                  provider: provider,
                  strings: strings,
                ),
              ),
          ],
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
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
          ),
        ),
      ],
    );
  }
}

/// กราฟแท่งพยากรณ์ฝนรายชั่วโมงสไตล์แอป Weather บน iOS (แท่งตั้ง มุมมน เลื่อนซ้าย-ขวา แตะดูค่าทีละชั่วโมง)
class _RainForecastCard extends StatefulWidget {
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

  @override
  State<_RainForecastCard> createState() => _RainForecastCardState();
}

class _RainForecastCardState extends State<_RainForecastCard> {
  int? _selectedBarIndex;

  @override
  void didUpdateWidget(covariant _RainForecastCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected.amphoeTh != widget.selected.amphoeTh) {
      _selectedBarIndex = null;
    }
  }

  int _defaultFocusIndex(List<HourlyRainPoint> points) {
    if (points.isEmpty) return 0;
    var bestIdx = 0;
    var bestMm = -1.0;
    for (var i = 0; i < points.length; i++) {
      if (points[i].mm > bestMm) {
        bestMm = points[i].mm;
        bestIdx = i;
      }
    }
    return bestMm > 0 ? bestIdx : 0;
  }

  Color _barColor(double mm, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    if (mm >= 20) return dark ? const Color(0xFFFF6B6B) : const Color(0xFFDC2626);
    if (mm >= 10) return dark ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
    if (mm >= 3) return dark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    if (mm > 0) return dark ? const Color(0xFF60A5FA) : const Color(0xFF38BDF8);
    return dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
  }

  /// สีข้อความ/ไอคอนบนพื้นกราฟฝน ผ่านเกณฑ์คอนทราสต์ WCAG AA >= 4.5:1 ทั้ง Light และ Dark Mode
  Color _rainTextColor(double mm, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    if (mm >= 20) return dark ? const Color(0xFFFF6B6B) : const Color(0xFFB91C1C);
    if (mm >= 10) return dark ? const Color(0xFFFB923C) : const Color(0xFFC2410C);
    return dark ? const Color(0xFF60A5FA) : const Color(0xFF0369A1);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final points = widget.selected.hourlyNext24h;
    final rawMax = points.fold<double>(0.0, (prev, e) => math.max(prev, e.mm));
    // สเกลแกนตั้งสะอาดแบบแอป Weather (ขั้นต่ำ 5 มม. เพื่อให้ฝนเบาไม่ดูล้นจอ)
    final double scaleMax = rawMax <= 5
        ? 5.0
        : rawMax <= 10
            ? 10.0
            : rawMax <= 20
                ? 20.0
                : (rawMax / 10).ceil() * 10.0;
    final focusIdx =
        (_selectedBarIndex != null && _selectedBarIndex! < points.length)
            ? _selectedBarIndex!
            : _defaultFocusIndex(points);
    final focusPt = points.isNotEmpty ? points[focusIdx] : null;

    final chartBg = isDark ? const Color(0xFF0F1E33) : const Color(0xFFF0F7FF);
    final chartBorder = isDark
        ? const Color(0xFF1E3A5F)
        : const Color(0xFFBFDBFE);
    final gridColor = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFF94A3B8).withValues(alpha: 0.35);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Icon(Icons.water_drop_rounded, size: 19, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.expanded
                              ? widget.strings.get('rain_drawer_open')
                              : widget.strings.get('rain_drawer_closed'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                        Text(
                          '${widget.strings.amphoe(widget.selected.amphoeTh)} · '
                          '${widget.strings.get('forecast_24h_label')} '
                          '${widget.selected.forecast24hMm.toStringAsFixed(1)} '
                          '${widget.strings.get('unit_mm')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    widget.expanded ? Icons.expand_less : Icons.expand_more,
                    color: cs.primary,
                  ),
                ],
              ),
            ),
          ),
          if (widget.expanded) ...[
            if (widget.amphoes.length > 1)
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: widget.amphoes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, idx) {
                    final a = widget.amphoes[idx];
                    return ChoiceChip(
                      label: Text(
                        widget.strings.amphoe(a.amphoeTh),
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected: a.amphoeTh == widget.selected.amphoeTh,
                      onSelected: (_) => widget.onSelectAmphoe(a.amphoeTh),
                    );
                  },
                ),
              ),
            const SizedBox(height: 6),
            // แถบแสดงค่าของชั่วโมงที่แตะเลือก (ใช้ Wrap รองรับโหมดตัวอักษรใหญ่และจอแคบ 375pt โดยไม่ล้น)
            if (focusPt != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: chartBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: chartBorder),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        Icons.umbrella_outlined,
                        size: 16,
                        color: _rainTextColor(focusPt.mm, brightness),
                      ),
                      Text(
                        widget.strings.formatHourLabel(focusPt.hourMinute),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        '${focusPt.mm.toStringAsFixed(1)} ${widget.strings.get('unit_mm')}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: _rainTextColor(focusPt.mm, brightness),
                        ),
                      ),
                      Text(
                        '${widget.strings.get('rain_prob_label')} ${focusPt.probPct}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // กราฟแท่งแนวตั้งแบบแอป Weather ของ iOS — แสดงครบทั้งปริมาณฝน (มม.) และโอกาสฝนตก (%) ทุกชั่วโมง
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: MediaQuery.textScalerOf(context).clamp(
                        minScaleFactor: 0.9,
                        maxScaleFactor: 1.15,
                      ),
                    ),
                    child: Container(
                      height: 214,
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                      decoration: BoxDecoration(
                        color: chartBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: chartBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // แกน Y (มม.) + ป้ายแถวเวลาและโอกาสฝนตก (%)
                          SizedBox(
                            width: 44,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 18, bottom: 4),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            scaleMax.toStringAsFixed(0),
                                            maxLines: 1,
                                            softWrap: false,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            (scaleMax / 2)
                                                .toStringAsFixed(scaleMax >= 10 ? 0 : 1),
                                            maxLines: 1,
                                            softWrap: false,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '0 ${widget.strings.get('unit_mm')}',
                                            maxLines: 1,
                                            softWrap: false,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w600,
                                              color: cs.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 18,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '%',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? const Color(0xFF7DD3FC)
                                              : const Color(0xFF0369A1),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 18,
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        widget.strings.lang == 'th' ? 'น.' : 'hr',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // พื้นที่แท่งกราฟเลื่อนซ้าย-ขวาได้ 24 ชั่วโมง
                          Expanded(
                            child: Stack(
                              children: [
                                // เส้นกริดแนวนอน 3 ระดับ
                                Positioned.fill(
                                  top: 20,
                                  bottom: 40,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      for (var i = 0; i < 3; i++)
                                        Container(height: 1, color: gridColor),
                                    ],
                                  ),
                                ),
                                ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: points.length,
                                  itemBuilder: (context, idx) {
                                    final pt = points[idx];
                                    final ratio = (pt.mm / scaleMax).clamp(0.0, 1.0);
                                    final isSelected = idx == focusIdx;
                                    final barColor = _barColor(pt.mm, brightness);
                                    final valTextColor =
                                        _rainTextColor(pt.mm, brightness);
                                    final probTextColor = pt.probPct >= 50
                                        ? (isDark
                                            ? const Color(0xFF7DD3FC)
                                            : const Color(0xFF0369A1))
                                        : cs.onSurfaceVariant;
                                    const maxBarHeight = 104.0;
                                    final barHeight = pt.mm > 0
                                        ? math.max(8.0, maxBarHeight * ratio)
                                        : 3.0;

                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () =>
                                          setState(() => _selectedBarIndex = idx),
                                      child: Container(
                                        width: 42,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        decoration: isSelected
                                            ? BoxDecoration(
                                                color: cs.primary.withValues(
                                                  alpha: isDark ? 0.16 : 0.09,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              )
                                            : null,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            // แถวที่ 1: ปริมาณฝน (มม.) บนยอดแท่ง
                                            SizedBox(
                                              height: 18,
                                              child: Center(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    pt.mm >= 0.1
                                                        ? pt.mm.toStringAsFixed(
                                                            pt.mm >= 10 ? 0 : 1,
                                                          )
                                                        : '0',
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: isSelected
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                      color: pt.mm >= 0.1
                                                          ? valTextColor
                                                          : cs.onSurfaceVariant
                                                              .withValues(alpha: 0.65),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // แถวที่ 2: แท่งกราฟแนวตั้ง
                                            Expanded(
                                              child: Align(
                                                alignment: Alignment.bottomCenter,
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 220,
                                                  ),
                                                  width: isSelected ? 18 : 14,
                                                  height: barHeight,
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        const BorderRadius.vertical(
                                                      top: Radius.circular(6),
                                                      bottom: Radius.circular(2),
                                                    ),
                                                    gradient: pt.mm > 0
                                                        ? LinearGradient(
                                                            begin:
                                                                Alignment.topCenter,
                                                            end: Alignment
                                                                .bottomCenter,
                                                            colors: [
                                                              barColor,
                                                              barColor.withValues(
                                                                alpha: 0.72,
                                                              ),
                                                            ],
                                                          )
                                                        : null,
                                                    color:
                                                        pt.mm > 0 ? null : barColor,
                                                    border: isSelected
                                                        ? Border.all(
                                                            color: cs.onSurface
                                                                .withValues(
                                                                  alpha: 0.55,
                                                                ),
                                                            width: 1.2,
                                                          )
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // แถวที่ 3: โอกาสฝนตก (%) แสดงครบทุกชั่วโมง (0%–100%)
                                            SizedBox(
                                              height: 18,
                                              child: Center(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    '${pt.probPct}%',
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: 9.5,
                                                      fontWeight: pt.probPct >= 50 ||
                                                              isSelected
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                      color: probTextColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // แถวที่ 4: ชั่วโมง (เวลาไทย UTC+7)
                                            SizedBox(
                                              height: 18,
                                              child: Center(
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    pt.hourMinute.length >= 2
                                                        ? pt.hourMinute
                                                            .substring(0, 2)
                                                        : pt.hourMinute,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: isSelected
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                      color: isSelected
                                                          ? cs.primary
                                                          : cs.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.strings.get('rain_chart_axis_legend'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// การ์ดสถานการณ์รายอำเภอ — เน้นเตือนชัดเจนว่าพื้นที่หมู่บ้านไหน ตำบลไหนเสี่ยง/ต้องเฝ้าระวัง
class _AmphoeStatusCard extends StatefulWidget {
  const _AmphoeStatusCard({
    required this.amphoe,
    required this.provider,
    required this.strings,
  });

  final AmphoeForecastSummary amphoe;
  final AlertProvider provider;
  final AppStrings strings;

  @override
  State<_AmphoeStatusCard> createState() => _AmphoeStatusCardState();
}

class _AmphoeStatusCardState extends State<_AmphoeStatusCard> {
  bool _showAllVillages = false;

  @override
  Widget build(BuildContext context) {
    final lv = AlertLevel.fromValue(widget.amphoe.level);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final villages = widget.provider.watchVillagesForAmphoe(
      widget.amphoe.amphoeTh,
      limit: 10,
    );
    final shownVillages = _showAllVillages ? villages : villages.take(4).toList();

    final areaBoxBg = lv.value >= 3
        ? lv.colorFor(Theme.of(context).brightness).withValues(alpha: isDark ? 0.16 : 0.08)
        : (isDark ? const Color(0xFF172536) : const Color(0xFFF8FAFC));
    final areaBoxBorder = lv.value >= 3
        ? lv.colorFor(Theme.of(context).brightness).withValues(alpha: 0.45)
        : cs.outlineVariant;

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
                    widget.strings.amphoePrefixed(widget.amphoe.amphoeTh),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: lv.color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    widget.strings.alertLevelLabel(lv.value),
                    style: TextStyle(
                      color: lv.onSolidColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${widget.strings.get('rain_24h_label')} ${widget.amphoe.rain24hMaxMm.toStringAsFixed(1)} ${widget.strings.get('unit_mm')} · '
              '${widget.strings.get('forecast_24h_label')} ${widget.amphoe.forecast24hMm.toStringAsFixed(1)} ${widget.strings.get('unit_mm')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.amphoe.alertBasis == 'rain_dam_early_warning' ||
                widget.amphoe.floodMechanism != 'monitoring') ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (widget.amphoe.alertBasis == 'rain_dam_early_warning')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: lv.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: lv.color.withValues(alpha: 0.45)),
                      ),
                      child: Text(
                        widget.strings.get('early_warning_rain_dam_badge'),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: lv.colorFor(Theme.of(context).brightness),
                        ),
                      ),
                    ),
                  if (widget.amphoe.floodMechanism != 'monitoring')
                    Text(
                      widget.strings.mechanismLabel(widget.amphoe.floodMechanism),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: lv.colorFor(Theme.of(context).brightness),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 4),
            Text(
              widget.strings.alertLevelAction(lv.value),
              style: const TextStyle(fontSize: 12.5),
            ),
            if (shownVillages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: areaBoxBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: areaBoxBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 15,
                          color: lv.value >= 3
                              ? lv.colorFor(Theme.of(context).brightness)
                              : cs.primary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            widget.strings.get('watch_areas_header'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    for (final entry in shownVillages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(top: 5, right: 6),
                              decoration: BoxDecoration(
                                color: AlertLevel.fromValue(entry.eval.level)
                                    .colorFor(Theme.of(context).brightness),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '${widget.strings.villageName(entry.village.moo, entry.village.nameTh, entry.village.nameEn)} '
                                '(${widget.strings.tumbonName(entry.village.tumbonTh, widget.provider.tumbonEnOf(entry.village.amphoeTh, entry.village.tumbonTh))})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                              ),
                            ),
                            if (entry.eval.marginMeters != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                widget.strings.elevationMarginText(
                                  entry.eval.marginMeters!,
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AlertLevel.fromValue(entry.eval.level)
                                      .colorFor(Theme.of(context).brightness),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (villages.length > 4)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 0,
                            ),
                          ),
                          onPressed: () => setState(
                            () => _showAllVillages = !_showAllVillages,
                          ),
                          child: Text(
                            _showAllVillages
                                ? widget.strings.get('watch_areas_show_less')
                                : '${widget.strings.get('watch_areas_show_more')} (${villages.length})',
                            style: const TextStyle(fontSize: 11.5),
                          ),
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

/// แถวสถานีวัดระดับน้ำ — เน้นแสดง "ระยะเหลือถึงตลิ่ง" เป็นตัวเลขหลัก + ป้ายความถี่อัปเดตจริง
class _StationRowCard extends StatelessWidget {
  const _StationRowCard({
    required this.station,
    required this.strings,
    required this.onTap,
  });

  final Station station;
  final AppStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final level = station.riskLevel;
    final displayColor = level.colorFor(brightness);
    final remaining = station.remainingToBank;
    final cadenceMin = station.effectiveUpdateIntervalMinutes;
    final cadenceColor = cadenceMin <= 10
        ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0369A1))
        : cs.onSurfaceVariant;

    final Color marginColor;
    if (remaining != null) {
      if (remaining <= 0) {
        marginColor = isDark ? const Color(0xFFFF6B6B) : const Color(0xFFB71C1C);
      } else if (remaining <= 1.0) {
        marginColor = isDark ? const Color(0xFFFFB74D) : const Color(0xFFEF6C00);
      } else if (remaining <= 2.5) {
        marginColor = isDark ? const Color(0xFFFDE047) : const Color(0xFFB45309);
      } else {
        marginColor = isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
      }
    } else {
      marginColor = displayColor;
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: displayColor.withValues(alpha: 0.16),
                child: Icon(station.trend.icon, color: displayColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.stationFullName(station),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      strings.stationLocation(station),
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (station.displayLevel != null)
                          Text(
                            '${strings.get('latest_water_level')} ${station.displayLevel!.toStringAsFixed(2)} ${strings.get('unit_m')}'
                            '${station.hasBank && station.bankLevel != null ? ' / ${strings.get('bank_label')} ${station.bankLevel!.toStringAsFixed(2)}' : ''}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: cadenceColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            strings.updateCadenceLabel(cadenceMin),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: cadenceColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (station.datetime != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${station.datetime} (${strings.get('updated_tz')})',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // ด้านขวา: เน้นแสดง "ระยะเหลือถึงตลิ่ง" เป็นตัวเลขหลักชัดเจน
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (remaining != null) ...[
                    Text(
                      remaining >= 0
                          ? strings.get('below_bank_short')
                          : strings.get('over_bank_short'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: marginColor,
                      ),
                    ),
                    Text(
                      remaining >= 0
                          ? '${remaining.toStringAsFixed(2)} ${strings.get('unit_m')}'
                          : '+${remaining.abs().toStringAsFixed(2)} ${strings.get('unit_m')}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: marginColor,
                      ),
                    ),
                  ] else ...[
                    Text(
                      station.displayLevel != null
                          ? '${station.displayLevel!.toStringAsFixed(2)} ${strings.get('unit_m')}'
                          : '—',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: displayColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  RiskBadge(level: level, compact: true, strings: strings),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert, required this.strings});

  final AlertItem alert;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AlertProvider>();
    final station = provider.stationByCode(alert.stationCode);
    final displayTitle = station != null
        ? '${strings.riskLevelLabel(alert.level)}: ${strings.stationFullName(station)}'
        : alert.title;
    final alertLvVal =
        alert.alertLevel?.value ?? alert.level.severity.clamp(1, 5);
    final displayMsg = strings.lang == 'th'
        ? alert.message
        : (alert.waterLevelMsl != null
            ? '${strings.get('latest_water_level')} ${alert.waterLevelMsl!.toStringAsFixed(2)} ${strings.get('unit_msl')} · ${strings.alertLevelAction(alertLvVal)}'
            : strings.alertLevelAction(alertLvVal));

    final nearVillages = station != null
        ? provider.watchVillagesNearStation(station, limit: 3)
        : const <({VillagePoint village, ElevationFloodResult eval, double distKm})>[];

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          provider.markAlertRead(alert.id);
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
                height: 54,
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
                            displayTitle,
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
                    if (station != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        strings.stationLocation(station),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(displayMsg, style: const TextStyle(fontSize: 13)),
                    if (nearVillages.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        '${strings.get('watch_areas_header')}: '
                        '${nearVillages.map((e) => '${strings.villageName(e.village.moo, e.village.nameTh, e.village.nameEn)} (${strings.tumbonName(e.village.tumbonTh, provider.tumbonEnOf(e.village.amphoeTh, e.village.tumbonTh))})').join(', ')}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RiskBadge(
                          level: alert.level,
                          compact: true,
                          strings: strings,
                        ),
                        Text(
                          strings.relativeTime(alert.createdAt),
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
