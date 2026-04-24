import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_service.dart';
import '../orders/order_detail_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  // Delivery Option
  String _deliveryOption = 'current'; // 'current' or 'custom'

  // GPS option fields
  Position? _gpsPosition;
  String _gpsAddressDisplay = 'Detecting location...';
  String _gpsCity = '';
  final _flatNoC = TextEditingController();
  final _landmarkC = TextEditingController();
  bool _gpsLoading = false;

  // Pin-drop option fields
  LatLng? _pinLatLng;
  String _pinAddressDisplay = 'Tap the map to drop a pin';
  GoogleMapController? _mapController;

  // Payment
  String _paymentMethod = 'cod';
  double _tipAmount = 0.0;
  bool _placing = false;
  final _specialNotesC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGpsLocation();
  }

  @override
  void dispose() {
    _flatNoC.dispose();
    _landmarkC.dispose();
    _specialNotesC.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchGpsLocation() async {
    setState(() => _gpsLoading = true);
    try {
      bool svc = await Geolocator.isLocationServiceEnabled();
      if (!svc) {
        setState(() { _gpsAddressDisplay = 'Location services off'; _gpsLoading = false; });
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() { _gpsAddressDisplay = 'Permission denied'; _gpsLoading = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() => _gpsPosition = pos);
      // Reverse geocode
      final res = await ApiService.reverseGeocode(pos.latitude, pos.longitude);
      if (res.data['success'] == true) {
        final d = res.data['data'];
        setState(() {
          _gpsAddressDisplay = d['display_name'] ?? '${pos.latitude}, ${pos.longitude}';
          _gpsCity = d['city'] ?? '';
        });
      } else {
        setState(() => _gpsAddressDisplay = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
      }
    } catch (e) {
      setState(() => _gpsAddressDisplay = 'Could not detect location');
    }
    setState(() => _gpsLoading = false);
  }

  Future<void> _reverseGeocodePin(LatLng pos) async {
    setState(() => _pinAddressDisplay = 'Detecting address...');
    try {
      final res = await ApiService.reverseGeocode(pos.latitude, pos.longitude);
      if (res.data['success'] == true) {
        setState(() => _pinAddressDisplay = res.data['data']['display_name'] ?? 'Selected location');
      }
    } catch (_) {
      setState(() => _pinAddressDisplay = 'Selected location');
    }
  }

  Future<void> _placeOrder() async {
    final cart = context.read<CartProvider>();

    // Validate delivery info
    if (_deliveryOption == 'current' && _gpsPosition == null) {
      _showErr('Could not detect GPS location. Please use "Another Location" option.');
      return;
    }
    if (_deliveryOption == 'custom' && _pinLatLng == null) {
      _showErr('Please drop a pin on the map to select delivery location.');
      return;
    }

    setState(() => _placing = true);
    try {
      final Map<String, dynamic> payload = {
        'restaurant_id': cart.restaurantId,
        'payment_method': _paymentMethod,
        'items': cart.itemsForApi,
        'coupon_code': cart.couponCode ?? '',
        'tip_amount': _tipAmount,
        'delivery_option': _deliveryOption,
        'special_notes': _specialNotesC.text.trim(),
      };

      if (_deliveryOption == 'current') {
        payload['delivery_lat']  = _gpsPosition!.latitude;
        payload['delivery_lng']  = _gpsPosition!.longitude;
        payload['flat_no']       = _flatNoC.text.trim();
        payload['landmark']      = _landmarkC.text.trim();
        payload['city']          = _gpsCity;
      } else {
        payload['delivery_lat']  = _pinLatLng!.latitude;
        payload['delivery_lng']  = _pinLatLng!.longitude;
        payload['flat_no']       = '';
        payload['landmark']      = '';
      }

      final res = await ApiService.placeOrder(payload);
      if (res.data['success'] == true) {
        final data = res.data['data'];
        cart.clearCart();
        if (mounted) _showSuccessDialog(data);
      } else {
        _showErr(res.data['message'] ?? 'Failed to place order');
      }
    } catch (_) {
      _showErr('Failed to place order. Please try again.');
    }
    if (mounted) setState(() => _placing = false);
  }

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccessDialog(Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 30),
          SizedBox(width: 10),
          Text('Order Placed! 🎉'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Order #${data['order_id']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              const Text('Your Delivery OTP', style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 6),
              Text('${data['delivery_otp'] ?? data['otp']}',
                  style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.bold,
                      color: Color(0xFFFF6B35), letterSpacing: 10)),
              const SizedBox(height: 4),
              const Text('Share this OTP with your delivery partner',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          ),
          const SizedBox(height: 10),
          Text('Total: ₹${data['total_amount']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(orderId: data['order_id'])));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Track Order'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
          title: const Text('Checkout', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── DELIVERY OPTION ────────────────────────────────────
          const Text('Choose Delivery Location',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),

          // Option 1 – Current GPS
          _optionCard(
            selected: _deliveryOption == 'current',
            onTap: () => setState(() => _deliveryOption = 'current'),
            icon: Icons.my_location_rounded,
            iconColor: Colors.green,
            title: '✅ Deliver to Current Location',
            subtitle: 'Uses your live GPS location',
            child: _deliveryOption == 'current' ? _gpsFields() : null,
          ),
          const SizedBox(height: 10),

          // Option 2 – Drop pin
          _optionCard(
            selected: _deliveryOption == 'custom',
            onTap: () => setState(() => _deliveryOption = 'custom'),
            icon: Icons.place_rounded,
            iconColor: const Color(0xFFFF6B35),
            title: '📍 Deliver to Another Location',
            subtitle: 'Drop a pin anywhere on the map',
            child: _deliveryOption == 'custom' ? _mapField() : null,
          ),
          const SizedBox(height: 22),

          // ── PAYMENT ────────────────────────────────────────────
          const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          _paymentOption('cod', 'Cash on Delivery', Icons.money_rounded, 'Pay when you receive'),
          const SizedBox(height: 8),
          _paymentOption('upi', 'UPI (Demo)', Icons.account_balance_wallet_rounded, 'Instant payment simulation'),
          const SizedBox(height: 22),

          // ── TIP ────────────────────────────────────────────────
          const Text('Tip for Delivery Partner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              const Text('Appreciate your delivery partner with a tip 🙏',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [10, 20, 30, 50].map((t) => _tipChip(t.toDouble())).toList()),
            ]),
          ),
          const SizedBox(height: 22),

          // ── SPECIAL INSTRUCTIONS ───────────────────────────────
          const Text('Special Instructions (Optional)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
            ),
            child: TextField(
              controller: _specialNotesC,
              maxLines: 3,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'e.g. Make it less spicy, no onions, extra ketchup...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.edit_note_rounded, color: Color(0xFFFF6B35)),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                counterStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ── ORDER SUMMARY ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Order Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Text('${cart.itemCount} items • ₹${cart.subtotal.toStringAsFixed(0)}',
                  style: TextStyle(color: Colors.grey.shade700)),
              if (cart.couponDiscount > 0)
                Text('Coupon discount: -₹${cart.couponDiscount.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.green)),
              if (_tipAmount > 0)
                Text('Tip: +₹${_tipAmount.toStringAsFixed(0)}',
                    style: const TextStyle(color: Color(0xFFFF6B35))),
              const Divider(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('₹${(cart.total + _tipAmount).toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFFF6B35))),
              ]),
            ]),
          ),
          const SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4))]),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _placing ? null : _placeOrder,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0),
            child: _placing
                ? const SizedBox(height: 22, width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Place Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  Widget _optionCard({
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: selected ? const Color(0xFFFF6B35) : Colors.grey.shade200, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w700,
                      color: selected ? const Color(0xFFFF6B35) : Colors.black87)),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ])),
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? const Color(0xFFFF6B35) : Colors.grey.shade400),
              ]),
            ),
            if (child != null) child,
          ],
        ),
      ),
    );
  }

  Widget _gpsFields() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(),
        // Detected address
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            _gpsLoading
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                : const Icon(Icons.location_on_rounded, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_gpsAddressDisplay,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            TextButton(
              onPressed: _fetchGpsLocation,
              style: TextButton.styleFrom(minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Refresh', style: TextStyle(fontSize: 11, color: Colors.green)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        // Flat No
        TextField(
          controller: _flatNoC,
          decoration: InputDecoration(
            labelText: 'Flat / House No.',
            hintText: 'e.g. Flat 201, Block B',
            prefixIcon: const Icon(Icons.home_rounded, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        // Landmark
        TextField(
          controller: _landmarkC,
          decoration: InputDecoration(
            labelText: 'Landmark (optional)',
            hintText: 'e.g. Near City Mall',
            prefixIcon: const Icon(Icons.place_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            isDense: true,
          ),
        ),
      ]),
    );
  }

  Widget _mapField() {
    final initialPin = _pinLatLng ?? const LatLng(20.5937, 78.9629); // center of India
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(),
        const Text('Drop a pin to choose delivery location:',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 220,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: initialPin, zoom: 5),
              onMapCreated: (c) => _mapController = c,
              markers: _pinLatLng != null
                  ? {Marker(markerId: const MarkerId('pin'), position: _pinLatLng!,
                      infoWindow: const InfoWindow(title: 'Delivery Here'))}
                  : {},
              onTap: (pos) {
                setState(() { _pinLatLng = pos; });
                _reverseGeocodePin(pos);
                _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Icon(Icons.place_rounded, color: Color(0xFFFF6B35), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_pinAddressDisplay,
                  style: const TextStyle(fontSize: 12), maxLines: 2),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _paymentOption(String value, String title, IconData icon, String subtitle) {
    final selected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? const Color(0xFFFF6B35) : Colors.transparent, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
        ),
        child: Row(children: [
          Icon(icon, color: selected ? const Color(0xFFFF6B35) : Colors.grey, size: 28),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600,
                color: selected ? const Color(0xFFFF6B35) : null)),
            Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          ])),
          Icon(selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? const Color(0xFFFF6B35) : Colors.grey.shade400),
        ]),
      ),
    );
  }

  Widget _tipChip(double amount) {
    final selected = _tipAmount == amount;
    return GestureDetector(
      onTap: () => setState(() => _tipAmount = (selected ? 0.0 : amount)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF6B35) : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFFFF6B35) : Colors.orange.shade100),
        ),
        child: Text('₹${amount.toInt()}',
            style: TextStyle(color: selected ? Colors.white : const Color(0xFFFF6B35),
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}
