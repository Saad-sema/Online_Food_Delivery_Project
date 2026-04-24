import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'order_detail_screen.dart';
import 'tracking_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => OrdersScreenState();
}

class OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Public method so MainScreen can trigger reload via GlobalKey
  void load() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.listOrders();
      if (res.data['success'] == true) {
        _orders = res.data['data'] ?? [];
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': case 'assigned': return Colors.blue;
      case 'out_for_delivery': return Colors.indigo;
      case 'delivered': return Colors.green;
      case 'cancelled': case 'rejected': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFF6B35),
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
            : _orders.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long_outlined, size: 70, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('No orders yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 6),
                    const Text('Your order history will appear here', style: TextStyle(color: Colors.grey)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    itemBuilder: (_, i) => _orderCard(_orders[i]),
                  ),
      ),
    );
  }

  Widget _orderCard(Map<String, dynamic> o) {
    final status = o['order_status'] ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: int.parse(o['id'].toString())))).then((_) => _load()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.restaurant, color: Color(0xFFFF6B35), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o['restaurant_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Order #${o['id']}', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('₹${double.tryParse(o['total_amount']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF6B35))),
                if (['pending', 'accepted', 'assigned', 'reached_restaurant', 'out_for_delivery'].contains(status))
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrackingScreen(orderId: int.parse(o['id'].toString())))),
                    icon: const Icon(Icons.map, size: 14),
                    label: const Text('Track', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6B35).withOpacity(0.1),
                      foregroundColor: const Color(0xFFFF6B35),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  )
                else
                  Row(children: [
                    Text(o['payment_method']?.toString().toUpperCase() ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
