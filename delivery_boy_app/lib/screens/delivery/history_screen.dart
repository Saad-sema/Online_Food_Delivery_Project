import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _deliveries = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getHistory();
      if (res.data['success'] == true) _deliveries = res.data['data'] ?? [];
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Delivery History', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
      body: RefreshIndicator(
        color: const Color(0xFF4F46E5),
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
            : _deliveries.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.history, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No deliveries yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _deliveries.length,
                    itemBuilder: (_, i) {
                      final d = _deliveries[i];
                      final status = d['order_status'] ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: status == 'delivered' ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Icon(status == 'delivered' ? Icons.check_circle : Icons.cancel, color: status == 'delivered' ? Colors.green : Colors.red, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Order #${d['order_id'] ?? d['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(d['restaurant_name'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                            Text(d['delivered_at'] ?? d['created_at'] ?? '', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                          ])),
                          Text('₹${double.tryParse(d['delivery_fee']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4F46E5))),
                        ]),
                      );
                    },
                  ),
      ),
    );
  }
}
