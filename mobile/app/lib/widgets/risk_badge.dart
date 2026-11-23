import 'package:material_ui/material_ui.dart';

import 'package:yala_flood_app/models/risk_level.dart';

/// ตัวพิมพ์สีตามระดับความเสี่ยง
class RiskBadge extends StatelessWidget {
  const RiskBadge({
    super.key,
    required this.level,
    this.compact = false,
    this.showIcon = true,
  });

  final RiskLevel level;
  final bool compact;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final color = level.color;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(level.icon, size: compact ? 13 : 16, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            level.labelTh,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 12 : 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// แถบสถานะแนวนอน (เช่น ต่ำกว่าตลิ่ง/ล้นตลิ่ง)
class RiskDot extends StatelessWidget {
  const RiskDot({super.key, required this.level, this.size = 10});

  final RiskLevel level;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: level.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}
