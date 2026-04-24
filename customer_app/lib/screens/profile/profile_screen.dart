import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  List<dynamic> _addresses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pRes = await ApiService.getProfile();
      if (pRes.data['success'] == true) _profile = pRes.data['data'];
      final aRes = await ApiService.listAddresses();
      if (aRes.data['success'] == true) _addresses = aRes.data['data'] ?? [];
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _editProfile() async {
    final nameC = TextEditingController(text: _profile?['name'] ?? '');
    final phoneC = TextEditingController(text: _profile?['phone'] ?? '');
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          TextField(controller: nameC, decoration: _dec('Full Name', Icons.person_outline)),
          const SizedBox(height: 14),
          TextField(controller: phoneC, decoration: _dec('Phone', Icons.phone_outlined), keyboardType: TextInputType.phone),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              await ApiService.updateProfile({'name': nameC.text, 'phone': phoneC.text});
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _addAddress() async {
    final line1C = TextEditingController();
    final line2C = TextEditingController();
    final cityC = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Add Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          TextField(controller: line1C, decoration: _dec('Address Line 1', Icons.location_on_outlined)),
          const SizedBox(height: 12),
          TextField(controller: line2C, decoration: _dec('Address Line 2 (optional)', Icons.location_city)),
          const SizedBox(height: 12),
          TextField(controller: cityC, decoration: _dec('City', Icons.location_city_outlined)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              await ApiService.addAddress({'address_line1': line1C.text, 'address_line2': line2C.text, 'city': cityC.text, 'is_default': _addresses.isEmpty ? 1 : 0});
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Add Address', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _deleteAddress(int id) async {
    try { await ApiService.deleteAddress(id); _load(); }
    catch (_) {}
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon, color: const Color(0xFFFF6B35)),
    filled: true, fillColor: const Color(0xFFF8F9FA),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, backgroundColor: Colors.white, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Profile card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8F65)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    const CircleAvatar(radius: 30, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 34, color: Colors.white)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_profile?['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(_profile?['email'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                      Text(_profile?['phone'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    ])),
                    IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: _editProfile),
                  ]),
                ),
                const SizedBox(height: 24),

                // Addresses
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('My Addresses', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  TextButton.icon(onPressed: _addAddress, icon: const Icon(Icons.add, size: 18, color: Color(0xFFFF6B35)), label: const Text('Add', style: TextStyle(color: Color(0xFFFF6B35)))),
                ]),
                const SizedBox(height: 8),
                if (_addresses.isEmpty) const Text('No addresses added yet', style: TextStyle(color: Colors.grey))
                else ..._addresses.map((a) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                  child: Row(children: [
                    const Icon(Icons.location_on, color: Color(0xFFFF6B35)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a['address_line1'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(a['city'] ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ])),
                    if (a['is_default'] == 1 || a['is_default'] == '1')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Default', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    IconButton(icon: Icon(Icons.delete_outline, color: Colors.red.shade300, size: 20), onPressed: () => _deleteAddress(int.parse(a['id'].toString()))),
                  ]),
                )),
                const SizedBox(height: 24),

                // Settings & Others
                const Text('Settings & Info', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                  child: Column(children: [
                    _tile(Icons.account_balance_wallet_outlined, 'Refunds', () {
                      // Navigate to refunds screen
                      Navigator.pushNamed(context, '/refunds');
                    }),
                    const Divider(height: 1),
                    _tile(Icons.help_outline, 'Help & Support', () {}),
                    const Divider(height: 1),
                    _tile(Icons.info_outline, 'About FoodDash', () {}),
                  ]),
                ),
                const SizedBox(height: 32),

                // Logout
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => context.read<AuthProvider>().logout(),
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: const Color(0xFFFF6B35)),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
    trailing: const Icon(Icons.chevron_right, size: 20),
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
  );
}
