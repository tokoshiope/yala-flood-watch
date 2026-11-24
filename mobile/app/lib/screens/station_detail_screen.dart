import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/screens/sos_screen.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/risk_badge.dart';

/// หน้ารายละเอียดสถานี: ระดับน้ำ เทียบตลิ่ง กราฟแนวโน้ม และคำแนะนำ
/// รองรับ iOS Dark Mode และ 4 ภาษาเต็มรูปแบบ
class StationDetailScreen extends StatelessWidget {
  const StationDetailScreen({super.key, required this.stationCode});

  final String stationCode;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final strings = provider.strings;
    final station = provider.stationByCode(stationCode);

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

    return Scaffold(
      appBar: AppBar(title: Text(strings.stationFullName(station))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _HeaderCard(station: station, strings: strings),
          const SizedBox(height: 12),
          _LevelCard(station: station, strings: strings),
          const SizedBox(height: 12),
          _BankCard(station: station, strings: strings),
          const SizedBox(height: 12),
          _ChartCard(station: station, strings: strings),
          const SizedBox(height: 12),
          _GuidanceCard(station: station, strings: strings),
          const SizedBox(height: 12),
          _InfoCard(station: station, strings: strings),
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _StationAlertsCard(station: station, alerts: alerts, strings: strings),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _goToSos(context),
                  icon: const Icon(Icons.emergency_share),
                  label: Text(strings.get('request_help_btn')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _goToSos(BuildContext context) {
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
      color: level.colorFor(brightness).withValues(alpha: brightness == Brightness.dark ? 0.16 : 0.08),
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
                    style: Theme.of(context).textTheme.titleMedium,
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

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.station, required this.strings});

  final Station station;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final level = station.riskLevel;
    final displayColor = level.colorFor(brightness);
    final wl = station.displayLevel;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.get('latest_water_level'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wl == null ? '—' : '${wl.toStringAsFixed(2)} ${strings.get('unit_m')}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: displayColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(strings.get('msl_full_label')),
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
                      ? (isDark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32))
                      : (isDark ? const Color(0xFFFF6B6B) : const Color(0xFFC62828)),
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
                    color: station.riskLevel.colorFor(Theme.of(context).brightness),
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

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.station, required this.strings});

  final Station station;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    strings.get('trend_chart_title'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  strings.get('trend_chart_sub'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              width: double.infinity,
              child: CustomPaint(
                painter: _LevelTrendPainter(
                  station: station,
                  strings: strings,
                  isDark: isDark,
                  labelColor: cs.onSurface,
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
    required this.strings,
    required this.isDark,
    required this.labelColor,
  });

  final Station station;
  final AppStrings strings;
  final bool isDark;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final wl = station.displayLevel;
    final prev = station.waterLevelMslPrev;
    if (wl == null) {
      _text(
        canvas,
        size.center(Offset.zero),
        strings.get('no_water_reading'),
        color: labelColor,
      );
      return;
    }

    final bank = station.bankLevel;
    final ground = station.groundLevel;
    final values = <double>[wl];
    if (prev != null) values.add(prev);
    var minV = values.reduce((a, b) => a < b ? a : b);
    var maxV = values.reduce((a, b) => a > b ? a : b);
    final extras = <double>[];
    if (bank != null && bank > 0) extras.add(bank);
    if (ground != null) extras.add(ground);
    for (final extra in extras) {
      if (extra < minV) minV = extra;
      if (extra > maxV) maxV = extra;
    }
    if (maxV - minV < 0.2) {
      final mid = (maxV + minV) / 2;
      minV = mid - 0.5;
      maxV = mid + 0.5;
    } else {
      minV -= 0.15;
      maxV += 0.15;
    }

    const leftPad = 52.0;
    const rightPad = 14.0;
    const topPad = 18.0;
    const bottomPad = 22.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    double yOf(double v) =>
        topPad + chartH * (1 - (v - minV) / (maxV - minV));

    final grid = Paint()
      ..color = isDark ? const Color(0x33FFFFFF) : const Color(0x1A000000)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = topPad + chartH * i / 4;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), grid);
    }

    final bankColor = isDark ? const Color(0xFFFF6B6B) : const Color(0xFFC62828);
    if (bank != null && bank > 0) {
      final bankPaint = Paint()
        ..color = bankColor
        ..strokeWidth = 1.6;
      final y = yOf(bank);
      _dashedLine(
        canvas,
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        bankPaint,
      );
      _text(
        canvas,
        Offset(leftPad - 4, y - 6),
        '${strings.get('bank_label')} ${bank.toStringAsFixed(1)}',
        color: bankColor,
        alignRight: true,
      );
    }

    final lineColor = station.riskLevel.colorFor(isDark ? Brightness.dark : Brightness.light);
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final p1 = Offset(leftPad + chartW * 0.12, yOf(prev ?? wl));
    final p2 = Offset(leftPad + chartW * 0.88, yOf(wl));
    final fill = Path()
      ..moveTo(p1.dx, topPad + chartH)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p2.dx, topPad + chartH)
      ..close();
    canvas.drawPath(fill, Paint()..color = lineColor.withValues(alpha: 0.16));
    canvas.drawLine(p1, p2, linePaint);

    canvas.drawCircle(p1, 4.5, Paint()..color = lineColor);
    canvas.drawCircle(p2, 5.5, Paint()..color = lineColor);
    canvas.drawCircle(
      p2,
      5.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    _text(
      canvas,
      Offset(p1.dx - 6, p1.dy - 18),
      (prev ?? wl).toStringAsFixed(2),
      color: labelColor,
      alignRight: true,
    );
    _text(
      canvas,
      Offset(p2.dx - 6, p2.dy - 18),
      wl.toStringAsFixed(2),
      color: lineColor,
      alignRight: true,
    );

    _text(canvas, Offset(leftPad, size.height - 6), strings.get('chart_prev'), color: labelColor);
    _text(
      canvas,
      Offset(size.width - rightPad, size.height - 6),
      strings.get('chart_latest'),
      color: labelColor,
      alignRight: true,
    );
  }

  void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    var x = from.dx;
    while (x < to.dx) {
      canvas.drawLine(Offset(x, from.dy), Offset(x + dash, to.dy), paint);
      x += dash + gap;
    }
  }

  void _text(
    Canvas canvas,
    Offset at,
    String value, {
    required Color color,
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = alignRight ? at - Offset(painter.width, 0) : at;
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LevelTrendPainter oldDelegate) =>
      oldDelegate.station != station ||
      oldDelegate.isDark != isDark ||
      oldDelegate.strings.lang != strings.lang;
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
            Text(strings.stationGuidance(station.riskLevel, station.amphoeTh ?? '')),
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
            _row(context, strings.get('meta_location'), strings.stationLocation(station)),
            _row(context, strings.get('meta_agency'), strings.agencyName(station.agencyShortTh)),
            _row(context, strings.get('meta_basin'), strings.riverName(station.basinNameTh)),
            _row(context, strings.get('meta_river'), strings.riverName(station.riverName)),
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
                    RiskBadge(level: alert.level, compact: true, strings: strings),
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
