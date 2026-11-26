import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/screens/sos_screen.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/risk_badge.dart';

/// หน้ารายละเอียดสถานี:
/// - เน้นแสดง "ระยะเหลือถึงตลิ่ง" เป็นหลักพร้อมความถี่อัปเดตจริงของเซ็นเซอร์
/// - กราฟแนวโน้มระดับน้ำย้อนหลัง 7 วัน (สลับดู 24 ชม. / 3 วัน / 7 วัน + แตะดูค่าทีละจุด)
/// - ระบุรายชื่อหมู่บ้านและตำบลในพื้นที่รอบสถานีอย่างชัดเจน
class StationDetailScreen extends StatefulWidget {
  const StationDetailScreen({super.key, required this.stationCode});

  final String stationCode;

  @override
  State<StationDetailScreen> createState() => _StationDetailScreenState();
}

class _StationDetailScreenState extends State<StationDetailScreen> {
  int _selectedDays = 7;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AlertProvider>();
      final station = provider.stationByCode(widget.stationCode);
      if (station != null) {
        provider.loadStationHistory7d(station);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final strings = provider.strings;
    final station = provider.stationByCode(widget.stationCode);

    if (station == null) {
      return Scaffold(
        appBar: AppBar(title: Text(strings.get('station_detail_title'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(strings.get('station_not_found')),
          ),
        ),
      );
    }

    final alerts = provider.alerts
        .where((a) => a.stationCode == station.code)
        .toList();
    final history7d = provider.stationHistory7d(station.code);
    final historyLoading = provider.isStationHistoryLoading(station.code);
    final nearVillages = provider.watchVillagesNearStation(station, limit: 6);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.stationFullName(station)),
        actions: [
          IconButton(
            tooltip: strings.get('refresh_tooltip'),
            onPressed: historyLoading
                ? null
                : () => provider.loadStationHistory7d(
                      station,
                      forceRefresh: true,
                    ),
            icon: historyLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _HeaderCard(station: station, strings: strings),
          const SizedBox(height: 12),
          _LevelCard(station: station, strings: strings),
          const SizedBox(height: 12),
          _BankCard(station: station, strings: strings),
          const SizedBox(height: 12),
          _ChartCard(
            station: station,
            strings: strings,
            history: history7d,
            loading: historyLoading,
            selectedDays: _selectedDays,
            onRangeChanged: (days) => setState(() => _selectedDays = days),
          ),
          if (nearVillages.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AffectedVillagesCard(
              villages: nearVillages,
              provider: provider,
              strings: strings,
            ),
          ],
          const SizedBox(height: 12),
          _GuidanceCard(station: station, strings: strings),
          const SizedBox(height: 12),
          _InfoCard(station: station, strings: strings),
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _StationAlertsCard(
              station: station,
              alerts: alerts,
              strings: strings,
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _goToEmergency(context),
                  icon: const Icon(Icons.phone_in_talk),
                  label: Text(strings.get('request_help_btn')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _goToEmergency(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SosScreen()),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.station, required this.strings});

  final Station station;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final level = station.riskLevel;
    final brightness = Theme.of(context).brightness;
    return Card(
      color: level.colorFor(brightness).withValues(
            alpha: brightness == Brightness.dark ? 0.16 : 0.08,
          ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.stationFullName(station),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${strings.stationLocation(station)} · ${station.code}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            RiskBadge(level: level, strings: strings),
          ],
        ),
      ),
    );
  }
}

/// การ์ดหลัก: เน้นแสดง "ระยะเหลือถึงตลิ่ง" เป็นตัวเลขเด่น พร้อมระดับน้ำจริงและรอบอัปเดตเซ็นเซอร์
class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.station, required this.strings});

  final Station station;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final level = station.riskLevel;
    final displayColor = level.colorFor(brightness);
    final wl = station.displayLevel;
    final remaining = station.remainingToBank;
    final cadenceMin = station.effectiveUpdateIntervalMinutes;

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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (remaining != null) ...[
                    Text(
                      remaining >= 0
                          ? strings.get('remaining_to_bank_hero')
                          : strings.get('over_bank_short'),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        remaining >= 0
                            ? '${remaining.toStringAsFixed(2)} ${strings.get('unit_m')}'
                            : '+${remaining.abs().toStringAsFixed(2)} ${strings.get('unit_m')}',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: marginColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${strings.get('latest_water_level')}: '
                      '${wl != null ? '${wl.toStringAsFixed(2)} ${strings.get('unit_msl')}' : '—'}'
                      '${station.bankLevel != null ? ' · ${strings.get('bank_label')} ${station.bankLevel!.toStringAsFixed(2)} ${strings.get('unit_m')}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ] else ...[
                    Text(
                      strings.get('latest_water_level'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      wl == null
                          ? '—'
                          : '${wl.toStringAsFixed(2)} ${strings.get('unit_m')}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: displayColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(strings.get('msl_full_label')),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: (cadenceMin <= 10
                              ? const Color(0xFF0284C7)
                              : const Color(0xFF64748B))
                          .withValues(alpha: isDark ? 0.24 : 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${strings.updateCadenceLabel(cadenceMin)}'
                      '${(station.agencyShortTh ?? '').isNotEmpty ? ' · ${strings.agencyName(station.agencyShortTh)}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cadenceMin <= 10
                            ? (isDark
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF0369A1))
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Icon(
                  station.trend.icon,
                  size: 30,
                  color: station.trend.colorFor(brightness),
                ),
                const SizedBox(height: 4),
                Text(
                  strings.waterTrendLabel(station.trend),
                  style: TextStyle(
                    color: station.trend.colorFor(brightness),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  station.datetime ?? strings.get('unknown'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BankCard extends StatelessWidget {
  const _BankCard({required this.station, required this.strings});

  final Station station;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bank = station.bankLevel;
    final wl = station.displayLevel;
    final remaining = station.remainingToBank;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.straighten, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.get('compare_bank_title'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  bank == null || bank <= 0
                      ? strings.get('no_bank_data')
                      : '${strings.get('bank_label')} ${bank.toStringAsFixed(2)} ${strings.get('unit_m')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (bank != null && bank > 0 && wl != null)
              _BankBar(station: station, strings: strings)
            else
              Text(strings.get('no_bank_explain')),
            if (remaining != null) ...[
              const SizedBox(height: 10),
              Text(
                strings.remainingToBankText(remaining),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: remaining >= 0
                      ? (isDark
                          ? const Color(0xFF66BB6A)
                          : const Color(0xFF2E7D32))
                      : (isDark
                          ? const Color(0xFFFF6B6B)
                          : const Color(0xFFC62828)),
                ),
              ),
            ],
            if (station.storagePercent != null) ...[
              const SizedBox(height: 8),
              Text(
                '${strings.get('reservoir_capacity')} ${station.storagePercent!.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BankBar extends StatelessWidget {
  const _BankBar({required this.station, required this.strings});

  final Station station;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bank = station.bankLevel!;
    final ground = station.groundLevel ?? 0;
    final wl = station.displayLevel ?? ground;
    final span = (bank - ground) <= 0 ? 1.0 : bank - ground;
    final ratio = ((wl - ground) / span).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Stack(
              children: [
                Container(color: cs.surfaceContainerHighest),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    color: station.riskLevel
                        .colorFor(Theme.of(context).brightness),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              ground > 0
                  ? '${strings.get('ground_level_label')} ${ground.toStringAsFixed(1)}'
                  : '${strings.get('ground_level_label')} —',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              '${strings.get('bank_label')} ${bank.toStringAsFixed(1)} ${strings.get('unit_m')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

/// กราฟแนวโน้มระดับน้ำย้อนหลัง 7 วัน (เลือก 24 ชม. / 3 วัน / 7 วัน + แตะลากดูค่ารายจุดได้)
class _ChartCard extends StatefulWidget {
  const _ChartCard({
    required this.station,
    required this.strings,
    required this.history,
    required this.loading,
    required this.selectedDays,
    required this.onRangeChanged,
  });

  final Station station;
  final AppStrings strings;
  final List<WaterLevelPoint> history;
  final bool loading;
  final int selectedDays;
  final ValueChanged<int> onRangeChanged;

  @override
  State<_ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<_ChartCard> {
  int? _inspectedIndex;

  List<WaterLevelPoint> _filteredSeries() {
    if (widget.history.isEmpty) return const <WaterLevelPoint>[];
    final latestDt = widget.history.last.dateTime;
    if (latestDt == null) return widget.history;
    final cutoff = latestDt.subtract(Duration(days: widget.selectedDays));
    final filtered = widget.history.where((pt) {
      final dt = pt.dateTime;
      return dt == null || !dt.isBefore(cutoff);
    }).toList();
    return filtered.length >= 2 ? filtered : widget.history;
  }

  void _updateInspect(Offset localPos, double width, int count) {
    if (count < 2) return;
    const leftPad = 52.0;
    const rightPad = 14.0;
    final chartW = width - leftPad - rightPad;
    if (chartW <= 0) return;
    final t = ((localPos.dx - leftPad) / chartW).clamp(0.0, 1.0);
    final idx = (t * (count - 1)).round().clamp(0, count - 1);
    if (_inspectedIndex != idx) {
      setState(() => _inspectedIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final series = _filteredSeries();
    final safeInspect = (_inspectedIndex != null && _inspectedIndex! < series.length)
        ? _inspectedIndex
        : null;
    final inspectedPt = safeInspect != null ? series[safeInspect] : null;
    final bank = widget.station.bankLevel;
    final watch = AppConfig.stationWatchMsl[widget.station.code];

    double? minV;
    double? maxV;
    for (final pt in series) {
      minV = minV == null ? pt.valueMsl : math.min(minV, pt.valueMsl);
      maxV = maxV == null ? pt.valueMsl : math.max(maxV, pt.valueMsl);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.strings.get('trend_chart_title'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (widget.loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // ปุ่มเลือกช่วงเวลาย้อนหลัง: 24 ชม. / 3 วัน / 7 วัน (ใช้ Wrap รองรับจอแคบ + โหมดตัวอักษรใหญ่)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final item in [
                  (1, widget.strings.get('range_24h')),
                  (3, widget.strings.get('range_3d')),
                  (7, widget.strings.get('range_7d')),
                ])
                  ChoiceChip(
                    label: Text(
                      item.$2,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    selected: widget.selectedDays == item.$1,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      setState(() => _inspectedIndex = null);
                      widget.onRangeChanged(item.$1);
                    },
                  ),
                if (series.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '${series.length} pts',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // แถบแสดงค่าที่กำลังแตะเลือก หรือค่าต่ำสุด-สูงสุดในช่วงเวลา (ใช้ Column/Wrap ไม่ล้นในโหมดตัวอักษรใหญ่)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F1E33)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: inspectedPt != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${inspectedPt.timestamp} (${widget.strings.get('updated_tz')})',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${inspectedPt.valueMsl.toStringAsFixed(2)} ${widget.strings.get('unit_m')}'
                          '${bank != null && bank > 0 ? ' · ${widget.strings.remainingToBankText(bank - inspectedPt.valueMsl)}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 2,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          minV != null && maxV != null
                              ? '${widget.strings.get('min_label')} ${minV.toStringAsFixed(2)} · '
                                  '${widget.strings.get('max_label')} ${maxV.toStringAsFixed(2)} ${widget.strings.get('unit_msl')}'
                              : (widget.loading
                                  ? widget.strings.get('chart_loading')
                                  : widget.strings.get('trend_chart_sub')),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        if (series.length >= 2)
                          Text(
                            widget.strings.get('trend_chart_sub'),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onTapDown: (d) => _updateInspect(
                  d.localPosition,
                  constraints.maxWidth,
                  series.length,
                ),
                onHorizontalDragUpdate: (d) => _updateInspect(
                  d.localPosition,
                  constraints.maxWidth,
                  series.length,
                ),
                child: SizedBox(
                  height: 205,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _LevelTrendPainter(
                      station: widget.station,
                      series: series,
                      watchLevel: watch,
                      inspectedIndex: safeInspect,
                      selectedDays: widget.selectedDays,
                      strings: widget.strings,
                      isDark: isDark,
                      labelColor: cs.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelTrendPainter extends CustomPainter {
  _LevelTrendPainter({
    required this.station,
    required this.series,
    required this.watchLevel,
    required this.inspectedIndex,
    required this.selectedDays,
    required this.strings,
    required this.isDark,
    required this.labelColor,
  });

  final Station station;
  final List<WaterLevelPoint> series;
  final double? watchLevel;
  final int? inspectedIndex;
  final int selectedDays;
  final AppStrings strings;
  final bool isDark;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final wl = station.displayLevel;
    final prev = station.waterLevelMslPrev;
    final hasHistory = series.length >= 2;
    if (!hasHistory && wl == null) {
      _text(
        canvas,
        size.center(Offset.zero),
        strings.get('no_water_reading'),
        color: labelColor,
      );
      return;
    }

    final bank = station.bankLevel;
    final values = hasHistory
        ? series.map((p) => p.valueMsl).toList()
        : <double>[prev ?? wl!, wl!];
    var minV = values.reduce(math.min);
    var maxV = values.reduce(math.max);

    // ใส่ระดับตลิ่ง/เฝ้าระวังเข้าสเกลเมื่อจุดต่ำสุดหรือจุดสูงสุดอยู่ในระยะ <= 10 ม. (รองรับน้ำหลากฉับพลัน)
    final showBankOnScale = bank != null &&
        bank > 0 &&
        math.min((bank - minV).abs(), (bank - maxV).abs()) <= 10.0;
    final showWatchOnScale = watchLevel != null &&
        watchLevel! > 0 &&
        math.min((watchLevel! - minV).abs(), (watchLevel! - maxV).abs()) <= 10.0;
    if (showBankOnScale) {
      minV = math.min(minV, bank);
      maxV = math.max(maxV, bank);
    }
    if (showWatchOnScale) {
      minV = math.min(minV, watchLevel!);
      maxV = math.max(maxV, watchLevel!);
    }

    final span = maxV - minV;
    if (span < 0.2) {
      final mid = (maxV + minV) / 2;
      minV = mid - 0.4;
      maxV = mid + 0.4;
    } else {
      minV -= span * 0.12;
      maxV += span * 0.12;
    }

    const leftPad = 52.0;
    const rightPad = 14.0;
    const topPad = 16.0;
    const bottomPad = 24.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    if (chartW <= 0 || chartH <= 0) return;

    double yOf(double v) =>
        topPad + chartH * (1 - (v - minV) / (maxV - minV));

    // เส้นกริดแนวนอนและตัวเลขแกน Y (4 ระดับ)
    final grid = Paint()
      ..color = isDark ? const Color(0x28FFFFFF) : const Color(0x18000000)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final frac = i / 4;
      final y = topPad + chartH * frac;
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        grid,
      );
      final vLabel = maxV - (maxV - minV) * frac;
      _text(
        canvas,
        Offset(leftPad - 6, y - 6),
        vLabel.toStringAsFixed(1),
        color: labelColor.withValues(alpha: 0.72),
        alignRight: true,
        fontSize: 9.5,
      );
    }

    // เส้นประระดับเฝ้าระวัง (Watch)
    if (showWatchOnScale) {
      final watchColor =
          isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      final y = yOf(watchLevel!);
      _dashedLine(
        canvas,
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        Paint()
          ..color = watchColor
          ..strokeWidth = 1.2,
      );
      _text(
        canvas,
        Offset(size.width - rightPad, y - 13),
        '${strings.get('watch_level_label')} ${watchLevel!.toStringAsFixed(1)}',
        color: watchColor,
        alignRight: true,
        fontSize: 9.5,
      );
    }

    // เส้นประระดับตลิ่ง (Bank)
    if (showBankOnScale) {
      final bankColor =
          isDark ? const Color(0xFFFF6B6B) : const Color(0xFFC62828);
      final y = yOf(bank);
      _dashedLine(
        canvas,
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        Paint()
          ..color = bankColor
          ..strokeWidth = 1.6,
      );
      _text(
        canvas,
        Offset(size.width - rightPad, y - 13),
        '${strings.get('bank_label')} ${bank.toStringAsFixed(2)}',
        color: bankColor,
        alignRight: true,
        fontSize: 9.5,
      );
    }

    // เส้นกราฟระดับน้ำ + แรเงาใต้กราฟ
    final lineColor = station.riskLevel.colorFor(
      isDark ? Brightness.dark : Brightness.light,
    );
    final offsets = <Offset>[];
    final n = values.length;
    for (var i = 0; i < n; i++) {
      final x = n == 1
          ? leftPad + chartW * 0.5
          : leftPad + chartW * (i / (n - 1));
      offsets.add(Offset(x, yOf(values[i])));
    }

    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (var i = 1; i < offsets.length; i++) {
      linePath.lineTo(offsets[i].dx, offsets[i].dy);
    }

    final areaPath = Path.from(linePath)
      ..lineTo(offsets.last.dx, topPad + chartH)
      ..lineTo(offsets.first.dx, topPad + chartH)
      ..close();

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: isDark ? 0.34 : 0.24),
            lineColor.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(leftPad, topPad, chartW, chartH)),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // จุดปลายล่าสุด
    final lastPt = offsets.last;
    canvas.drawCircle(lastPt, 4.5, Paint()..color = lineColor);
    canvas.drawCircle(
      lastPt,
      4.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // เส้นเล็งจุดที่ผู้ใช้แตะตรวจสอบ
    if (inspectedIndex != null && inspectedIndex! < offsets.length) {
      final pt = offsets[inspectedIndex!];
      canvas.drawLine(
        Offset(pt.dx, topPad),
        Offset(pt.dx, topPad + chartH),
        Paint()
          ..color = labelColor.withValues(alpha: 0.45)
          ..strokeWidth = 1.2,
      );
      canvas.drawCircle(pt, 6, Paint()..color = lineColor);
      canvas.drawCircle(
        pt,
        6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // ป้ายแกน X (วันที่ / เวลา)
    if (hasHistory) {
      final tickIndices = <int>{
        0,
        (n * 0.33).round().clamp(0, n - 1),
        (n * 0.66).round().clamp(0, n - 1),
        n - 1,
      }.toList()
        ..sort();
      for (final idx in tickIndices) {
        final ts = series[idx].timestamp;
        final label = _formatTick(ts, selectedDays);
        final x = offsets[idx].dx;
        final alignRight = idx == n - 1;
        final alignCenter = idx != 0 && idx != n - 1;
        _text(
          canvas,
          Offset(x, size.height - 14),
          label,
          color: labelColor.withValues(alpha: 0.78),
          alignRight: alignRight,
          alignCenter: alignCenter,
          fontSize: 9.5,
        );
      }
    } else {
      _text(
        canvas,
        Offset(leftPad, size.height - 14),
        strings.get('chart_prev'),
        color: labelColor,
      );
      _text(
        canvas,
        Offset(size.width - rightPad, size.height - 14),
        strings.get('chart_latest'),
        color: labelColor,
        alignRight: true,
      );
    }
  }

  String _formatTick(String ts, int days) {
    // ts format: "YYYY-MM-DD HH:MM"
    if (ts.length < 16) return ts;
    final mm = ts.substring(5, 7);
    final dd = ts.substring(8, 10);
    final hhmm = ts.substring(11, 16);
    if (days <= 1) return hhmm;
    return '$dd/$mm';
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 5.0;
    const gap = 4.0;
    var x = from.dx;
    while (x < to.dx) {
      final endX = math.min(x + dash, to.dx);
      canvas.drawLine(Offset(x, from.dy), Offset(endX, to.dy), paint);
      x += dash + gap;
    }
  }

  void _text(
    Canvas canvas,
    Offset at,
    String value, {
    required Color color,
    bool alignRight = false,
    bool alignCenter = false,
    double fontSize = 10,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight
        ? at.dx - painter.width
        : (alignCenter ? at.dx - painter.width / 2 : at.dx);
    painter.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(covariant _LevelTrendPainter oldDelegate) =>
      oldDelegate.station != station ||
      oldDelegate.series != series ||
      oldDelegate.inspectedIndex != inspectedIndex ||
      oldDelegate.selectedDays != selectedDays ||
      oldDelegate.isDark != isDark ||
      oldDelegate.strings.lang != strings.lang;
}

class _AffectedVillagesCard extends StatelessWidget {
  const _AffectedVillagesCard({
    required this.villages,
    required this.provider,
    required this.strings,
  });

  final List<({VillagePoint village, ElevationFloodResult eval, double distKm})>
      villages;
  final AlertProvider provider;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.get('affected_villages_near_station'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final entry in villages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AlertLevel.fromValue(entry.eval.level)
                            .colorFor(brightness),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${strings.villageName(entry.village.moo, entry.village.nameTh, entry.village.nameEn)} '
                        '(${strings.tumbonName(entry.village.tumbonTh, provider.tumbonEnOf(entry.village.amphoeTh, entry.village.tumbonTh))})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (entry.eval.marginMeters != null)
                      Text(
                        strings.elevationMarginText(entry.eval.marginMeters!),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AlertLevel.fromValue(entry.eval.level)
                              .colorFor(brightness),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({required this.station, required this.strings});

  final Station station;
  final AppStrings strings;

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
                const Icon(Icons.support_agent, size: 18),
                const SizedBox(width: 8),
                Text(
                  strings.get('guidance_title'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              strings.stationGuidance(
                station.riskLevel,
                station.amphoeTh ?? '',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              strings.get('emergency_kit_note'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.station, required this.strings});

  final Station station;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _row(context, strings.get('meta_station_code'), station.code),
            _row(
              context,
              strings.get('meta_location'),
              strings.stationLocation(station),
            ),
            _row(
              context,
              strings.get('meta_agency'),
              strings.agencyName(station.agencyShortTh),
            ),
            _row(
              context,
              strings.get('meta_update_freq'),
              strings.updateCadenceLabel(station.effectiveUpdateIntervalMinutes),
            ),
            _row(
              context,
              strings.get('meta_basin'),
              strings.riverName(station.basinNameTh),
            ),
            _row(
              context,
              strings.get('meta_river'),
              strings.riverName(station.riverName),
            ),
            _row(
              context,
              strings.get('meta_coords'),
              station.hasCoordinate
                  ? '${station.lat!.toStringAsFixed(5)}, ${station.lng!.toStringAsFixed(5)}'
                  : strings.get('unknown'),
            ),
            if (station.remainingToBank != null)
              _row(
                context,
                strings.get('meta_bank_status'),
                strings.remainingToBankText(station.remainingToBank!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationAlertsCard extends StatelessWidget {
  const _StationAlertsCard({
    required this.station,
    required this.alerts,
    required this.strings,
  });

  final Station station;
  final List<AlertItem> alerts;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.get('station_alert_history'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final alert in alerts.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    RiskBadge(
                      level: alert.level,
                      compact: true,
                      strings: strings,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${strings.riskLevelLabel(alert.level)}: ${strings.stationFullName(station)}\n${strings.relativeTime(alert.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
