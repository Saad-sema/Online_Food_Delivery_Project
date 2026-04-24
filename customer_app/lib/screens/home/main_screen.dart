import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  final _ordersKey = GlobalKey<OrdersScreenState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeScreen(),
      OrdersScreen(key: _ordersKey),
      const ProfileScreen(),
    ];
  }

  void _onTabSelected(int i) {
    setState(() => _index = i);
    // Reload orders whenever Orders tab is tapped
    if (i == 1) {
      _ordersKey.currentState?.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onTabSelected,
          height: 68,
          elevation: 0,
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFFFF6B35).withOpacity(0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: Color(0xFFFF6B35)), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded, color: Color(0xFFFF6B35)), label: 'Orders'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded, color: Color(0xFFFF6B35)), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
