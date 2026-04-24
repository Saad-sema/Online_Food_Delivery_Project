import 'package:flutter/material.dart';
import '../orders/dashboard_screen.dart';
import '../menu/menu_screen.dart';
import '../earnings/earnings_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  final List<Widget> _pages = const [DashboardScreen(), MenuScreen(), EarningsScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 68,
        indicatorColor: const Color(0xFF059669).withOpacity(0.12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard, color: Color(0xFF059669)), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu, color: Color(0xFF059669)), label: 'Menu'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart, color: Color(0xFF059669)), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: Color(0xFF059669)), label: 'Profile'),
        ],
      ),
    );
  }
}
