import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.getOrder(widget.orderId);
      if (res.data['success'] == true) {
        setState(() => _order = res.data['data']);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _handleAction(Future<dynamic> Function() action) async {
    setState(() => _acting = true);
    try {
      final res = await action();
      if (res.data['success'] == true) {
        await _load();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res.data['message'] ?? 'Action failed'), backgroundColor: Colors.red));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Network error'), backgroundColor: Colors.red));
      }
    }
    setState(() => _acting = false);
  }

  @override
  Widget build(BuildContext context) {
    final status = _order?['order_status'] ?? '';
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
          title: Text('Order #${widget.orderId}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
          : _order == null
              ? const Center(child: Text('Order not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [BoxShadow(color: const Color(0xFF059669).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(children: [
                        const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 32),
                        const SizedBox(height: 8),
                        Text(status.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // Delivery Info
                    _card('Delivery Details', [
                      _row(Icons.person_outline, _order!['customer_name'] ?? 'Unknown Customer'),
                      _row(Icons.phone_outlined, _order!['customer_phone'] ?? 'No Phone'),
                      _row(Icons.location_on_outlined, _order!['delivery_address'] ?? 'No Address'),
                      if (_order!['flat_no'] != null && _order!['flat_no'].toString().isNotEmpty)
                        _row(Icons.home_outlined, 'Flat/No: ${_order!['flat_no']}'),
                      if (_order!['landmark'] != null && _order!['landmark'].toString().isNotEmpty)
                        _row(Icons.flag_outlined, 'Landmark: ${_order!['landmark']}'),
                    ]),
                    const SizedBox(height: 12),

                    // Order Items
                    _card('Ordered Items', [
                      ...List<dynamic>.from(_order!['items'] ?? []).map((it) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                child: Text('${it['quantity']}x', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669), fontSize: 12)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(it['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                              Text('₹${double.tryParse(it['price']?.toString() ?? '0')?.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]),
                          )),
                      const Divider(height: 24),
                      _summaryRow('Subtotal', '₹${double.tryParse(_order!['subtotal']?.toString() ?? '0')?.toStringAsFixed(0)}'),
                      if (double.tryParse(_order!['coupon_discount']?.toString() ?? '0')! > 0)
                        _summaryRow('Discount', '-₹${double.tryParse(_order!['coupon_discount']?.toString() ?? '0')?.toStringAsFixed(0)}', color: Colors.green),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('₹${double.tryParse(_order!['total_amount']?.toString() ?? '0')?.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF059669))),
                      ]),
                    ]),

                    // Special Instructions
                    if ((_order!['special_notes'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade300, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.edit_note_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 8),
                            const Text('Special Instructions',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                          ]),
                          const Divider(height: 16),
                          Text(_order!['special_notes'],
                              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
                        ]),
                      ),
                    ],

                    const SizedBox(height: 30),

                    // ── ACTION BUTTONS ────────────────────────────────
                    _buildActions(status),
                    
                    const SizedBox(height: 40),
                  ],
                ),
    );
  }

  Widget _buildActions(String status) {
    if (_acting) return const Center(child: CircularProgressIndicator(color: Color(0xFF059669)));

    switch (status) {
      case 'pending':
        return Row(children: [
          Expanded(
            child: SizedBox(height: 52, child: OutlinedButton(
              onPressed: () => _handleAction(() => ApiService.rejectOrder(widget.orderId)),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Reject Order', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(height: 52, child: ElevatedButton(
              onPressed: () => _handleAction(() => ApiService.acceptOrder(widget.orderId)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Accept Order', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ),
        ]);

      case 'accepted':
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () => _handleAction(() => ApiService.markPreparing(widget.orderId)),
            icon: const Icon(Icons.restaurant_rounded),
            label: const Text('Start Preparing Food', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        );

      case 'preparing':
        return SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: () => _handleAction(() => ApiService.markReady(widget.orderId)),
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Food is Ready for Pickup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        );

      default:
        return const Center(child: Text('No further actions required', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)));
    }
  }

  Widget _card(String title, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
          const Divider(height: 20),
          ...children,
        ]),
      );

  Widget _row(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [Icon(icon, size: 20, color: const Color(0xFF059669)), const SizedBox(width: 12), Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade800)))]),
      );

  Widget _summaryRow(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: const TextStyle(color: Colors.grey)), Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color))]),
      );
}
