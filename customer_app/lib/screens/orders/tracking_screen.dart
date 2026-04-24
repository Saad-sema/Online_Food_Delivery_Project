import 'package:flutter/material.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/api_service.dart';
import '../../config/maps_config.dart';
import '../chat/chat_screen.dart';

class TrackingScreen extends StatefulWidget {
  final int orderId;
  const TrackingScreen({super.key, required this.orderId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Map<String, dynamic>? _tracking;
  bool _loading = true;
  Timer? _timer;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.trackOrder(widget.orderId);
      if (res.data['success'] == true) {
        if (!mounted) return;
        setState(() {
          _tracking = res.data['data'];
          _loading = false;
        });
        await _updateMapMarkers();
      } else {
        if (!mounted) return;
        setState(() => _loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _updateMapMarkers() async {
    if (_tracking == null) return;
    final markers = <Marker>{};

    final boyLat = double.tryParse(_tracking?['boy_lat']?.toString() ?? '');
    final boyLng = double.tryParse(_tracking?['boy_lng']?.toString() ?? '');
    final restLat = double.tryParse(_tracking?['restaurant_lat']?.toString() ?? '');
    final restLng = double.tryParse(_tracking?['restaurant_lng']?.toString() ?? '');
    final custLat = double.tryParse(_tracking?['customer_lat']?.toString() ?? '');
    final custLng = double.tryParse(_tracking?['customer_lng']?.toString() ?? '');

    // Restaurant
    if (restLat != null && restLat != 0) {
      markers.add(Marker(
        markerId: const MarkerId('restaurant'),
        position: LatLng(restLat, restLng!),
        infoWindow: InfoWindow(title: _tracking?['restaurant_name'] ?? 'Restaurant'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    }

    // Delivery Boy
    if (boyLat != null && boyLat != 0) {
      markers.add(Marker(
        markerId: const MarkerId('delivery_boy'),
        position: LatLng(boyLat, boyLng!),
        infoWindow: InfoWindow(title: _tracking?['delivery_boy_name'] ?? 'Delivery Executive'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    // Customer
    if (custLat != null && custLat != 0) {
      markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: LatLng(custLat, custLng!),
        infoWindow: const InfoWindow(title: 'You'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ));
    }

    if (mounted) {
      setState(() => _markers = markers);
      _fitMarkers(markers);
    }
    await _drawRoute(boyLat, boyLng, restLat, restLng, custLat, custLng);
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

  Future<void> _drawRoute(double? bLat, double? bLng, double? rLat, double? rLng, double? cLat, double? cLng) async {
    LatLng? origin, destination;
    final status = _tracking?['order_status'] ?? '';

    if (bLat != null && bLat != 0) {
      origin = LatLng(bLat, bLng!);
      if (status == 'assigned' || status == 'reached_restaurant' || status == 'accepted' || status == 'preparing') {
        destination = LatLng(rLat!, rLng!);
      } else {
        destination = LatLng(cLat!, cLng!);
      }
    }

    if (origin == null || destination == null) return;

    const apiKey = googleMapsApiKey;
    final url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=driving&key=$apiKey';

    try {
      final res = await Dio().get(url);
      if (res.data['status'] == 'OK') {
        final points = _decodePolyline(res.data['routes'][0]['overview_polyline']['points']);
        if (mounted) {
          setState(() {
            _polylines = {
              Polyline(polylineId: const PolylineId('route'), points: points, color: const Color(0xFFFF6B35), width: 5)
            };
          });
        }
      }
    } catch (_) {}
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length, lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      shift = 0; result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    final status = (_tracking?['order_status'] ?? '').toString().replaceAll('_', ' ').toUpperCase();
    final eta = _tracking?['eta_minutes'];
    final timeline = (_tracking?['timeline'] as List?) ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Live Tracking', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : Column(
              children: [
                // ETA Banner
                if (eta != null && _tracking?['order_status'] != 'delivered')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0xFFFF6B35), Color(0xFFFF8A5C)]),
                    ),
                    child: Row(children: [
                      const Icon(Icons.timer_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('ESTIMATED ARRIVAL', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        Text('$eta MINS', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                      ]),
                    ]),
                  ),

                // Map
                Expanded(
                  flex: 3,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: LatLng(
                      double.tryParse(_tracking?['customer_lat']?.toString() ?? '') ?? 0.0,
                      double.tryParse(_tracking?['customer_lng']?.toString() ?? '') ?? 0.0,
                    ), zoom: 14),
                    markers: _markers,
                    polylines: _polylines,
                    onMapCreated: (c) => _mapController = c,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                ),

                // Interaction Area
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Agent Info
                        if (_tracking?['delivery_boy_name'] != null)
                          _buildAgentCard(),
                        
                        const SizedBox(height: 10),
                        const Text('ORDER TIMELINE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey, letterSpacing: 1)),
                        const SizedBox(height: 16),
                        
                        // 7-step Timeline
                        ...timeline.map((item) {
                          final isDone = item['done'] == true;
                          final isLast = timeline.indexOf(item) == timeline.length - 1;
                          return IntrinsicHeight(
                            child: Row(children: [
                              Column(children: [
                                Container(
                                  width: 24, height: 24,
                                  decoration: BoxDecoration(color: isDone ? const Color(0xFFFF6B35) : Colors.grey.shade200, shape: BoxShape.circle),
                                  child: Icon(isDone ? Icons.check : Icons.circle, size: 14, color: isDone ? Colors.white : Colors.grey.shade400),
                                ),
                                if (!isLast) Expanded(child: Container(width: 2, color: isDone ? const Color(0xFFFF6B35) : Colors.grey.shade200)),
                              ]),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(item['step'], style: TextStyle(fontWeight: isDone ? FontWeight.bold : FontWeight.normal, color: isDone ? Colors.black : Colors.grey)),
                                    if (item['time'] != null && item['time'] != '')
                                      Text(item['time'].toString().length >= 16 
                                        ? item['time'].toString().substring(11, 16) 
                                        : item['time'].toString(), 
                                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ]),
                                ),
                              ),
                            ]),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(orderId: widget.orderId, recipientName: _tracking?['delivery_boy_name']))),
        backgroundColor: const Color(0xFFFF6B35),
        icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
        label: const Text('Chat with Agent', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAgentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        const CircleAvatar(radius: 24, backgroundColor: Color(0xFFFF6B35), child: Icon(Icons.person, color: Colors.white)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_tracking!['delivery_boy_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Text('Your Delivery Partner', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
        IconButton(
          icon: const Icon(Icons.call_rounded, color: Color(0xFFFF6B35)),
          onPressed: () {},
        ),
      ]),
    );
  }
}
