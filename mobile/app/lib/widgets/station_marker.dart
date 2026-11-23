import 'package:material_ui/material_ui.dart';

import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';

/// หมุดสถานีบนแผนที่ แสดงสีตามระดับความเสี่ยง + ตัวอักษรย่อสถานี
///
/// ใช้เป็น [Marker.child] ของ flutter_map (ต้องมีขนาดใน [width]/[height])
class StationMarker extends StatelessWidget {
  const StationMarker({
    super.key,
    required this.station,
    required this.onTap,
    this.selected = false,
  });

  final Station station;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final level = station.riskLevel;
    final color = level.color;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ป้ายชื่อสถานี
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? color : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              station.code,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // หมุด
          Container(
            width: selected ? 26 : 22,
            height: selected ? 26 : 22,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: selected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
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
