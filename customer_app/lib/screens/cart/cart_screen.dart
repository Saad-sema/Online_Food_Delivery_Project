import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../checkout/checkout_screen.dart';
import '../../services/api_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _couponC = TextEditingController();
  bool _applyingCoupon = false;
  String? _couponMsg;

  Future<void> _applyCoupon() async {
    final code = _couponC.text.trim();
    if (code.isEmpty) return;
    setState(() { _applyingCoupon = true; _couponMsg = null; });
    try {
      final cart = context.read<CartProvider>();
      final res = await ApiService.applyCoupon(code, cart.subtotal);
      if (res.data['success'] == true) {
        final d = res.data['data'];
        cart.applyCoupon(d['code'], (d['discount'] as num).toDouble());
        setState(() => _couponMsg = d['message']);
      } else {
        setState(() => _couponMsg = res.data['message'] ?? 'Invalid coupon');
      }
    } catch (e) {
      setState(() => _couponMsg = 'Failed to apply coupon');
    }
    setState(() => _applyingCoupon = false);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final items = cart.items.values.toList();
    final deliveryCharge = 40.0;
    final taxPct = 5.0;
    final subtotal = cart.subtotal;
    final discount = cart.couponDiscount;
    final taxable = subtotal - discount;
    final tax = taxable * taxPct / 100;
    final total = taxable + tax + deliveryCharge;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Your Cart', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: items.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                const Text('Your cart is empty', style: TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('Add items from a restaurant', style: TextStyle(color: Colors.grey)),
              ]),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Items
                      ...items.map((item) => _cartItemCard(item, cart)),
                      const SizedBox(height: 16),

                      // Coupon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Have a coupon?', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _couponC,
                                    textCapitalization: TextCapitalization.characters,
                                    decoration: InputDecoration(
                                      hintText: 'Enter coupon code',
                                      filled: true,
                                      fillColor: const Color(0xFFF8F9FA),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: _applyingCoupon ? null : _applyCoupon,
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                  child: _applyingCoupon ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Apply'),
                                ),
                              ],
                            ),
                            if (_couponMsg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_couponMsg!, style: TextStyle(color: discount > 0 ? Colors.green : Colors.red, fontSize: 13))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Bill
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
                        child: Column(
                          children: [
                            _billRow('Subtotal', subtotal),
                            if (discount > 0) _billRow('Coupon Discount', -discount, color: Colors.green),
                            _billRow('Tax (${taxPct.toStringAsFixed(0)}%)', tax),
                            _billRow('Delivery Charge', deliveryCharge),
                            const Divider(height: 20),
                            _billRow('Total', total, bold: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Checkout button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4))]),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B35), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                      child: Text('Proceed to Checkout • ₹${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _cartItemCard(CartItem item, CartProvider cart) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('₹${item.price.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFFF6B35), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: () => cart.removeItem(item.id), constraints: const BoxConstraints(minWidth: 34, minHeight: 34)),
                Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                IconButton(icon: const Icon(Icons.add, size: 18), onPressed: () => cart.addItem(cart.restaurantId!, item.id, item.name, item.price), constraints: const BoxConstraints(minWidth: 34, minHeight: 34)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, double value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 16 : 14)),
          Text('${value < 0 ? '-' : ''}₹${value.abs().toStringAsFixed(0)}', style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: color ?? (bold ? const Color(0xFFFF6B35) : null), fontSize: bold ? 16 : 14)),
        ],
      ),
    );
  }
}
