import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:yala_flood_app/screens/alerts_screen.dart';
import 'package:yala_flood_app/screens/home_screen.dart';
import 'package:yala_flood_app/screens/settings_screen.dart';
import 'package:yala_flood_app/screens/shelters_screen.dart';
import 'package:yala_flood_app/screens/sos_screen.dart';
import 'package:yala_flood_app/state/alert_provider.dart';

/// กรอบแอพหลัก: แถบนำทางด้านล่าง 5 หน้า (รองรับ 4 ภาษา + ใช้คำว่า "ศูนย์พักพิง")
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    AlertsScreen(),
    SosScreen(),
    SheltersScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final strings = provider.strings;
    final unread = provider.unreadCount;

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: strings.get('tab_home'),
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.analytics_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.analytics),
            ),
            label: strings.get('tab_alerts'),
          ),
          NavigationDestination(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFB71C1C),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sos, color: Colors.white, size: 20),
            ),
            label: strings.get('tab_sos'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.home_work_outlined),
            selectedIcon: const Icon(Icons.home_work),
            label: strings.get('tab_shelters'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: strings.get('tab_settings'),
          ),
        ],
      ),
    );
  }
}
