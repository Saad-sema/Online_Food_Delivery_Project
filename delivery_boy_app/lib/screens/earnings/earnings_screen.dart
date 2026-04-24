import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _period = 'today'; // 'today', 'week', 'month'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getEarnings(period: _period);
      if (res.data['success'] == true) {
        setState(() {
          _data = res.data['data'];
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
        title: const Text('My Earnings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        color: const Color(0xFF4F46E5),
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Period Selector
                  _buildPeriodSelector(),
                  const SizedBox(height: 24),

                  // Main Earnings Card
                  _buildMainCard(),
                  const SizedBox(height: 20),

                  // Stats Grid
                  Row(children: [
                    _statCard('Deliveries', '${_data?['total_deliveries'] ?? 0}', Icons.directions_bike_rounded, Colors.blue),
                    const SizedBox(width: 15),
                    _statCard('Avg/Order', '₹${double.tryParse(_data?['avg_per_delivery']?.toString() ?? '0')?.toStringAsFixed(0)}', Icons.analytics_rounded, Colors.purple),
                  ]),
                  const SizedBox(height: 15),
                  Row(children: [
                    _statCard('Base Pay', '₹${double.tryParse(_data?['base_earnings']?.toString() ?? '0')?.toStringAsFixed(0)}', Icons.payment_rounded, Colors.green),
                    const SizedBox(width: 15),
                    _statCard('Tips', '₹${double.tryParse(_data?['total_tips']?.toString() ?? '0')?.toStringAsFixed(0)}', Icons.volunteer_activism_rounded, Colors.orange),
                  ]),

                  const SizedBox(height: 30),

                  // Recent Earnings List
                  const Text('Recent Deliveries', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 15),
                  if ((_data?['recent_orders'] as List?)?.isEmpty ?? true)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('No deliveries found for this period', style: TextStyle(color: Colors.grey)),
                    ))
                  else
                    ...(_data!['recent_orders'] as List).map((o) => _orderEarnCard(o)),

                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        for (final p in ['today', 'week', 'month'])
          Expanded(child: GestureDetector(
            onTap: () { setState(() => _period = p); _load(); },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _period == p ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                boxShadow: _period == p ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
              ),
              child: Center(child: Text(p[0].toUpperCase() + p.substring(1),
                  style: TextStyle(fontWeight: FontWeight.bold, color: _period == p ? const Color(0xFF4F46E5) : Colors.grey.shade600, fontSize: 14))),
            ),
          )),
      ]),
    );
  }

  Widget _buildMainCard() {
    final total = double.tryParse(_data?['total_earnings']?.toString() ?? '0')?.toStringAsFixed(0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF6366F1)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF4F46E5).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(children: [
        const Text('Total Payout', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        Text('₹$total', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 48)),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Text('${_period.toUpperCase()} PERFORMANCE', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _orderEarnCard(Map<String, dynamic> o) {
    final base = double.tryParse(o['boy_base_charge']?.toString() ?? '0')?.toStringAsFixed(0);
    final tip = double.tryParse(o['tip_amount']?.toString() ?? '0')?.toStringAsFixed(0);
    final total = (double.tryParse(o['boy_base_charge']?.toString() ?? '0')! + double.tryParse(o['tip_amount']?.toString() ?? '0')!).toStringAsFixed(0);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade100)),
      child: Row(children: [
        Container(
          height: 50, width: 50,
          decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF4F46E5)),
        ),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Order #${o['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text(o['delivered_at'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹$total', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF4F46E5))),
          Text('Base: ₹$base + Tip: ₹$tip', style: TextStyle(color: Colors.grey.shade400, fontSize: 10)),
        ]),
      ]),
    );
  }
}
