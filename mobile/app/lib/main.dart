import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yala_flood_app/config/app_config.dart';
import 'package:yala_flood_app/screens/alerts_screen.dart';
import 'package:yala_flood_app/screens/app_shell.dart';
import 'package:yala_flood_app/screens/settings_screen.dart';
import 'package:yala_flood_app/screens/shelters_screen.dart';
import 'package:yala_flood_app/screens/sos_screen.dart';
import 'package:yala_flood_app/screens/station_detail_screen.dart';
import 'package:yala_flood_app/services/deep_link_service.dart';
import 'package:yala_flood_app/services/local_store.dart';
import 'package:yala_flood_app/services/notification_service.dart';
import 'package:yala_flood_app/services/snapshot_service.dart';
import 'package:yala_flood_app/services/thai_water_service.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// ใช้ deep link เปิดหน้าต่างต่าง ๆ จากภายนอก เช่น yalaflood://station/PAT002
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();
  final waterService = ThaiWaterService(preferences: preferences);
  final provider = AlertProvider(
    waterService: waterService,
    localStorage: LocalStore(preferences),
    snapshotService: SnapshotService(preferences: preferences),
  );

  // แจ้งเตือนในเครื่อง + Push รายอำเภอ (Push ข้ามได้อัตโนมัติถ้ายังไม่วาง GoogleService-Info.plist)
  final savedSettings = LocalStore(preferences).loadSettings();
  await NotificationService.instance.initialize();
  await NotificationService.instance.initializePush(
    pushEnabled: savedSettings.pushEnabled,
    selectedAmphoeTh: savedSettings.selectedAmphoeTh,
  );

  runApp(YalaFloodApp(provider: provider));
}

class YalaFloodApp extends StatefulWidget {
  const YalaFloodApp({super.key, required this.provider});

  final AlertProvider provider;

  @override
  State<YalaFloodApp> createState() => _YalaFloodAppState();
}

class _YalaFloodAppState extends State<YalaFloodApp> {
  final DeepLinkService _deepLinkService = DeepLinkService();

  @override
  void initState() {
    super.initState();
    // โหลดแคชในเครื่องก่อน แล้วค่อยดึงค่าใหม่จากเน็ต
    widget.provider.hydrate();
    _deepLinkService.start(_handleDeepLink);
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  void _handleDeepLink(DeepLinkTarget target) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamed(target.route, arguments: target.argument);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AlertProvider>.value(
      value: widget.provider,
      child: Consumer<AlertProvider>(
        builder: (context, provider, _) {
          final settings = provider.settings;
          final locale = switch (settings.languageCode) {
            'en' => const Locale('en', 'US'),
            'zh' => const Locale('zh'),
            'ms' => const Locale('ms'),
            _ => const Locale('th', 'TH'),
          };
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(AppConfig.colorPrimary),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(AppConfig.colorPrimary),
                brightness: Brightness.dark,
              ),
            ),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [
              Locale('th', 'TH'),
              Locale('en', 'US'),
              Locale('zh'),
              Locale('ms'),
            ],
            locale: locale,
            builder: (context, child) {
              if (!settings.largeTextMode || child == null) {
                return child ?? const SizedBox.shrink();
              }
              final mq = MediaQuery.of(context);
              final currentScale = mq.textScaler.scale(1.0);
              final boosted = currentScale < 1.25 ? 1.25 : currentScale;
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(boosted)),
                child: child,
              );
            },
            initialRoute: '/',
            onGenerateRoute: _generateRoute,
          );
        },
      ),
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return _materialRoute(const AppShell(), settings);
      case '/station':
        return _materialRoute(
          StationDetailScreen(stationCode: settings.arguments as String? ?? ''),
          settings,
        );
      case '/alerts':
        return _materialRoute(const AlertsScreen(), settings);
      case '/sos':
        return _materialRoute(const SosScreen(), settings);
      case '/shelters':
        return _materialRoute(const SheltersScreen(), settings);
      case '/settings':
        return _materialRoute(const SettingsScreen(), settings);
      default:
        return _materialRoute(const AppShell(), settings);
    }
  }

  MaterialPageRoute<void> _materialRoute(Widget child, RouteSettings settings) {
    return MaterialPageRoute<void>(builder: (_) => child, settings: settings);
  }
}
