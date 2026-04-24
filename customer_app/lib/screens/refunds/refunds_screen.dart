import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:intl/intl.dart';

class RefundsScreen extends StatefulWidget {
  const RefundsScreen({super.key});

  @override
  State<RefundsScreen> createState() => _RefundsScreenState();
}

class _RefundsScreenState extends State<RefundsScreen> {
  List<dynamic> _refunds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.listRefunds();
      if (res.data['success'] == true) {
        setState(() {
          _refunds = res.data['data'];
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('My Refunds', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : _refunds.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _refunds.length,
                  itemBuilder: (context, index) {
                    final r = _refunds[index];
                    return _buildRefundCard(r);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No refunds found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Refunds from cancelled or rejected orders will appear here.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRefundCard(Map<String, dynamic> r) {
    final date = DateTime.parse(r['created_at']);
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order #${r['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Text('Refunded', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(r['restaurant_name'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Amount to be Refunded', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text('₹${r['total_amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFFF6B35))),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Order Date', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(formattedDate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Refund will be credited back to your original payment method in 3-5 business days.',
                    style: TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
