import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF818CF8)]), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            const CircleAvatar(radius: 30, backgroundColor: Colors.white24, child: Icon(Icons.delivery_dining, size: 30, color: Colors.white)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(auth.user?['name'] ?? 'Delivery Partner', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              Text(auth.user?['email'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
            ])),
          ]),
        ),
        const SizedBox(height: 24),
        _tile(Icons.phone, 'Phone', auth.user?['phone'] ?? 'N/A'),
        _tile(Icons.two_wheeler, 'Vehicle', auth.user?['vehicle_number'] ?? 'Not set'),
        _tile(Icons.star, 'Rating', auth.user?['rating'] ?? 'N/A'),
        const SizedBox(height: 24),
        SizedBox(height: 50, child: OutlinedButton.icon(
          onPressed: () => auth.logout(),
          icon: const Icon(Icons.logout, color: Colors.red),
          label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        )),
      ]),
    );
  }

  Widget _tile(IconData icon, String label, String value) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      Icon(icon, color: const Color(0xFF4F46E5), size: 22),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ]),
    ]),
  );
}
