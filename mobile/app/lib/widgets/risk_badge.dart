import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// ตัวพิมพ์สีตามระดับความเสี่ยง รองรับทั้งโหมดสว่าง/โหมดมืด iOS และ 4 ภาษา
class RiskBadge extends StatelessWidget {
  const RiskBadge({
    super.key,
    required this.level,
    this.compact = false,
    this.showIcon = true,
    this.strings,
  });

  final RiskLevel level;
  final bool compact;
  final bool showIcon;
  final AppStrings? strings;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = level.colorFor(brightness);
    final resolvedStrings = strings ?? _tryStrings(context);
    final label = resolvedStrings?.riskLevelLabel(level) ?? level.labelTh;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: brightness == Brightness.dark ? 0.22 : 0.14),
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
            label,
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

  static AppStrings? _tryStrings(BuildContext context) {
    try {
      return context.watch<AlertProvider>().strings;
    } catch (_) {
      return null;
    }
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
