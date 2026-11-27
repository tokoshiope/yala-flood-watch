import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/l10n/app_strings.dart';
import 'package:yala_flood_app/models/risk_level.dart';
import 'package:yala_flood_app/models/station.dart';
import 'package:yala_flood_app/screens/settings_screen.dart';
import 'package:yala_flood_app/screens/shelters_screen.dart';
import 'package:yala_flood_app/services/alert_engine.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/snapshot_service.dart';
import 'package:yala_flood_app/services/thai_water_service.dart';
import 'package:yala_flood_app/state/alert_provider.dart';
import 'package:yala_flood_app/widgets/station_marker.dart';

void main() {
  const engine = AlertEngine();

  group('Curved GIS, Real DEM Grid, Elevation Zones & Village Zones', () {
    test('Parses high-res curved boundaries, DEM grid, elevation zones & MultiPolygon village zones', () {
      final dem = SnapshotService.parseDemGrid(
        File('assets/geo/yala_dem_grid.json').readAsStringSync(),
      );
      expect(dem, isNotNull);
      final yalaElev = dem!.elevationAt(6.5415, 101.2812);
      final betongElev = dem.elevationAt(5.7853, 101.0587);
      expect(yalaElev, isNotNull);
      expect(betongElev, isNotNull);
      expect(yalaElev!, lessThan(60.0));
      expect(betongElev!, greaterThan(150.0));

      final ez = SnapshotService.parseElevationZones(
        File('assets/geo/yala_elevation_zones.geojson').readAsStringSync(),
      );
      expect(ez.length, greaterThanOrEqualTo(100));
      expect(ez.map((e) => e.amphoeTh).toSet(), containsAll(AppConfig.riskAmphoeTh));
      expect(ez.every((e) => const {'A', 'B', 'C'}.contains(e.exposureZone)), isTrue);

      final vz = SnapshotService.parseVillageZones(
        File('assets/geo/yala_village_zones.geojson').readAsStringSync(),
      );
      expect(vz.length, greaterThanOrEqualTo(430));
      expect(vz.every((v) => v.rings.isNotEmpty), isTrue);
    });
  });

  group('Real Station Names, Complete 4-Language Coverage & Dark Mode UI', () {
    testWidgets('StationMarker shows real station name บ้านปายอยือนิ (not X.273) & adapts to Dark Mode', (tester) async {
      const x273 = Station(
        id: 273,
        code: 'X.273',
        nameTh: 'บ้านปายอยือนิ',
        lat: 6.47977,
        lng: 101.44474,
        waterLevelMsl: 12.37,
        leftBank: 16.5,
        amphoeTh: 'รามัน',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: Center(
              child: StationMarker(
                station: x273,
                strings: const AppStrings('th'),
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('บ้านปายอยือนิ'), findsOneWidget);
      expect(find.text('X.273'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: Center(
              child: StationMarker(
                station: x273,
                strings: const AppStrings('en'),
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Ban Payo Yuni'), findsOneWidget);
    });

    test('All 4 languages (th/en/zh/ms) have zero Thai leakage in non-Thai modes', () {
      final thaiRegex = RegExp(r'[\u0E00-\u0E7F]');
      for (final lang in const ['en', 'zh', 'ms']) {
        final s = AppStrings(lang);
        for (var lv = 1; lv <= 5; lv++) {
          expect(thaiRegex.hasMatch(s.alertLevelLabel(lv)), isFalse, reason: '$lang lv$lv label');
          expect(thaiRegex.hasMatch(s.alertLevelDesc(lv)), isFalse, reason: '$lang lv$lv desc');
          expect(thaiRegex.hasMatch(s.alertLevelAction(lv)), isFalse, reason: '$lang lv$lv action');
        }
        for (final key in const [
          'zone_c_advisory_lv3',
          'zone_c_advisory_lv4',
          'zone_c_advisory_flash_lv4',
          'zone_c_advisory_lv5',
          'guide_title',
          'guide_tab_app',
          'guide_tab_evac',
          'guide_card_sub',
          'guide_open_web',
          'guide_offline_badge',
          'rain_chart_axis_legend',
        ]) {
          expect(thaiRegex.hasMatch(s.get(key)), isFalse, reason: '$lang key $key');
        }
        for (final sh in kYalaShelters) {
          expect(thaiRegex.hasMatch(s.shelterName(sh.nameTh)), isFalse, reason: '$lang shelter ${sh.nameTh}');
        }
        for (final amp in AppConfig.riskAmphoeTh) {
          expect(thaiRegex.hasMatch(s.amphoe(amp)), isFalse, reason: '$lang amphoe $amp');
        }
      }
    });

    testWidgets('SettingsScreen displays Guide card & 5-level alert guide in Dark Mode & switches languages', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AlertProvider(
        waterService: ThaiWaterService(preferences: prefs),
        localStorage: LocalStore(prefs),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            themeMode: ThemeMode.dark,
            darkTheme: ThemeData.dark(useMaterial3: true),
            home: const SettingsScreen(),
          ),
        ),
      );

      expect(find.text('คู่มือใช้งานและคู่มืออพยพ'), findsOneWidget);
      expect(find.text('คำอธิบายระดับการแจ้งเตือน (1–5)'), findsOneWidget);
      expect(find.text('ปกติ'), findsOneWidget);

      provider.updateSettings(provider.settings.copyWith(languageCode: 'en'));
      await tester.pump();
      expect(find.text('App & Evacuation Guide'), findsOneWidget);
      expect(find.text('Alert Level Guide (Levels 1–5)'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);

      provider.updateSettings(provider.settings.copyWith(languageCode: 'ms'));
      await tester.pump();
      expect(find.text('Panduan Tahap Amaran (Tahap 1–5)'), findsOneWidget);
    });

    test('User pinned location persists locally and is completely erased by PDPA deleteAllUserData', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStore(prefs);
      final provider = AlertProvider(
        waterService: ThaiWaterService(preferences: prefs),
        localStorage: store,
      );

      await provider.setPinnedLocation(6.5415, 101.2812, isGps: false);
      expect(provider.userPinAssessment, isNotNull);
      expect(store.loadPinnedLocation(), isNotNull);

      await provider.deleteAllUserData();
      expect(provider.userPinAssessment, isNull);
      expect(store.loadPinnedLocation(), isNull);
      expect(prefs.getString(AppConfig.pinnedLocationPrefsKey), isNull);
    });

    test('QA regressions: X.77 RID8 evaluate override, NaN fail-closed, Dark Mode & watch contrast', () {
      const x77 = Station(
        id: 77,
        code: 'X.77',
        nameTh: 'บ้านหัวสะพาน',
        lat: 6.1525,
        lng: 101.0809,
        waterLevelMsl: 39.75,
        waterLevelMslPrev: 39.65,
        leftBank: 40.30,
        amphoeTh: 'ธารโต',
      );
      final alerts = engine.evaluate(stations: const [x77]);
      expect(alerts, isNotEmpty);
      expect(alerts.first.stationCode, 'X.77');
      expect(alerts.first.level, RiskLevel.danger);

      expect(AlertLevel.watch.onSolidColor, const Color(0xFF111827));
      expect(RiskLevel.watch.onColor, const Color(0xFF111827));
      expect(WaterTrend.steady.colorFor(Brightness.dark), isNot(WaterTrend.steady.color));

      final nanStation = Station.fromThaiWaterJson({
        'id': 999,
        'waterlevel_msl': 'NaN',
        'waterlevel_msl_previous': 'Infinity',
        'station': {
          'tele_station_oldcode': 'X.40A',
          'tele_station_name': {'th': 'บ้านท่าสาป'},
          'left_bank': double.nan,
        },
      });
      expect(nanStation.waterLevelMsl, isNull);
      expect(nanStation.waterLevelMslPrev, isNull);
      expect(nanStation.leftBank, isNull);
    });
  });
}
