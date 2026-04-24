import 'package:flutter/material.dart';
import '../delivery/requests_screen.dart';
import '../delivery/history_screen.dart';
import '../earnings/earnings_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  final _pages = const [RequestsScreen(), HistoryScreen(), EarningsScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        height: 68,
        indicatorColor: const Color(0xFF4F46E5).withOpacity(0.12),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping, color: Color(0xFF4F46E5)), label: 'Requests'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history, color: Color(0xFF4F46E5)), label: 'History'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart, color: Color(0xFF4F46E5)), label: 'Earnings'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person, color: Color(0xFF4F46E5)), label: 'Profile'),
        ],
      ),
    );
  }
}
