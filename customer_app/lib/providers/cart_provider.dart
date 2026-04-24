import 'package:flutter/material.dart';

class CartItem {
  final int id;
  final String name;
  final double price;
  int quantity;
  CartItem({required this.id, required this.name, required this.price, this.quantity = 1});
}

class CartProvider extends ChangeNotifier {
  int? _restaurantId;
  final Map<int, CartItem> _items = {};
  String? _couponCode;
  double _couponDiscount = 0;

  Map<int, CartItem> get items => {..._items};
  int? get restaurantId => _restaurantId;
  String? get couponCode => _couponCode;
  double get couponDiscount => _couponDiscount;

  double get subtotal => _items.values.fold(0, (sum, i) => sum + i.price * i.quantity);
  double get total => subtotal - couponDiscount;
  int get itemCount => _items.values.fold(0, (sum, i) => sum + i.quantity);

  void addItem(int restaurantId, int itemId, String name, double price) {
    if (_restaurantId != null && _restaurantId != restaurantId) {
      clearCart();
    }
    _restaurantId = restaurantId;
    if (_items.containsKey(itemId)) {
      _items[itemId]!.quantity++;
    } else {
      _items[itemId] = CartItem(id: itemId, name: name, price: price);
    }
    notifyListeners();
  }

  void removeItem(int itemId) {
    if (_items[itemId]?.quantity == 1) {
      _items.remove(itemId);
    } else {
      _items[itemId]!.quantity--;
    }
    notifyListeners();
  }

  void applyCoupon(String code, double discount) {
    _couponCode    = code;
    _couponDiscount = discount;
    notifyListeners();
  }

  void clearCart() {
    _items.clear();
    _restaurantId = null;
    _couponCode   = null;
    _couponDiscount = 0;
    notifyListeners();
  }

  List<Map<String, dynamic>> get itemsForApi => _items.values
      .map((i) => {'id': i.id, 'quantity': i.quantity})
      .toList();
}
