import 'package:material_ui/material_ui.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/screens/alerts_screen.dart';
import 'package:yala_flood_app/screens/station_detail_screen.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/risk_badge.dart';
import 'package:yala_flood_app/widgets/station_marker.dart';

/// หน้าหลัก: แผนที่สถานีวัดระดับน้ำ + รายการสถานีล่าสุด
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  String? _selectedCode;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _focusStation(Station station) {
    final lat = station.lat;
    final lng = station.lng;
    if (lat == null || lng == null) return;
    setState(() => _selectedCode = station.code);
    _mapController.move(LatLng(lat, lng), 12.5);
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
                '${station.locationLabel} · ${station.code}',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(_stationSummary(station)),
              const SizedBox(height: 16),
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
      buffer.write('ระดับน้ำ ${level.toStringAsFixed(2)} ม. (MSL)');
    } else {
      buffer.write('ยังไม่มีค่าระดับน้ำ');
    }
    final remaining = station.remainingToBank;
    if (remaining != null) {
      buffer.write(
        remaining >= 0
            ? ' เหลือ ${remaining.toStringAsFixed(2)} ม. ถึงตลิ่ง'
            : ' ล้นตลิ่ง ${(-remaining).toStringAsFixed(2)} ม.',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConfig.appName),
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
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: 'การแจ้งเตือน',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AlertsScreen(),
                  ),
                ),
                icon: const Icon(Icons.notifications_outlined),
              ),
              if (provider.unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(AppConfig.colorDanger),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${provider.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
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

    return Column(
      children: [
        if (provider.isOffline || provider.noticeTh != null)
          _OfflineBanner(messageTh: provider.noticeTh),
        Expanded(child: _buildMap(provider)),
        _StationCarousel(
          stations: _sortedStations(provider),
          selectedCode: _selectedCode,
          onTap: (station) {
            _focusStation(station);
            _showStationSheet(station);
          },
        ),
      ],
    );
  }

  /// สถานีที่อัปเดตล่าสุดก่อน (ข้อมูลล่าสุดจากกระทรวง)
  List<Station> _sortedStations(AlertProvider provider) {
    final list = [...provider.stations];
    list.sort((a, b) {
      final aTime = DateTime.tryParse(a.datetime ?? '');
      final bTime = DateTime.tryParse(b.datetime ?? '');
      if (aTime != null && bTime != null) {
        final byTime = bTime.compareTo(aTime);
        if (byTime != 0) return byTime;
      }
      return b.riskLevel.severity.compareTo(a.riskLevel.severity);
    });
    return list;
  }

  Widget _buildMap(AlertProvider provider) {
    final markers = <Marker>[];
    for (final station in provider.stations) {
      final lat = station.lat;
      final lng = station.lng;
      if (lat == null || lng == null) continue;
      markers.add(
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
              _mapController.move(LatLng(lat, lng), 12.5);
              _showStationSheet(station);
            },
          ),
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(AppConfig.defaultLat, AppConfig.defaultLng),
        initialZoom: AppConfig.defaultZoom,
        minZoom: 7,
        maxZoom: 16,
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
          urlTemplate: AppConfig.osmTileUrl,
          userAgentPackageName: AppConfig.packageName,
          maxZoom: 19,
        ),
        MarkerLayer(markers: markers),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              AppConfig.osmAttribution,
              onTap: () {},
            ),
          ],
        ),
      ],
    );
  }
}

/// แถบเตือนเมื่อใช้ข้อมูลสำรอง
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({this.messageTh});

  final String? messageTh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: Color(0xFFEF6C00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              messageTh ?? 'ไม่มีสัญญาณเน็ต กำลังแสดงข้อมูลล่าสุดที่บันทึกไว้',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6D4C00)),
            ),
          ),
        ],
      ),
    );
  }
}

/// สถานีล่าสุดแนวนอน
class _StationCarousel extends StatelessWidget {
  const _StationCarousel({
    required this.stations,
    required this.selectedCode,
    required this.onTap,
  });

  final List<Station> stations;
  final String? selectedCode;
  final ValueChanged<Station> onTap;

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0x22000000))),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.update, size: 16),
              const SizedBox(width: 6),
              Text(
                'สถานีอัปเดตล่าสุด',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                '${stations.length} แห่ง',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: stations.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final station = stations[index];
                return _StationCard(
                  station: station,
                  selected: station.code == selectedCode,
                  onTap: () => onTap(station),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.station,
    required this.selected,
    required this.onTap,
  });

  final Station station;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final level = station.riskLevel;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? level.color.withValues(alpha: 0.10) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? level.color : const Color(0x22000000),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    station.nameTh,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                RiskDot(level: level),
              ],
            ),
            const Spacer(),
            Text(
              station.displayLevel == null
                  ? '— ม.'
                  : '${station.displayLevel!.toStringAsFixed(2)} ม.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: level.color,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(station.trend.icon, size: 14, color: station.trend.color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    station.datetime ?? 'ไม่ระบุเวลา',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'กำลังโหลดข้อมูลระดับน้ำของจังหวัดยะลา…',
            style: TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'ใช้เวลาไม่กี่วินาที แอพจะจำข้อมูลไว้ให้ใช้ต่อได้แม้เน็ตขาด',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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
            const Text(
              'ขออภัย โหลดข้อมูลไม่สำเร็จ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              messageTh,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
            const SizedBox(height: 12),
            Text(
              'ถ้าเน็ตกลับมาแล้ว แอพจะโหลดค่าใหม่ให้อัตโนมัติ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
