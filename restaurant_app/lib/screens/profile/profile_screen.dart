import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;

  final _addressC = TextEditingController();
  final _nameC    = TextEditingController();
  final _cuisineC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addressC.dispose();
    _nameC.dispose();
    _cuisineC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getProfile();
      if (res.data['success'] == true) {
        _profile = res.data['data'];
        _addressC.text = _profile?['address'] ?? '';
        _nameC.text    = _profile?['name'] ?? '';
        _cuisineC.text = _profile?['cuisine'] ?? '';
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final res = await ApiService.updateProfile({
        'name': _nameC.text,
        'address': _addressC.text,
        'cuisine': _cuisineC.text,
      });
      if (res.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Color(0xFF059669)));
        _load();
      }
    } catch (_) {}
    setState(() => _saving = false);
  }

  Future<void> _uploadRestaurantImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (img == null) return;
    setState(() => _uploading = true);
    try {
      final res = await ApiService.uploadRestaurantImage(img.path);
      if (res.data['success'] == true) {
        setState(() { _profile?['image_url'] = res.data['data']['image_url']; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Banner updated!'), backgroundColor: Color(0xFF059669)));
      }
    } catch (_) {}
    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _profile?['image_url'] as String?;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Restaurant Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_loading)
            IconButton(
              icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check, color: Color(0xFF059669)),
              onPressed: _saving ? null : _save,
            )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Banner Section
                _buildBanner(imageUrl),
                const SizedBox(height: 24),

                // Manual Address Entry (Requirement 1)
                _sectionTitle('Restaurant Settings'),
                const SizedBox(height: 12),
                _buildTextField('Restaurant Name', _nameC, Icons.storefront_rounded),
                _buildTextField('Cuisine / Description', _cuisineC, Icons.restaurant_rounded),
                _buildTextField('Manual Address Entry', _addressC, Icons.location_on_rounded, maxLines: 2),

                const SizedBox(height: 24),
                _sectionTitle('Account Info'),
                _infoItem('Owner Phone', _profile?['owner_phone'] ?? 'N/A', Icons.phone_android_rounded),
                _infoItem('Operational Status', (_profile?['is_active'] == 1) ? 'Verified' : 'Pending', Icons.verified_user_rounded),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () => context.read<AuthProvider>().logout(),
                    icon: const Icon(Icons.logout_rounded, color: Colors.red),
                    label: const Text('Logout Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87));

  Widget _buildBanner(String? url) {
    return GestureDetector(
      onTap: _uploading ? null : _uploadRestaurantImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(24),
          image: url != null ? DecorationImage(image: CachedNetworkImageProvider(url), fit: BoxFit.cover) : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Stack(children: [
          if (url == null)
            const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.grey),
              Text('Add Restaurant Banner', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ])),
          Positioned(right: 12, bottom: 12, child: Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: _uploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.camera_alt_rounded, size: 20, color: Color(0xFF059669)),
          )),
        ]),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF059669), size: 20),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5)),
        ),
      ),
    );
  }

  Widget _infoItem(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(icon, color: Colors.grey.shade400, size: 22),
        const SizedBox(width: 15),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      ]),
    );
  }
}
