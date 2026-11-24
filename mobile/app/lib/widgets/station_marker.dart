import 'package:material_ui/material_ui.dart';

import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';

/// หมุดสถานีวัดระดับน้ำบนแผนที่ แสดงชื่อสถานีจริง (เช่น "บ้านปายอยือนิ" ไม่ใช่รหัส X.273)
/// พร้อมคอนทราสต์สูงชัดเจนทั้ง iOS Light Mode และ Dark Mode
class StationMarker extends StatelessWidget {
  const StationMarker({
    super.key,
    required this.station,
    required this.onTap,
    this.selected = false,
    this.strings = const AppStrings('th'),
  });

  final Station station;
  final VoidCallback onTap;
  final bool selected;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final level = station.riskLevel;
    final pinColor = level.color;
    final borderColor = level.colorFor(Theme.of(context).brightness);
    final labelText = strings.stationShortName(station);

    final bgColor = selected
        ? pinColor
        : (isDark ? const Color(0xF20F172A) : const Color(0xFAFFFFFF));
    final fgColor = selected
        ? level.onColor
        : (isDark ? Colors.white : const Color(0xFF0F172A));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ป้ายชื่อสถานีจริง (อ่านชัดทั้ง Light / Dark Mode)
          Container(
            constraints: const BoxConstraints(maxWidth: 132),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: borderColor, width: 1.4),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 4,
                  offset: Offset(0, 1.5),
                ),
              ],
            ),
            child: Text(
              labelText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: fgColor,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // หมุดสถานี
          Container(
            width: selected ? 26 : 22,
            height: selected ? 26 : 22,
            decoration: BoxDecoration(
              color: pinColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: selected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: pinColor.withValues(alpha: 0.55),
                  blurRadius: selected ? 10 : 4,
                ),
              ],
            ),
            child: Icon(
              level.isAtLeastWarning
                  ? Icons.warning_amber_rounded
                  : Icons.water_drop,
              size: selected ? 15 : 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
