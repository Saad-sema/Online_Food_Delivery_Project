import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import 'active_delivery_screen.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  List<dynamic> _requests = [];
  bool _loading = true;
  bool _available = true;
  Position? _position;
  int? _activeOrderId;

  Timer? _pollTimer;      // Poll for new requests every 5s
  Timer? _locationTimer;  // Send location every 5s

  @override
  void initState() {
    super.initState();
    _initLocation();
    // Poll every 5 seconds for new requests
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
    // Location update every 5 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sendLocation());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        _position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      }
    } catch (_) {}
    _load();
  }

  Future<void> _sendLocation() async {
    if (_position == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 3));
      if (mounted) setState(() => _position = pos);
      await ApiService.updateLocation(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final activeRes = await ApiService.getActiveDelivery();
      if (activeRes.data['success'] == true && activeRes.data['data'] != null) {
        _activeOrderId = int.tryParse(activeRes.data['data']['id']?.toString() ?? '');
      } else {
        _activeOrderId = null;
      }

      if (_activeOrderId == null) {
        final res = await ApiService.getRequests(
          lat: _position?.latitude,
          lng: _position?.longitude,
        );
        if (res.data['success'] == true) {
          final newReqs = res.data['data'] as List? ?? [];
          if (mounted) setState(() => _requests = newReqs);
        }
      } else {
        if (mounted) setState(() => _requests = []);
      }
    } catch (_) {}
    if (!silent && mounted) setState(() => _loading = false);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleAvailability() async {
    final newStatus = _available ? 'unavailable' : 'available';
    try {
      await ApiService.updateStatus(newStatus);
      setState(() => _available = !_available);
    } catch (_) {}
  }

  Future<void> _accept(int requestId, int orderId) async {
    try {
      final res = await ApiService.acceptRequest(requestId);
      if (res.data['success'] == true && mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(orderId: orderId)));
      } else {
        final msg = res.data['message'] ?? 'Order already taken';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.red));
        }
        _load();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request failed'), backgroundColor: Colors.red));
    }
  }

  Future<void> _reject(int requestId) async {
    try {
      await ApiService.rejectRequest(requestId);
      _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Delivery Requests', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(children: [
              Text(_available ? 'Online' : 'Offline',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold,
                      color: _available ? Colors.green : Colors.red)),
              const SizedBox(width: 6),
              Switch(
                value: _available,
                onChanged: _activeOrderId != null ? null : (_) => _toggleAvailability(),
                activeColor: Colors.green,
              ),
            ]),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFF4F46E5),
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
            : !_available
                ? _emptyState(Icons.power_off, 'You are offline', 'Go online to receive delivery requests')
                : _activeOrderId != null
                    ? _activeDeliveryState()
                    : _requests.isEmpty
                        ? _emptyState(Icons.local_shipping_outlined, 'No requests right now',
                            'New delivery requests will appear here automatically')
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _requests.length,
                            itemBuilder: (_, i) => _requestCard(_requests[i]),
                          ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 72, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: Colors.grey.shade400), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _activeDeliveryState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.delivery_dining_rounded, size: 72, color: Color(0xFF4F46E5)),
        const SizedBox(height: 12),
        const Text('Active Delivery in Progress',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          child: Text('Complete your current order to view new requests.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => ActiveDeliveryScreen(orderId: _activeOrderId!))),
          icon: const Icon(Icons.navigation_rounded),
          label: const Text('Go to Delivery'),
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        ),
      ]),
    );
  }

  Widget _requestCard(Map<String, dynamic> r) {
    final reqId = int.parse(r['id'].toString());
    final orderId = int.parse(r['order_id'].toString());
    final distanceKm = double.tryParse(r['distance_km']?.toString() ?? '');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF4F46E5).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.receipt_long, color: Color(0xFF4F46E5), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Order #$orderId', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(r['restaurant_name'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ])),
        ]),

        const Divider(height: 20),

        // Distance badge
        if (distanceKm != null && distanceKm < 9999)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.near_me_rounded, size: 14, color: Colors.green.shade700),
              const SizedBox(width: 4),
              Text('${distanceKm.toStringAsFixed(1)} km from restaurant',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
            ]),
          ),

        // Earnings info
        Row(children: [
          const Icon(Icons.currency_rupee_rounded, size: 16, color: Color(0xFF4F46E5)),
          Text('₹${double.tryParse(r['delivery_fee']?.toString() ?? r['total_amount']?.toString() ?? '40')?.toStringAsFixed(0) ?? '40'} earnings',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
          const SizedBox(width: 12),
          const Icon(Icons.location_on_rounded, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(r['customer_address'] ?? r['delivery_address'] ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ]),

        // From restaurant address
        Row(children: [
          const Icon(Icons.restaurant_rounded, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: Text(r['restaurant_address'] ?? '',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ]),

        const SizedBox(height: 14),

        // Action buttons
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _reject(reqId),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('✗ Reject', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _accept(reqId, orderId),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('✓ Accept', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ]),
    );
  }
}
