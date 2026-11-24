import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/flood_snapshot.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/screens/alerts_screen.dart';
import 'package:yala_flood_app/screens/station_detail_screen.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/risk_badge.dart';
import 'package:yala_flood_app/widgets/station_marker.dart';

/// หน้าหลัก: แผนที่ Google Maps แบ่งเขต 8 อำเภอระบายสีตามระดับแจ้งเตือน,
/// เวลาไทย (UTC+7), แถบเลื่อนกราฟพยากรณ์ฝนรายชั่วโมง และรายการสถานีล่าสุด
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  String? _selectedCode;
  bool _rainDrawerOpen = false;

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
    _mapController.move(LatLng(lat, lng), 12.0);
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
    final strings = provider.strings;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(strings.get('app_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: strings.get('tab_alerts'),
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

    final focusAmphoe = _focusAmphoeForecast(provider);

    return Column(
      children: [
        if (provider.isOffline || provider.noticeTh != null)
          _OfflineBanner(messageTh: provider.noticeTh),
        Expanded(child: _buildMap(provider)),
        if (focusAmphoe != null && focusAmphoe.hourlyNext24h.isNotEmpty)
          _RainForecastDrawer(
            amphoeLabel: provider.strings.amphoe(focusAmphoe.amphoeTh),
            forecast: focusAmphoe,
            expanded: _rainDrawerOpen,
            strings: provider.strings,
            onToggle: () => setState(() => _rainDrawerOpen = !_rainDrawerOpen),
          ),
        _StationCarousel(
          title: provider.strings.get('latest_stations'),
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

  AmphoeForecastSummary? _focusAmphoeForecast(AlertProvider provider) {
    final snap = provider.snapshot;
    if (snap == null || snap.amphoes.isEmpty) return null;
    final sub = provider.settings.selectedAmphoeTh;
    if (sub != null) {
      final matched = snap.byAmphoe(sub);
      if (matched != null) return matched;
    }
    return snap.amphoes.first;
  }

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
    final lang = provider.settings.languageCode;
    final polygons = <Polygon>[];
    final amphoeMarkers = <Marker>[];

    for (final boundary in provider.boundaries) {
      final level = provider.amphoeAlertLevel(boundary.amphoeTh);
      final isSelected = provider.settings.selectedAmphoeTh == boundary.amphoeTh;
      for (final ring in boundary.rings) {
        polygons.add(
          Polygon(
            points: ring,
            color: level.color.withValues(alpha: isSelected ? 0.45 : 0.28),
            borderColor: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderStrokeWidth: isSelected ? 2.4 : 1.4,
          ),
        );
      }
      amphoeMarkers.add(
        Marker(
          point: boundary.centroid,
          width: 112,
          height: 24,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: level.color, width: 1.4),
              ),
              child: Text(
                '${provider.strings.amphoe(boundary.amphoeTh)} · Lv.${level.value}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
      );
    }

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
              _mapController.move(LatLng(lat, lng), 12.0);
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
          urlTemplate: AppConfig.googleMapsTileUrl(lang),
          userAgentPackageName: AppConfig.packageName,
          maxZoom: 18,
        ),
        if (polygons.isNotEmpty) PolygonLayer(polygons: polygons),
        if (amphoeMarkers.isNotEmpty) MarkerLayer(markers: amphoeMarkers),
        MarkerLayer(markers: markers),
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
}

/// แถบเลื่อนกราฟพยากรณ์ฝนรายชั่วโมง (UTC+7) แสดงช่องเวลาชัดเจน
class _RainForecastDrawer extends StatelessWidget {
  const _RainForecastDrawer({
    required this.amphoeLabel,
    required this.forecast,
    required this.expanded,
    required this.strings,
    required this.onToggle,
  });

  final String amphoeLabel;
  final AmphoeForecastSummary forecast;
  final bool expanded;
  final AppStrings strings;
  final VoidCallback onToggle;

  Color _barColor(double mm) {
    if (mm >= 20) return const Color(0xFFB71C1C);
    if (mm >= 10) return const Color(0xFFEF6C00);
    if (mm >= 3) return const Color(0xFFF59E0B);
    if (mm > 0) return const Color(0xFF0284C7);
    return const Color(0xFF94A3B8);
  }

  @override
  Widget build(BuildContext context) {
    final maxMm = forecast.hourlyNext24h.fold<double>(
      10.0,
      (prev, e) => e.mm > prev ? e.mm : prev,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0x22000000))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.water_drop_outlined, size: 16, color: Color(0xFF0E5FA6)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$amphoeLabel · 24h: ${forecast.forecast24hMm.toStringAsFixed(1)} มม. · '
                      '${expanded ? strings.get('rain_drawer_open') : strings.get('rain_drawer_closed')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0E5FA6),
                      ),
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: const Color(0xFF0E5FA6)),
                ],
              ),
            ),
          ),
          if (expanded)
            SizedBox(
              height: 170,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                itemCount: forecast.hourlyNext24h.length,
                itemBuilder: (context, idx) {
                  final pt = forecast.hourlyNext24h[idx];
                  final ratio = (pt.mm / maxMm).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 58,
                          child: Text(
                            '${pt.hourMinute} น.',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: pt.mm > 0 ? ratio.clamp(0.06, 1.0) : 0.02,
                              minHeight: 10,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(_barColor(pt.mm)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 78,
                          child: Text(
                            '${pt.mm.toStringAsFixed(1)} มม. · ${pt.probPct}%',
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
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

class _StationCarousel extends StatelessWidget {
  const _StationCarousel({
    required this.title,
    required this.stations,
    required this.selectedCode,
    required this.onTap,
  });

  final String title;
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
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text(
                '${stations.length} แห่ง · UTC+7',
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
                    station.datetime != null ? '${station.datetime} (UTC+7)' : 'ไม่ระบุเวลา',
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
