import 'dart:async';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/api_service.dart';
import '../../config/maps_config.dart';
import '../chat/chat_screen.dart';

class ActiveDeliveryScreen extends StatefulWidget {
  final int orderId;
  const ActiveDeliveryScreen({super.key, required this.orderId});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  final _otpC = TextEditingController();
  bool _loading = false;
  bool _disposed = false;

  Map<String, dynamic>? _order;
  String _status = 'assigned';

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Timer? _locationTimer;
  Timer? _pollTimer;
  Position? _myPosition;

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _startLocationTracking();
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) => _loadOrder(silent: true));
  }

  @override
  void dispose() {
    _disposed = true;
    _locationTimer?.cancel();
    _pollTimer?.cancel();
    _mapController?.dispose();
    _otpC.dispose();
    super.dispose();
  }

  // ─── Data ───────────────────────────────────────────────────────────────────

  Future<void> _loadOrder({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final res = await ApiService.getActiveDelivery();
      if (!_disposed && res.data['success'] == true && res.data['data'] != null) {
        final data = res.data['data'];
        setState(() {
          _order = data;
          _status = data['order_status'] ?? 'assigned';
        });
        await _updateMapMarkersAndRoute();
      }
    } catch (_) {}
    if (!silent && !_disposed) setState(() => _loading = false);
  }

  // ─── Directions + Polyline ──────────────────────────────────────────────────

  Future<void> _updateMapMarkersAndRoute() async {
    if (_order == null) return;
    final markers = <Marker>{};

    final rLat = double.tryParse(_order!['restaurant_lat']?.toString() ?? '');
    final rLng = double.tryParse(_order!['restaurant_lng']?.toString() ?? '');
    final cLat = double.tryParse(_order!['customer_lat']?.toString() ?? '');
    final cLng = double.tryParse(_order!['customer_lng']?.toString() ?? '');

    // Restaurant Marker
    if (rLat != null && rLng != null && rLat != 0) {
      markers.add(Marker(
        markerId: const MarkerId('restaurant'),
        position: LatLng(rLat, rLng),
        infoWindow: InfoWindow(title: _order!['restaurant_name'] ?? 'Restaurant'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    // Delivery Boy Marker (Me)
    if (_myPosition != null) {
      markers.add(Marker(
        markerId: const MarkerId('delivery_boy'),
        position: LatLng(_myPosition!.latitude, _myPosition!.longitude),
        infoWindow: const InfoWindow(title: 'You (Delivery)'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    // Customer Marker
    if (cLat != null && cLng != null && cLat != 0) {
      markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: LatLng(cLat, cLng),
        infoWindow: InfoWindow(title: _order!['customer_name'] ?? 'Customer'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    if (!_disposed) {
      setState(() => _markers = markers);
      _fitMarkers(markers);
    }
    await _drawRoute(rLat, rLng, cLat, cLng);
  }

  void _fitMarkers(Set<Marker> markers) {
    if (markers.isEmpty || _mapController == null) return;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final m in markers) {
      if (m.position.latitude < minLat) minLat = m.position.latitude;
      if (m.position.latitude > maxLat) maxLat = m.position.latitude;
      if (m.position.longitude < minLng) minLng = m.position.longitude;
      if (m.position.longitude > maxLng) maxLng = m.position.longitude;
    }
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      50,
    ));
  }

  Future<void> _drawRoute(double? rLat, double? rLng, double? cLat, double? cLng) async {
    LatLng? origin;
    LatLng? destination;

    if (_status == 'out_for_delivery') {
      // Navigate to Customer (Phase 2)
      // Destination is Customer, Origin is Restaurant (as per requirements: Restaurant to Customer)
      // However, usually it's Current Location to Customer. 
      // Requirement says: "After reaching the restaurant and picking up the order, display the best route from the Restaurant to the Customer location."
      if (rLat != null && rLng != null && cLat != null && cLng != null) {
        origin = LatLng(rLat, rLng);
        destination = LatLng(cLat, cLng);
      }
    } else {
      // Heading to Restaurant (Phase 1)
      // Destination is Restaurant, Origin is Current Location
      if (_myPosition != null && rLat != null && rLng != null) {
        origin = LatLng(_myPosition!.latitude, _myPosition!.longitude);
        destination = LatLng(rLat, rLng);
      }
    }

    if (origin == null || destination == null) return;

    try {
      final points = await _fetchRoutePoints(origin, destination);
      if (!_disposed && points.isNotEmpty) {
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: const Color(0xFF4F46E5),
              width: 5,
              jointType: JointType.round,
            )
          };
        });
      }
    } catch (_) {}
  }

  Future<List<LatLng>> _fetchRoutePoints(LatLng origin, LatLng dest) async {
    const apiKey = googleMapsApiKey;
    final url =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${dest.latitude},${dest.longitude}'
        '&mode=driving&key=$apiKey';

    final dio = Dio();
    try {
      final response = await dio.get(url);
      if (response.statusCode == 200 &&
          response.data['status'] == 'OK' &&
          response.data['routes'] != null &&
          (response.data['routes'] as List).isNotEmpty) {
        final encoded = response.data['routes'][0]['overview_polyline']['points'] as String;
        return _decodePolyline(encoded);
      }
    } catch (_) {}
    return [];
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  // ─── Location tracking ──────────────────────────────────────────────────────

  void _startLocationTracking() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
        final initialPos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        if (!_disposed) {
          setState(() => _myPosition = initialPos);
          await ApiService.updateLocation(initialPos.latitude, initialPos.longitude);
        }

        // CONTINUOUS TRACKING: Update every 5 seconds
        _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
          try {
            final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 3),
            );
            if (!_disposed) {
              setState(() => _myPosition = pos);
              await ApiService.updateLocation(pos.latitude, pos.longitude);
              if (_order != null) await _updateMapMarkersAndRoute();
            }
          } catch (_) {}
        });
      }
    } catch (_) {}
  }

  // ─── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _reachedRestaurant() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.reachedRestaurant(widget.orderId);
      if (!_disposed && res.data['success'] == true) {
        setState(() => _status = 'reached_restaurant');
        _showSnack('You have reached the restaurant! 🏪', Colors.orange);
        await _updateMapMarkersAndRoute();
      } else {
        _showSnack(res.data['message'] ?? 'Failed to update', Colors.red);
      }
    } catch (_) { _showSnack('Network error', Colors.red); }
    if (!_disposed) setState(() => _loading = false);
  }

  Future<void> _pickedUp() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.startDelivery(widget.orderId);
      if (!_disposed && res.data['success'] == true) {
        setState(() => _status = 'out_for_delivery');
        _showSnack('Order picked up! Navigate to customer. 🛵', Colors.green);
        await _updateMapMarkersAndRoute();
      } else {
        _showSnack(res.data['message'] ?? 'Failed to update', Colors.red);
      }
    } catch (_) { _showSnack('Network error', Colors.red); }
    if (!_disposed) setState(() => _loading = false);
  }

  Future<void> _verifyOtp() async {
    if (_otpC.text.length < 6) {
      _showSnack('Enter 6-digit OTP', Colors.orange);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ApiService.verifyOtp(widget.orderId, _otpC.text);
      if (!_disposed && res.data['success'] == true) {
        _showSuccessDialog();
      } else {
        _showSnack(res.data['message'] ?? 'Invalid OTP', Colors.red);
      }
    } catch (_) { _showSnack('Verification failed', Colors.red); }
    if (!_disposed) setState(() => _loading = false);
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.verified_rounded, color: Colors.green, size: 60),
          const SizedBox(height: 16),
          const Text('Delivered!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 8),
          const Text('Order # verified successfully.', style: TextStyle(color: Colors.grey)),
        ]),
        actions: [
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
            child: const Text('Complete'),
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eta = _order?['eta_minutes'];
    final phaseTitle = _status == 'out_for_delivery' ? 'Delivering to Customer' : 'Heading to Restaurant';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text('Order Tracking', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.chat_outlined, color: Color(0xFF4F46E5)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(orderId: widget.orderId)))),
        ],
      ),
      body: _order == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : Column(
              children: [
                // Top Status Info
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(phaseTitle, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const Text('Live Navigation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ]),
                    const Spacer(),
                    if (eta != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFF4F46E5).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text('$eta min', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                      ),
                  ]),
                ),

                // Map
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: LatLng(_myPosition?.latitude ?? 20.5937, _myPosition?.longitude ?? 78.9629), zoom: 15),
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    onMapCreated: (c) { _mapController = c; _updateMapMarkersAndRoute(); },
                  ),
                ),

                // Bottom Panel
                _buildActionPanel(),
              ],
            ),
    );
  }

  Widget _buildActionPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Destination Row
        Row(children: [
          const Icon(Icons.location_on_rounded, color: Color(0xFF4F46E5)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_status == 'out_for_delivery' ? 'Customer Address' : 'Restaurant Address',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(_status == 'out_for_delivery' ? (_order!['delivery_address'] ?? 'N/A') : (_order!['restaurant_address'] ?? 'N/A'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 2),
            if (_status == 'out_for_delivery' && (_order!['flat_no'] != null || _order!['landmark'] != null))
              Text('${_order!['flat_no'] ?? ""} ${_order!['landmark'] ?? ""}', style: const TextStyle(fontSize: 12, color: Colors.indigo)),
          ])),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.green),
            onPressed: () {}, // url_launcher would go here
          ),
        ]),
        const SizedBox(height: 16),

        // Action Buttons
        if (_status == 'assigned')
          _bigButton('I have reached Restaurant 🏪', Colors.orange, _reachedRestaurant)
        else if (_status == 'reached_restaurant')
          _bigButton('Order Collected 🛒', const Color(0xFF4F46E5), _pickedUp)
        else if (_status == 'out_for_delivery')
          Column(children: [
            const Text('Enter Customer OTP', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _otpC,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
              decoration: InputDecoration(
                counterText: '',
                hintText: '000000',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            _bigButton('Verify & Complete Delivery 🏁', Colors.green, _verifyOtp),
          ]),
      ]),
    );
  }

  Widget _bigButton(String text, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _loading ? null : onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: _loading ? const CircularProgressIndicator(color: Colors.white) : Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
