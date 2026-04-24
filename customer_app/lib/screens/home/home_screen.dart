import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';
import '../restaurant/restaurant_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _restaurants = [];
  List<String> _cuisines = [];
  bool _loading = true;
  String? _selectedCuisine;
  final _searchC = TextEditingController();
  final _cityC = TextEditingController();
  Position? _currentPosition;
  String _detectedAddress = '';
  String _detectedCity = '';
  bool _citySearchMode = false;

  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _initLocation();
    // Start continuous 5-second location update
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _sendLocationUpdate();
    });
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _searchC.dispose();
    _cityC.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    await _getLocation();
    _loadHome();
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _detectedAddress = 'Detecting address...';
        });
      }

      // Reverse geocode to get human-readable address
      _reverseGeocode(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final res = await ApiService.reverseGeocode(lat, lng);
      if (res.data['success'] == true) {
        final data = res.data['data'];
        final address = data['address'] ?? '';
        final city = data['city'] ?? '';
        if (mounted) {
          setState(() {
            _detectedAddress = [address, city].where((s) => s.isNotEmpty).join(', ');
            _detectedCity = city;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _sendLocationUpdate() async {
    if (_currentPosition == null) return;
    try {
      // Refresh position
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );
      if (mounted) setState(() => _currentPosition = pos);
      await ApiService.updateLocation(pos.latitude, pos.longitude);
    } catch (_) {}
  }

  Future<void> _loadHome() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getHome(
        lat: _citySearchMode ? null : _currentPosition?.latitude,
        lng: _citySearchMode ? null : _currentPosition?.longitude,
        city: _citySearchMode && _cityC.text.isNotEmpty ? _cityC.text.trim() : null,
      );
      if (res.data['success'] == true) {
        _restaurants = res.data['data']['restaurants'] ?? [];
        _cuisines = List<String>.from(res.data['data']['cuisines'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getRestaurants(
        lat: _citySearchMode ? null : _currentPosition?.latitude,
        lng: _citySearchMode ? null : _currentPosition?.longitude,
        search: _searchC.text.isNotEmpty ? _searchC.text : null,
        cuisine: _selectedCuisine,
        city: _citySearchMode && _cityC.text.isNotEmpty ? _cityC.text.trim() : null,
      );
      if (res.data['success'] == true) {
        _restaurants = res.data['data']['restaurants'] ?? [];
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
      child: RefreshIndicator(
        color: const Color(0xFFFF6B35),
          onRefresh: () async { await _getLocation(); await _loadHome(); },
          child: CustomScrollView(
            slivers: [
              // ── HEADER ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: const [Color(0xFFFF5722), Color(0xFFFF9800)],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Location row
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Deliver to',
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                                Text(
                                  _detectedAddress.isNotEmpty
                                      ? _detectedAddress
                                      : _currentPosition != null
                                          ? 'Nearby Restaurants'
                                          : 'Enable Location',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // City search toggle
                          GestureDetector(
                            onTap: () => setState(() {
                              _citySearchMode = !_citySearchMode;
                              if (!_citySearchMode) { _cityC.clear(); _loadHome(); }
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _citySearchMode ? '📍 Use GPS' : '🔍 Other City',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // City input (visible only in city search mode)
                      if (_citySearchMode) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14)),
                          child: TextField(
                            controller: _cityC,
                            decoration: const InputDecoration(
                              hintText: 'Enter city name (e.g. Surat, Mumbai)...',
                              hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                              prefixIcon: const Icon(Icons.location_city, color: Color(0xFFFF6B35)),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 13),
                            ),
                            onSubmitted: (_) => _search(),
                          ),
                        ),
                      ],

                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10)]),
                        child: TextField(
                          controller: _searchC,
                          onSubmitted: (_) => _search(),
                          onChanged: (v) {
                            if (v.isEmpty) _loadHome();
                          },
                          decoration: InputDecoration(
                            hintText: 'Search restaurants...',
                            hintStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFFFF6B35)),
                            suffixIcon: _searchC.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () { _searchC.clear(); _loadHome(); })
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── CUISINES ──────────────────────────────────────────
              if (_cuisines.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _cuisines.length + 1,
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return _cuisineChip('All', _selectedCuisine == null,
                                () { setState(() => _selectedCuisine = null); _loadHome(); });
                          }
                          final c = _cuisines[i - 1];
                          return _cuisineChip(c, _selectedCuisine == c, () {
                            setState(() => _selectedCuisine = c);
                            _search();
                          });
                        },
                      ),
                    ),
                  ),
                ),

              // ── SECTION TITLE ───────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Row(
                    children: [
                      const Text('Popular Restaurants',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      if (_currentPosition != null && !_citySearchMode)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('≤ 20 km',
                              style: TextStyle(color: Color(0xFFFF6B35), fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
              ),

              // ── RESTAURANTS ──────────────────────────────────────
              _loading ? _shimmerGrid() : _restaurantGrid(),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cuisineChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF6B35) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFFFF6B35) : Colors.grey.shade300),
          boxShadow: selected
              ? [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.3), blurRadius: 8)]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }

  Widget _shimmerGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
        delegate: SliverChildBuilderDelegate(
          (_, __) => Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          ),
          childCount: 6,
        ),
      ),
    );
  }

  Widget _restaurantGrid() {
    if (_restaurants.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.restaurant_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_citySearchMode ? 'No restaurants found in this city' : 'No restaurants nearby',
                style: const TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 8),
            if (!_citySearchMode)
              TextButton(
                onPressed: () => setState(() { _citySearchMode = true; }),
                child: const Text('Search in another city?', style: TextStyle(color: Color(0xFFFF6B35))),
              ),
          ]),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
        delegate: SliverChildBuilderDelegate(
          (_, i) => _restaurantCard(_restaurants[i]),
          childCount: _restaurants.length,
        ),
      ),
    );
  }

  Widget _restaurantCard(Map<String, dynamic> r) {
    final imgUrl = r['image_url'] as String?;
    final hasImage = imgUrl != null && imgUrl.isNotEmpty;
    final distance = r['distance'];
    final status = r['operator_status'] ?? 'online';

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => RestaurantScreen(id: int.parse(r['id'].toString())))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: hasImage
                      ? CachedNetworkImage(
                          imageUrl: imgUrl,
                          height: 100,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _imgPlaceholder(),
                          errorWidget: (_, __, ___) => _imgPlaceholder(),
                        )
                      : _imgPlaceholder(),
                ),
                // Status badge
                if (status == 'busy')
                  Positioned(top: 6, right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(6)),
                      child: const Text('BUSY', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    )),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(r['cuisine'] ?? '',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 16),
                        const SizedBox(width: 3),
                        Text(
                          double.tryParse(r['rating_avg']?.toString() ?? '0')?.toStringAsFixed(1) ?? '0.0',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        if (distance != null && distance != 9999) ...[
                          const Spacer(),
                          Text(
                            '${double.tryParse(distance.toString())?.toStringAsFixed(1) ?? '?'} km',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    height: 100,
    decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.orange.shade100, Colors.orange.shade50])),
    child: Center(child: Icon(Icons.restaurant_rounded, size: 40, color: Colors.orange.shade300)),
  );
}
