import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import 'order_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _orders = [];
  bool _loading = true;
  String _filter = 'pending';

  // Operator status: 'online' | 'busy' | 'closed'
  String _operatorStatus = 'online';
  bool _statusSaving = false;

  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
    _tabCtrl.addListener(() {
      final filters = ['pending', 'accepted', 'preparing', 'out_for_delivery', 'delivered'];
      if (!_tabCtrl.indexIsChanging) {
        _filter = filters[_tabCtrl.index];
        _load();
      }
    });
    _loadProfile();
    _load();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiService.getProfile();
      if (res.data['success'] == true) {
        final data = res.data['data'];
        if (mounted) setState(() {
          _operatorStatus = data['operator_status'] ?? 'online';
        });
      }
    } catch (_) {}
  }

  void _startLocationTracking() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
          try {
            final pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high,
                timeLimit: const Duration(seconds: 3));
            await ApiService.updateLocation(pos.latitude, pos.longitude);
          } catch (_) {}
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getOrders(status: _filter);
      if (res.data['success'] == true) _orders = res.data['data'] ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _setStatus(String status) async {
    setState(() => _statusSaving = true);
    try {
      final res = await ApiService.updateOperatorStatus(status);
      if (res.data['success'] == true) {
        setState(() => _operatorStatus = status);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? 'Failed'), backgroundColor: Colors.red));
      }
    } catch (_) {}
    setState(() => _statusSaving = false);
  }

  Color _statusBgColor() => switch (_operatorStatus) {
    'online' => Colors.green.shade50,
    'busy'   => Colors.orange.shade50,
    _        => Colors.red.shade50,
  };

  Color _statusBorderColor() => switch (_operatorStatus) {
    'online' => Colors.green.shade300,
    'busy'   => Colors.orange.shade300,
    _        => Colors.red.shade300,
  };

  Color _statusTextColor() => switch (_operatorStatus) {
    'online' => Colors.green.shade800,
    'busy'   => Colors.orange.shade800,
    _        => Colors.red.shade800,
  };

  IconData _statusIcon() => switch (_operatorStatus) {
    'online' => Icons.check_circle_rounded,
    'busy'   => Icons.hourglass_top_rounded,
    _        => Icons.cancel_rounded,
  };

  Color _orderStatusColor(String s) => switch (s) {
    'pending'        => Colors.orange,
    'accepted'       => Colors.blue,
    'preparing'      => Colors.purple,
    'ready_for_pickup' => Colors.teal,
    'out_for_delivery' => Colors.indigo,
    'delivered'      => Colors.green,
    'cancelled'      => Colors.red,
    _                => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Orders', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: const Color(0xFF059669),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF059669),
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Accepted'),
            Tab(text: 'Preparing'),
            Tab(text: 'In Delivery'),
            Tab(text: 'Delivered'),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF059669),
        onRefresh: _load,
        child: Column(
          children: [
            // ── OPERATOR STATUS BANNER ──────────────────────────
            _operatorStatusBanner(),

            // ── ORDERS LIST ─────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
                  : _orders.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No ${_filter.replaceAll("_", " ")} orders',
                              style: const TextStyle(color: Colors.grey, fontSize: 16)),
                        ]))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _orders.length,
                          itemBuilder: (_, i) => _orderCard(_orders[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _operatorStatusBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _statusBgColor(),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusBorderColor()),
      ),
      child: Row(children: [
        Icon(_statusIcon(), color: _statusTextColor(), size: 24),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Restaurant Status', style: TextStyle(fontSize: 12, color: Colors.grey)),
          Text(_operatorStatus.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _statusTextColor())),
        ]),
        const Spacer(),
        if (_statusSaving)
          const SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)))
        else
          PopupMenuButton<String>(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF059669),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Change', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'online', child: Row(children: [
                Icon(Icons.check_circle, color: Colors.green, size: 18),
                SizedBox(width: 8),
                Text('Online – Accept orders'),
              ])),
              const PopupMenuItem(value: 'busy', child: Row(children: [
                Icon(Icons.hourglass_top, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Text('Busy – Limited orders'),
              ])),
              const PopupMenuItem(value: 'closed', child: Row(children: [
                Icon(Icons.cancel, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('Closed – Stop orders'),
              ])),
            ],
            onSelected: _setStatus,
          ),
      ]),
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final status = o['order_status'] ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: int.parse(o['id'].toString()))))
          .then((_) => _load()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('#${o['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _orderStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(color: _orderStatusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(o['customer_name'] ?? 'Customer', style: TextStyle(color: Colors.grey.shade700)),
          const Divider(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('₹${double.tryParse(o['total_amount']?.toString() ?? '0')?.toStringAsFixed(0)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF059669))),
            Text(o['payment_method']?.toString().toUpperCase() ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ]),
        ]),
      ),
    );
  }
}
