import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/main_screen.dart';
import 'screens/delivery/active_delivery_screen.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  // Request location permission early
  try {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  } catch (_) {}

  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'FoodDash Delivery',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(backgroundColor: Colors.white, elevation: 0, foregroundColor: Colors.black87),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<void> _autoLoginFuture;

  @override
  void initState() {
    super.initState();
    _autoLoginFuture = Provider.of<AuthProvider>(context, listen: false).tryAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _autoLoginFuture,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            ),
          );
        }
        return Consumer<AuthProvider>(
          builder: (ctx, auth, _) => auth.isLoggedIn
              ? const _ActiveOrderChecker()
              : const LoginScreen(),
        );
      },
    );
  }
}

/// Checks for an active delivery on startup.
/// If one exists, go directly to ActiveDeliveryScreen.
/// Otherwise show MainScreen.
class _ActiveOrderChecker extends StatefulWidget {
  const _ActiveOrderChecker();
  @override
  State<_ActiveOrderChecker> createState() => _ActiveOrderCheckerState();
}

class _ActiveOrderCheckerState extends State<_ActiveOrderChecker> {
  bool _checking = true;
  int? _activeOrderId;

  @override
  void initState() {
    super.initState();
    _checkActiveOrder();
  }

  Future<void> _checkActiveOrder() async {
    try {
      final res = await ApiService.getActiveDelivery();
      if (res.data['success'] == true && res.data['data'] != null) {
        final data = res.data['data'];
        _activeOrderId = int.tryParse(data['id']?.toString() ?? '');
      }
    } catch (_) {}
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
      );
    }

    if (_activeOrderId != null) {
      // Directly show active delivery screen
      return ActiveDeliveryScreen(orderId: _activeOrderId!);
    }

    return const MainScreen();
  }
}
