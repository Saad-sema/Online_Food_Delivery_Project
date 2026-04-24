import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../providers/cart_provider.dart';
import '../cart/cart_screen.dart';

class RestaurantScreen extends StatefulWidget {
  final int id;
  const RestaurantScreen({super.key, required this.id});
  @override
  State<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends State<RestaurantScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _restaurant;
  bool _loading = true;
  String? _error;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.getRestaurant(widget.id);
      if (res.data['success'] == true) {
        setState(() { _restaurant = res.data['data']; _loading = false; });
      } else {
        setState(() {
          _error = res.data['message'] ?? 'Restaurant not found';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B35)))
          : _restaurant == null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.restaurant, size: 64, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(_error ?? 'Restaurant not found', style: const TextStyle(color: Colors.grey, fontSize: 16), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white)),
                ]))
              : NestedScrollView(
                  headerSliverBuilder: (_, __) => [
                    SliverAppBar(
                      expandedHeight: 220,
                      pinned: true,
                      backgroundColor: const Color(0xFFFF6B35),
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(_restaurant!['name'] ?? '',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        background: _buildRestaurantBanner(),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 20),
                                const SizedBox(width: 4),
                                Text(double.tryParse(_restaurant!['rating_avg']?.toString() ?? '0')?.toStringAsFixed(1) ?? '0.0',
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text(' (${_restaurant!['rating_count'] ?? 0})', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                const Spacer(),
                                Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text('${_restaurant!['opening_time']?.toString().substring(0, 5) ?? ''} - ${_restaurant!['closing_time']?.toString().substring(0, 5) ?? ''}',
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(_restaurant!['cuisine'] ?? '', style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Expanded(child: Text(_restaurant!['address'] ?? '', style: TextStyle(color: Colors.grey.shade500, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(TabBar(
                        controller: _tabCtrl,
                        labelColor: const Color(0xFFFF6B35),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFFFF6B35),
                        tabs: const [Tab(text: 'Menu'), Tab(text: 'Reviews'), Tab(text: 'Info')],
                      )),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _menuTab(),
                      _reviewsTab(),
                      _infoTab(),
                    ],
                  ),
                ),
      // Cart FAB
      floatingActionButton: cart.itemCount > 0 && cart.restaurantId == widget.id
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFFF6B35),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text('${cart.itemCount} items • ₹${cart.subtotal.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _menuTab() {
    final categories = List<Map<String, dynamic>>.from(_restaurant!['categories'] ?? []);
    if (categories.isEmpty) return const Center(child: Text('No menu items available'));
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: categories.length,
      itemBuilder: (_, ci) {
        final cat = categories[ci];
        final items = List<Map<String, dynamic>>.from(cat['items'] ?? []);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(cat['name'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF333333))),
            ),
            ...items.map((item) => _menuItemCard(item)),
          ],
        );
      },
    );
  }

  Widget _buildRestaurantBanner() {
    final imgUrl = _restaurant!['image_url'] as String?;
    if (imgUrl != null && imgUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imgUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.orange.shade200, Colors.orange.shade50])),
          child: Center(
              child: Icon(Icons.restaurant_rounded,
                  size: 60, color: Colors.orange.shade300)),
        ),
        errorWidget: (_, __, ___) => Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.orange.shade200, Colors.orange.shade50])),
          child: Center(
              child: Icon(Icons.restaurant_rounded,
                  size: 60, color: Colors.orange.shade300)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [Colors.orange.shade200, Colors.orange.shade50])),
      child: Center(
          child: Icon(Icons.restaurant_rounded,
              size: 60, color: Colors.orange.shade300)),
    );
  }

  Widget _menuItemCard(Map<String, dynamic> item) {
    final isVeg = item['is_veg'] == 1 || item['is_veg'] == true;
    final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
    final imgUrl = item['image_url'] as String?;
    final hasImage = imgUrl != null && imgUrl.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          // Veg/Non-veg indicator
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              border: Border.all(
                  color: isVeg ? Colors.green : Colors.red, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
                child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: isVeg ? Colors.green : Colors.red,
                        shape: BoxShape.circle))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (item['description'] != null &&
                    item['description'].toString().isNotEmpty)
                  Text(item['description'],
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('₹${price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B35),
                        fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Item image
          if (hasImage)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: imgUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                      width: 64,
                      height: 64,
                      color: Colors.grey.shade100),
                  errorWidget: (_, __, ___) => Container(
                      width: 64,
                      height: 64,
                      color: Colors.grey.shade100,
                      child: const Icon(Icons.fastfood,
                          color: Colors.grey)),
                ),
              ),
            ),
          SizedBox(
            height: 34,
            child: ElevatedButton(
              onPressed: () {
                context.read<CartProvider>().addItem(
                    widget.id,
                    int.parse(item['id'].toString()),
                    item['name'] ?? '',
                    price);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${item['name']} added to cart'),
                    duration: const Duration(seconds: 1)));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFFF6B35).withOpacity(0.1),
                foregroundColor: const Color(0xFFFF6B35),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('ADD',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewsTab() {
    final reviews = List<Map<String, dynamic>>.from(_restaurant!['reviews'] ?? []);
    if (reviews.isEmpty) return const Center(child: Text('No reviews yet'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reviews.length,
      itemBuilder: (_, i) {
        final r = reviews[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(r['reviewer'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  ...List.generate(5, (j) => Icon(Icons.star, size: 14, color: j < (int.tryParse(r['rating']?.toString() ?? '0') ?? 0) ? const Color(0xFFFFB300) : Colors.grey.shade300)),
                ],
              ),
              if (r['comment'] != null && r['comment'].toString().isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(r['comment'], style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
            ],
          ),
        );
      },
    );
  }

  Widget _infoTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.location_on_outlined, 'Address', _restaurant!['address'] ?? ''),
          _infoRow(Icons.schedule, 'Hours', '${_restaurant!['opening_time']?.toString().substring(0, 5) ?? ''} - ${_restaurant!['closing_time']?.toString().substring(0, 5) ?? ''}'),
          _infoRow(Icons.restaurant_menu, 'Cuisine', _restaurant!['cuisine'] ?? ''),
          _infoRow(Icons.phone, 'Phone', _restaurant!['owner_phone'] ?? 'N/A'),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF6B35), size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
