import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../services/api_service.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _period = 'week';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getEarnings(period: _period);
      if (res.data['success'] == true) _data = res.data['data'];
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Earnings', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
          : RefreshIndicator(
              color: const Color(0xFF059669),
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                // Period selector
                Row(children: [
                  for (final p in ['today', 'week', 'month'])
                    Expanded(
                      child: GestureDetector(
                        onTap: () { _period = p; _load(); },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _period == p ? const Color(0xFF059669) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _period == p ? const Color(0xFF059669) : Colors.grey.shade300),
                          ),
                          child: Center(child: Text(p[0].toUpperCase() + p.substring(1), style: TextStyle(fontWeight: FontWeight.bold, color: _period == p ? Colors.white : Colors.grey.shade700, fontSize: 13))),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 20),

                // Revenue Graph
                Container(
                  height: 200,
                  padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _getSpots(),
                          isCurved: true,
                          color: const Color(0xFF059669),
                          barWidth: 4,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(show: true, color: const Color(0xFF059669).withOpacity(0.1)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Stats cards
                Row(children: [
                  _statCard('Total Orders', '${_data?['total_orders'] ?? 0}', Icons.receipt_long, Colors.blue),
                  const SizedBox(width: 12),
                  _statCard('Revenue', '₹${double.tryParse(_data?['total_revenue']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'}', Icons.currency_rupee, const Color(0xFF059669)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  _statCard('Avg Order', '₹${double.tryParse(_data?['avg_order']?.toString() ?? '0')?.toStringAsFixed(0) ?? '0'}', Icons.trending_up, Colors.orange),
                  const SizedBox(width: 12),
                  _statCard('Completed', '${_data?['completed_orders'] ?? 0}', Icons.check_circle, Colors.green),
                ]),
                const SizedBox(height: 20),

                // Recent earnings
                const Text('Recent Orders', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                ...List<Map<String, dynamic>>.from(_data?['recent'] ?? []).map((o) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.receipt, color: Color(0xFF059669), size: 18)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('#${o['id']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(o['created_at']?.toString() ?? '', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ])),
                    Text('₹${double.tryParse(o['total_amount']?.toString() ?? '0')?.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                  ]),
                )),
              ]),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ]),
      ),
    );
  }

  List<FlSpot> _getSpots() {
    final chart = List<Map<String, dynamic>>.from(_data?['chart'] ?? []);
    if (chart.isEmpty) return [const FlSpot(0, 0)];
    return List.generate(chart.length, (i) {
      final val = double.tryParse(chart[i]['r']?.toString() ?? '0') ?? 0;
      return FlSpot(i.toDouble(), val);
    });
  }
}
