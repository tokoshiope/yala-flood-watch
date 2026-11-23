import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/models/alert.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/sos_request.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/screens/sos_screen.dart';
import 'package:yala_flood_app/services/alert_engine.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/risk_badge.dart';

/// หน้ารายละเอียดสถานี: ระดับน้ำ เทียบตลิ่ง กราฟจำลอง และคำแนะนำ
class StationDetailScreen extends StatelessWidget {
  const StationDetailScreen({super.key, required this.stationCode});

  final String stationCode;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final station = provider.stationByCode(stationCode);

    if (station == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('รายละเอียดสถานี')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('ไม่พบสถานีนี้ในข้อมูล ลองโหลดข้อมูลใหม่อีกครั้ง'),
          ),
        ),
      );
    }

    final alerts = provider.alerts
        .where((a) => a.stationCode == station.code)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(station.nameTh)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _HeaderCard(station: station),
          const SizedBox(height: 12),
          _LevelCard(station: station),
          const SizedBox(height: 12),
          _BankCard(station: station),
          const SizedBox(height: 12),
          _ChartCard(station: station),
          const SizedBox(height: 12),
          _GuidanceCard(station: station),
          const SizedBox(height: 12),
          _InfoCard(station: station),
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _StationAlertsCard(alerts: alerts),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _goToSos(context),
                  icon: const Icon(Icons.emergency_share),
                  label: const Text('ขอความช่วยเหลือ'),
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
  const _HeaderCard({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final level = station.riskLevel;
    return Card(
      color: level.color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    station.nameTh,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${station.locationLabel} · ${station.code}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            RiskBadge(level: level),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final level = station.riskLevel;
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
                    'ระดับน้ำล่าสุด',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wl == null ? '—' : '${wl.toStringAsFixed(2)} ม.',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: level.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('ม.ระดับน้ำทะเลปานกลาง (MSL)'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              children: [
                Icon(station.trend.icon, size: 30, color: station.trend.color),
                const SizedBox(height: 4),
                Text(
                  station.trend.labelTh,
                  style: TextStyle(
                    color: station.trend.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'ข้อมูล ${station.datetime ?? 'ไม่ระบุ'}',
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
  const _BankCard({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
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
                    'เทียบตลิ่ง',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  bank == null || bank <= 0
                      ? 'ไม่มีข้อมูลตลิ่ง'
                      : 'ตลิ่ง ${bank.toStringAsFixed(2)} ม.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (bank != null && bank > 0 && wl != null)
              _BankBar(station: station)
            else
              const Text(
                'สถานีนี้ไม่มีค่าระดับตลิ่งจากกระทรวง จึงเปรียบเทียบไม่ได้ '
                'โปรดติดตามจาก ศูนย์ปภ.ยะลา',
              ),
            if (remaining != null) ...[
              const SizedBox(height: 10),
              Text(
                remaining >= 0
                    ? 'เหลือ ${remaining.toStringAsFixed(2)} ม. ก่อนถึงตลิ่ง'
                    : 'ล้นตลิ่งแล้ว ${(-remaining).toStringAsFixed(2)} ม.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: remaining >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                ),
              ),
            ],
            if (station.storagePercent != null) ...[
              const SizedBox(height: 8),
              Text(
                'ความจุอ่างเก็บน้ำ ${station.storagePercent!.toStringAsFixed(1)}%',
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
  const _BankBar({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
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
                Container(color: const Color(0xFFE3F2FD)),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    color: station.riskLevel.color,
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
                  ? 'ระดับพื้น ${ground.toStringAsFixed(1)}'
                  : 'ระดับพื้น —',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'ตลิ่ง ${bank.toStringAsFixed(1)} ม.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.station});

  final Station station;

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
                const Icon(Icons.show_chart, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'แนวโน้มระดับน้ำ',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  'จำลองจากค่าก่อนหน้า',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              width: double.infinity,
              child: CustomPaint(
                painter: _LevelTrendPainter(station: station),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// วาดกราฟระดับน้ำ 2 จุด (ก่อนหน้า → ล่าสุด) พร้อมเส้นตลิ่ง
class _LevelTrendPainter extends CustomPainter {
  _LevelTrendPainter({required this.station});

  final Station station;

  @override
  void paint(Canvas canvas, Size size) {
    final wl = station.displayLevel;
    final prev = station.waterLevelMslPrev;
    if (wl == null) {
      _text(canvas, size.center(Offset.zero), 'ยังไม่มีค่าระดับน้ำ');
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

    const leftPad = 44.0;
    const rightPad = 12.0;
    const topPad = 18.0;
    const bottomPad = 22.0;
    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    double yOf(double v) =>
        topPad + chartH * (1 - (v - minV) / (maxV - minV));

    // กริดแนวนอน
    final grid = Paint()
      ..color = const Color(0x1A000000)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = topPad + chartH * i / 4;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), grid);
    }

    // เส้นตลิ่ง
    if (bank != null && bank > 0) {
      final bankPaint = Paint()
        ..color = const Color(0xFFC62828)
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
        'ตลิ่ง ${bank.toStringAsFixed(1)}',
        color: const Color(0xFFC62828),
        alignRight: true,
      );
    }

    // เส้นระดับน้ำ
    final linePaint = Paint()
      ..color = station.riskLevel.color
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
    canvas.drawPath(fill, Paint()..color = station.riskLevel.color.withValues(alpha: 0.12));
    canvas.drawLine(p1, p2, linePaint);

    canvas.drawCircle(p1, 4.5, Paint()..color = station.riskLevel.color);
    canvas.drawCircle(p2, 5.5, Paint()..color = station.riskLevel.color);
    canvas.drawCircle(
      p2,
      5.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    _text(canvas, Offset(p1.dx - 8, p1.dy - 18), (prev ?? wl).toStringAsFixed(2),
        alignRight: true);
    _text(
      canvas,
      Offset(p2.dx + 8, p2.dy - 18),
      wl.toStringAsFixed(2),
      color: station.riskLevel.color,
    );

    // ป้ายแกน X
    _text(canvas, Offset(leftPad, size.height - 6), 'ก่อนหน้า');
    _text(canvas, Offset(size.width - rightPad, size.height - 6), 'ล่าสุด',
        alignRight: true);
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
    Color color = const Color(0xFF424242),
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = alignRight
        ? at - Offset(painter.width, 0)
        : at;
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LevelTrendPainter oldDelegate) =>
      oldDelegate.station != station;
}

class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final engine = const AlertEngine();
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
                Text('คำแนะนำ', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(engine.guidanceTh(station.riskLevel, station.amphoeTh ?? '')),
            const SizedBox(height: 8),
            const Text(
              'หากมีถุงยังชีพ เตรียมไว้ที่บ้านและอยู่ในที่สูงอย่างน้อย 1 เมตร',
              style: TextStyle(fontSize: 13, color: Color(0xFF616161)),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _row(context, 'รหัสสถานี', station.code),
            _row(context, 'อำเภอ/ตำบล', station.locationLabel),
            _row(context, 'หน่วยงาน', station.agencyShortTh ?? 'ไม่ระบุ'),
            _row(context, 'ลุ่มน้ำ', station.basinNameTh ?? 'ไม่ระบุ'),
            _row(context, 'แม่น้ำ', station.riverName ?? 'ไม่ระบุ'),
            _row(context, 'พิกัด', station.hasCoordinate ? '${station.lat!.toStringAsFixed(5)}, ${station.lng!.toStringAsFixed(5)}' : 'ไม่ระบุ'),
            _row(context, 'ครั้งล่าสุดที่มีการเปลี่ยนแปลง', station.diffWlBankText ?? 'ไม่ระบุ'),
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
            width: 150,
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
  const _StationAlertsCard({required this.alerts});

  final List<AlertItem> alerts;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ประวัติแจ้งเตือนของสถานีนี้',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final alert in alerts.take(5))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    RiskBadge(level: alert.level, compact: true),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${alert.title}\n${thaiRelativeTime(alert.createdAt)}',
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
