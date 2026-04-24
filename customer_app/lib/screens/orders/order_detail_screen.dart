import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../chat/chat_screen.dart';
import 'tracking_screen.dart';
import 'review_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    try {
      final res = await ApiService.getOrder(widget.orderId);
      if (res.data['success']) {
        setState(() {
          _order = res.data['data'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load order details')),
        );
      }
    }
  }

  Future<void> _cancelOrder() async {
    try {
      final res = await ApiService.cancelOrder(widget.orderId);
      if (res.data['success']) {
        _loadOrder();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order cancelled successfully')),
          );
        }
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel order')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: Text('Order not found')),
      );
    }

    final items = _order!['items'] as List;
    final status = _order!['order_status'] ?? 'pending';
    // Allow cancellation until the order is picked up (out_for_delivery)
    final canCancel = ['pending', 'accepted', 'assigned', 'reached_restaurant'].contains(status);
    final isPickedUp = ['out_for_delivery', 'delivered'].contains(status);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${_order!['id']}'),
        actions: [
          if (canCancel)
            TextButton(
              onPressed: _cancelOrder,
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(status),
            const SizedBox(height: 20),
            _buildSectionTitle('Restaurant'),
            Text(_order!['restaurant_name'] ?? '',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(_order!['restaurant_address'] ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            _buildSectionTitle('Items'),
            ...items.map((it) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text('${it['quantity']}x ',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(child: Text(it['name'])),
                      Text('₹${it['price']}'),
                    ],
                  ),
                )),
            const Divider(height: 32),
            _buildBillDetail('Subtotal', _order!['subtotal']),
            _buildBillDetail('Delivery Fee', _order!['delivery_charge']),
            _buildBillDetail('Tax', _order!['tax_amount']),
            if (double.parse(_order!['coupon_discount'].toString()) > 0)
              _buildBillDetail('Discount', '-₹${_order!['coupon_discount']}',
                  isDiscount: true),
            const Divider(),
            _buildBillDetail('Total', '₹${_order!['total_amount']}', isBold: true),
            // Special Instructions
            if ((_order!['special_notes'] ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionTitle('Special Instructions'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.edit_note_rounded, color: Color(0xFFFF6B35), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_order!['special_notes'],
                        style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            if (_order!['delivery_otp'] != null && status != 'delivered' && status != 'cancelled' && status != 'rejected')
               Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.vpn_key, color: Colors.orange),
                    const SizedBox(width: 12),
                    Text(
                      'Delivery OTP: ${_order!['delivery_otp']}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            if (['pending', 'accepted', 'assigned', 'reached_restaurant', 'out_for_delivery'].contains(status)) ...[
               SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => TrackingScreen(orderId: widget.orderId)),
                  ),
                  icon: const Icon(Icons.map),
                  label: const Text('Track Order'),
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Show non-cancellable message after pickup
            if (isPickedUp && status != 'delivered')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text('Cannot cancel — order has been picked up',
                      style: TextStyle(color: Colors.red, fontSize: 13))),
                ]),
              ),
            if (status != 'delivered' && status != 'cancelled' && _order!['delivery_boy_id'] != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ChatScreen(
                              orderId: widget.orderId,
                              recipientName: _order!['delivery_boy_name'] ?? 'Delivery Boy',
                            )),
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text('Chat with Delivery Boy'),
                ),
              ),
            // Refund Banner – shown when order is rejected/cancelled and was paid online
            if ((status == 'rejected' || status == 'cancelled') && _order!['payment_status'] == 'refunded') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300, width: 1.5),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.account_balance_wallet_rounded, color: Colors.green.shade700, size: 22),
                    const SizedBox(width: 10),
                    Text('Refund Initiated',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green.shade800)),
                  ]),
                  const SizedBox(height: 8),
                  Text('₹${_order!["total_amount"]} will be refunded to your original payment method.',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Refunds typically take 3–5 business days.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ]),
              ),
              const SizedBox(height: 16),
            ],
            if (status == 'delivered') ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final rated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReviewScreen(
                          orderId: widget.orderId,
                          restaurantName: _order!['restaurant_name'] ?? 'Restaurant',
                        ),
                      ),
                    );
                    if (rated == true) _loadOrder();
                  },
                  icon: const Icon(Icons.star_rate_rounded),
                  label: const Text('Rate & Review Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        icon = Icons.timer;
        break;
      case 'assigned':
        color = Colors.blue;
        icon = Icons.local_shipping;
        break;
      case 'reached_restaurant':
        color = Colors.orange;
        icon = Icons.store;
        break;
      case 'accepted':
        color = Colors.blue;
        icon = Icons.check_circle;
        break;
      case 'out_for_delivery':
        color = Colors.indigo;
        icon = Icons.delivery_dining;
        break;
      case 'delivered':
        color = Colors.green;
        icon = Icons.home;
        break;
      case 'cancelled':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            status.replaceAll('_', ' ').toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  Widget _buildBillDetail(String label, dynamic value,
      {bool isBold = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: isBold ? 16 : 14)),
          Text(value.toString(),
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: isBold ? 16 : 14,
                  color: isDiscount ? Colors.green : Colors.black)),
        ],
      ),
    );
  }
}
