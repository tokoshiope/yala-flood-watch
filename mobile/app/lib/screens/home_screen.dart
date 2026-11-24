import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/screens/station_detail_screen.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/risk_badge.dart';
import 'package:yala_flood_app/widgets/station_marker.dart';

/// แถบที่ 1 "แผนที่":
/// - หัวบนสุด "แจ้งเตือนน้ำท่วมยะลา" + เวลาไทย UTC+7
/// - กรอบเขื่อนบางลางอยู่ด้านบนต่อจากแถบหัวเรื่อง
/// - แผนที่ Google Maps แสดงเฉพาะเขต จ.ยะลา (Mask นอกจังหวัด + ล็อกขอบเขต)
/// - ระบายสีระดับน้ำท่วมถึงอ้างอิงความสูงภูมิประเทศจริง (ม.รทก.) เทียบระดับน้ำ
/// - กดขยาย 3 ระดับ: จังหวัดยะลา (8 อำเภอ) -> ตำบลทั้งหมด (58 ตำบล) -> หมู่บ้านทั้งหมด (449 หมู่บ้าน)
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  String? _selectedCode;
  String? _drillAmphoe;
  String? _drillTumbon;

  static final LatLngBounds _yalaBounds = LatLngBounds(
    const LatLng(5.55, 100.78),
    const LatLng(6.76, 101.68),
  );

  static const List<LatLng> _outerWorldMask = [
    LatLng(-20, 60),
    LatLng(-20, 140),
    LatLng(35, 140),
    LatLng(35, 60),
  ];

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _drillToProvince() {
    setState(() {
      _drillAmphoe = null;
      _drillTumbon = null;
      _selectedCode = null;
    });
    _mapController.move(
      const LatLng(AppConfig.defaultLat, AppConfig.defaultLng),
      AppConfig.defaultZoom,
    );
  }

  void _drillToAmphoe(AlertProvider provider, String amphoeTh) {
    setState(() {
      _drillAmphoe = amphoeTh;
      _drillTumbon = null;
    });
    for (final b in provider.boundaries) {
      if (b.amphoeTh == amphoeTh) {
        _mapController.move(b.centroid, 10.6);
        break;
      }
    }
  }

  void _drillToTumbon(AlertProvider provider, String amphoeTh, String tumbonTh) {
    setState(() {
      _drillAmphoe = amphoeTh;
      _drillTumbon = tumbonTh;
    });
    for (final sub in provider.subdistrictsOf(amphoeTh)) {
      if (sub.tumbonTh == tumbonTh) {
        _mapController.move(sub.centroid, 12.2);
        break;
      }
    }
  }

  void _openDetail(Station station) {
    context.read<AlertProvider>().setSelectedStation(station.code);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StationDetailScreen(stationCode: station.code),
      ),
    );
  }

  Future<void> _showStationSheet(Station station) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      station.nameTh,
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                  RiskBadge(level: station.riskLevel),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                station.locationLabel,
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Text(_stationSummary(station)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _openDetail(station);
                  },
                  icon: const Icon(Icons.insights_outlined),
                  label: const Text('ดูรายละเอียดสถานี'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stationSummary(Station station) {
    final level = station.displayLevel;
    final buffer = StringBuffer();
    if (level != null) {
      buffer.write('ระดับน้ำ ${level.toStringAsFixed(2)} ม.รทก.');
    } else {
      buffer.write('ยังไม่มีค่าระดับน้ำ');
    }
    final remaining = station.remainingToBank;
    if (remaining != null) {
      buffer.write(
        remaining >= 0
            ? ' · เหลือ ${remaining.toStringAsFixed(2)} ม. ถึงตลิ่ง'
            : ' · ล้นตลิ่ง ${(-remaining).toStringAsFixed(2)} ม.',
      );
    }
    if (station.trend != WaterTrend.unknown) {
      buffer.write(' · ${station.trend.labelTh}');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final strings = provider.strings;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.get('app_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (provider.lastUpdated != null)
              Text(
                AppStrings.formatThailandTime(provider.lastUpdated!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'โหลดข้อมูลใหม่',
            onPressed: provider.loading
                ? null
                : () => provider.refresh(force: true),
            icon: provider.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _buildBody(context, provider),
    );
  }

  Widget _buildBody(BuildContext context, AlertProvider provider) {
    if (provider.loading && provider.stations.isEmpty) {
      return const _LoadingView();
    }
    if (provider.stations.isEmpty) {
      return _ErrorView(
        messageTh: provider.errorTh ?? 'ยังไม่มีข้อมูลสถานี',
        onRetry: () => provider.refresh(force: true),
      );
    }

    final dam = provider.snapshot?.bangLangDam;

    return Column(
      children: [
        if (provider.isOffline || provider.noticeTh != null)
          _OfflineBanner(messageTh: provider.noticeTh),
        if (dam != null) _BangLangDamCard(dam: dam, strings: provider.strings),
        _DrillBreadcrumbBar(
          drillAmphoe: _drillAmphoe,
          drillTumbon: _drillTumbon,
          provider: provider,
          onBackProvince: _drillToProvince,
          onBackAmphoe: _drillAmphoe == null
              ? null
              : () => _drillToAmphoe(provider, _drillAmphoe!),
        ),
        Expanded(child: _buildMap(provider)),
        _DrillListStrip(
          provider: provider,
          drillAmphoe: _drillAmphoe,
          drillTumbon: _drillTumbon,
          onSelectAmphoe: (amp) => _drillToAmphoe(provider, amp),
          onSelectTumbon: (amp, tam) => _drillToTumbon(provider, amp, tam),
          onSelectVillage: (v) => _mapController.move(v.point, 14.0),
        ),
      ],
    );
  }

  Widget _buildMap(AlertProvider provider) {
    final lang = provider.settings.languageCode;
    final maskHoles = <List<LatLng>>[
      for (final b in provider.boundaries) ...b.rings,
    ];

    final polygons = <Polygon>[];
    if (maskHoles.isNotEmpty) {
      polygons.add(
        Polygon(
          points: _outerWorldMask,
          holePointsList: maskHoles,
          color: const Color(0xD90F172A),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );
    }

    final areaMarkers = <Marker>[];

    if (_drillAmphoe == null) {
      // ระดับที่ 1: ทั้ง 8 อำเภอของ จ.ยะลา
      for (final boundary in provider.boundaries) {
        final level = provider.amphoeAlertLevel(boundary.amphoeTh);
        for (final ring in boundary.rings) {
          polygons.add(
            Polygon(
              points: ring,
              color: level.color.withValues(alpha: 0.34),
              borderColor: Colors.white,
              borderStrokeWidth: 1.8,
            ),
          );
        }
        areaMarkers.add(
          Marker(
            point: boundary.centroid,
            width: 118,
            height: 28,
            child: GestureDetector(
              onTap: () => _drillToAmphoe(provider, boundary.amphoeTh),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: level.color, width: 1.6),
                  ),
                  child: Text(
                    provider.strings.amphoe(boundary.amphoeTh),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } else if (_drillTumbon == null) {
      // ระดับที่ 2: ตำบลทั้งหมดในอำเภอที่เลือก (ระบายสีตามความสูง MSL เทียบระดับน้ำ)
      final subs = provider.subdistrictsOf(_drillAmphoe!);
      for (final sub in subs) {
        final elev = provider.elevationFloodLevel(
          sub.minElevationMsl ?? sub.elevationMsl,
          sub.amphoeTh,
        );
        final lv = AlertLevel.fromValue(elev.level);
        for (final ring in sub.rings) {
          polygons.add(
            Polygon(
              points: ring,
              color: lv.color.withValues(alpha: 0.42),
              borderColor: Colors.white,
              borderStrokeWidth: 1.5,
            ),
          );
        }
        areaMarkers.add(
          Marker(
            point: sub.centroid,
            width: 120,
            height: 28,
            child: GestureDetector(
              onTap: () => _drillToTumbon(provider, sub.amphoeTh, sub.tumbonTh),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: lv.color, width: 1.5),
                  ),
                  child: Text(
                    'ต.${sub.tumbonTh}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } else {
      // ระดับที่ 3: หมู่บ้านทั้งหมดในตำบลที่เลือก (จุดสีตามความสูงจากระดับน้ำทะเล MSL)
      final subs = provider.subdistrictsOf(_drillAmphoe!);
      for (final sub in subs) {
        final isTarget = sub.tumbonTh == _drillTumbon;
        final elev = provider.elevationFloodLevel(
          sub.minElevationMsl ?? sub.elevationMsl,
          sub.amphoeTh,
        );
        final lv = AlertLevel.fromValue(elev.level);
        for (final ring in sub.rings) {
          polygons.add(
            Polygon(
              points: ring,
              color: isTarget
                  ? lv.color.withValues(alpha: 0.18)
                  : const Color(0x331E293B),
              borderColor: isTarget ? const Color(0xFF0E5FA6) : Colors.white54,
              borderStrokeWidth: isTarget ? 2.4 : 1.0,
            ),
          );
        }
      }
      final villages = provider.villagesOf(_drillAmphoe!, _drillTumbon!);
      for (final v in villages) {
        final elev = provider.elevationFloodLevel(v.elevationMsl, v.amphoeTh);
        final lv = AlertLevel.fromValue(elev.level);
        areaMarkers.add(
          Marker(
            point: v.point,
            width: 118,
            height: 36,
            child: GestureDetector(
              onTap: () => _showVillageSheet(v, elev, lv),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: lv.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      v.nameTh,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    final stationMarkers = <Marker>[];
    if (_drillTumbon == null) {
      for (final station in provider.stations) {
        final lat = station.lat;
        final lng = station.lng;
        if (lat == null || lng == null) continue;
        if (_drillAmphoe != null && station.amphoeTh != _drillAmphoe) continue;
        stationMarkers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 92,
            height: 62,
            alignment: Alignment.topCenter,
            child: StationMarker(
              station: station,
              selected: _selectedCode == station.code,
              onTap: () {
                setState(() => _selectedCode = station.code);
                _mapController.move(LatLng(lat, lng), 12.0);
                _showStationSheet(station);
              },
            ),
          ),
        );
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(AppConfig.defaultLat, AppConfig.defaultLng),
        initialZoom: AppConfig.defaultZoom,
        minZoom: 8.5,
        maxZoom: 16,
        cameraConstraint: CameraConstraint.contain(bounds: _yalaBounds),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom |
              InteractiveFlag.drag |
              InteractiveFlag.doubleTapZoom |
              InteractiveFlag.scrollWheelZoom,
        ),
        onTap: (_, _) => setState(() => _selectedCode = null),
      ),
      children: [
        TileLayer(
          urlTemplate: AppConfig.googleMapsTileUrl(lang),
          userAgentPackageName: AppConfig.packageName,
          maxZoom: 18,
        ),
        if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
        if (areaMarkers.isNotEmpty) MarkerLayer(markers: areaMarkers),
        if (stationMarkers.isNotEmpty) MarkerLayer(markers: stationMarkers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              AppConfig.googleMapsAttribution,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showVillageSheet(
    VillagePoint v,
    ElevationFloodResult elev,
    AlertLevel lv,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'หมู่ ${v.moo} ${v.nameTh}',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: lv.color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      lv.labelTh,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('ต.${v.tumbonTh} อ.${v.amphoeTh} จ.ยะลา'),
              const SizedBox(height: 8),
              Text(
                'ความสูงพื้นที่: ${v.elevationMsl?.toStringAsFixed(0) ?? '-'} ม.รทก. · ${elev.summaryTh}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (elev.refWaterMsl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'ระดับน้ำแม่น้ำอ้างอิงในอำเภอ: ${elev.refWaterMsl!.toStringAsFixed(2)} ม.รทก.',
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// กรอบสถานะเขื่อนบางลาง ด้านบนต่อจากแถบ "แจ้งเตือนน้ำท่วมยะลา"
class _BangLangDamCard extends StatelessWidget {
  const _BangLangDamCard({required this.dam, required this.strings});

  final BangLangDamStatus dam;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final spill = dam.spillwayActive;
    final bgStart = spill ? const Color(0xFF991B1B) : const Color(0xFF0B3B75);
    final bgEnd = spill ? const Color(0xFFDC2626) : const Color(0xFF145DA0);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [bgStart, bgEnd]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water, color: Colors.white, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  strings.get('dam_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: spill ? Colors.amber : Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  spill ? 'ระบายน้ำล้นฉุกเฉิน' : 'ควบคุมปกติ',
                  style: TextStyle(
                    color: spill ? const Color(0xFF111827) : Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _metric(
                'ความจุน้ำ',
                dam.storagePercent != null
                    ? '${dam.storagePercent!.toStringAsFixed(1)}%'
                    : '—',
              ),
              const SizedBox(width: 8),
              _metric(
                'ปริมาณน้ำ',
                dam.storageMcm != null
                    ? '${dam.storageMcm!.toStringAsFixed(0)} ล้าน ลบ.ม.'
                    : '—',
              ),
              const SizedBox(width: 8),
              _metric(
                'ระบายน้ำ/วัน',
                dam.releasedDailyMcm != null
                    ? '${dam.releasedDailyMcm!.toStringAsFixed(2)} ล้าน ลบ.ม.'
                    : '—',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrillBreadcrumbBar extends StatelessWidget {
  const _DrillBreadcrumbBar({
    required this.drillAmphoe,
    required this.drillTumbon,
    required this.provider,
    required this.onBackProvince,
    required this.onBackAmphoe,
  });

  final String? drillAmphoe;
  final String? drillTumbon;
  final AlertProvider provider;
  final VoidCallback onBackProvince;
  final VoidCallback? onBackAmphoe;

  @override
  Widget build(BuildContext context) {
    final path = drillAmphoe == null
        ? 'จ.ยะลา (8 อำเภอ · แตะอำเภอเพื่อดูตำบล)'
        : drillTumbon == null
            ? 'จ.ยะลา › อ.$drillAmphoe (${provider.subdistrictsOf(drillAmphoe!).length} ตำบล)'
            : 'อ.$drillAmphoe › ต.$drillTumbon (${provider.villagesOf(drillAmphoe!, drillTumbon!).length} หมู่บ้าน)';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: const Color(0xFFF8FAFC),
      child: Row(
        children: [
          const Icon(Icons.layers_outlined, size: 15, color: Color(0xFF0E5FA6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          if (drillTumbon != null && onBackAmphoe != null)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              onPressed: onBackAmphoe,
              child: const Text('กลับตำบล', style: TextStyle(fontSize: 11)),
            ),
          if (drillAmphoe != null)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              onPressed: onBackProvince,
              child: Text(
                provider.strings.get('map_back_province'),
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _DrillListStrip extends StatelessWidget {
  const _DrillListStrip({
    required this.provider,
    required this.drillAmphoe,
    required this.drillTumbon,
    required this.onSelectAmphoe,
    required this.onSelectTumbon,
    required this.onSelectVillage,
  });

  final AlertProvider provider;
  final String? drillAmphoe;
  final String? drillTumbon;
  final ValueChanged<String> onSelectAmphoe;
  final void Function(String amphoe, String tumbon) onSelectTumbon;
  final ValueChanged<VillagePoint> onSelectVillage;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x22000000))),
      ),
      child: _buildItems(),
    );
  }

  Widget _buildItems() {
    if (drillAmphoe == null) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        itemCount: AppConfig.riskAmphoeTh.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final amp = AppConfig.riskAmphoeTh[i];
          final lv = provider.amphoeAlertLevel(amp);
          return ActionChip(
            avatar: CircleAvatar(backgroundColor: lv.color, radius: 6),
            label: Text(provider.strings.amphoe(amp), style: const TextStyle(fontSize: 12)),
            onPressed: () => onSelectAmphoe(amp),
          );
        },
      );
    }

    if (drillTumbon == null) {
      final subs = provider.subdistrictsOf(drillAmphoe!);
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        itemCount: subs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final sub = subs[i];
          final elev = provider.elevationFloodLevel(
            sub.minElevationMsl ?? sub.elevationMsl,
            sub.amphoeTh,
          );
          final lv = AlertLevel.fromValue(elev.level);
          return ActionChip(
            avatar: CircleAvatar(backgroundColor: lv.color, radius: 6),
            label: Text(
              'ต.${sub.tumbonTh} (${sub.minElevationMsl?.toStringAsFixed(0) ?? '-'} ม.รทก.)',
              style: const TextStyle(fontSize: 11.5),
            ),
            onPressed: () => onSelectTumbon(sub.amphoeTh, sub.tumbonTh),
          );
        },
      );
    }

    final villages = provider.villagesOf(drillAmphoe!, drillTumbon!);
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      itemCount: villages.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (_, i) {
        final v = villages[i];
        final elev = provider.elevationFloodLevel(v.elevationMsl, v.amphoeTh);
        final lv = AlertLevel.fromValue(elev.level);
        return ActionChip(
          avatar: CircleAvatar(backgroundColor: lv.color, radius: 6),
          label: Text(
            'ม.${v.moo} ${v.nameTh} (${v.elevationMsl?.toStringAsFixed(0) ?? '-'} ม.)',
            style: const TextStyle(fontSize: 11.5),
          ),
          onPressed: () => onSelectVillage(v),
        );
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({this.messageTh});

  final String? messageTh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 16, color: Color(0xFFEF6C00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              messageTh ?? 'ไม่มีสัญญาณเน็ต กำลังแสดงข้อมูลล่าสุดที่บันทึกไว้',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6D4C00)),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('กำลังโหลดข้อมูลระดับน้ำของจังหวัดยะลา…', style: TextStyle(fontSize: 15)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.messageTh, required this.onRetry});

  final String messageTh;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.water_damage_outlined, size: 56, color: Color(0xFF0E5FA6)),
            const SizedBox(height: 16),
            const Text('ขออภัย โหลดข้อมูลไม่สำเร็จ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(messageTh, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      ),
    );
  }
}
