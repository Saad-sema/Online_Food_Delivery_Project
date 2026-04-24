import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    validateStatus: (status) => true,
  ));

  static String? _token;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  static void setToken(String token) {
    _token = token;
  }

  static Options get _options => Options(
    headers: {
      if (_token != null) 'Authorization': 'Bearer $_token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  );

  // ── Auth ──────────────────────────────────────────────────────
  static Future<Response> login(String email, String password) =>
      _dio.post('login', data: {'email': email, 'password': password});

  static Future<Response> register(Map<String, dynamic> data) =>
      _dio.post('register', data: data);

  static Future<Response> updateFcmToken(String fcmToken) async =>
      _dio.post('update-fcm-token',
          data: {'fcm_token': fcmToken}, options: _options);

  // ── Tracking & Geocoding ──────────────────────────────────────
  static Future<Response> updateLocation(double lat, double lng) async =>
      _dio.post('location/update',
          data: {'lat': lat, 'lng': lng}, options: _options);

  static Future<Response> reverseGeocode(double lat, double lng) async =>
      _dio.get('geocode/reverse',
          queryParameters: {'lat': lat, 'lng': lng}, options: _options);

  // ── Customer Home ─────────────────────────────────────────────
  static Future<Response> getHome({double? lat, double? lng, String? city}) async =>
      _dio.get('customer/home',
        queryParameters: {
          if (lat != null) 'lat': lat,
          if (lng != null) 'lng': lng,
          if (city != null) 'city': city,
        },
        options: _options);

  static Future<Response> getRestaurants({
    double? lat,
    double? lng,
    String? search,
    String? cuisine,
    String? city,
    int page = 1,
  }) async =>
      _dio.get('restaurants',
          queryParameters: {
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
            if (search != null) 'search': search,
            if (cuisine != null) 'cuisine': cuisine,
            if (city != null) 'city': city,
            'page': page,
          },
          options: _options);

  static Future<Response> getRestaurant(int id) async =>
      _dio.get('restaurants/$id', options: _options);

  // ── Cart ──────────────────────────────────────────────────────
  static Future<Response> getCart() async =>
      _dio.get('cart', options: _options);

  static Future<Response> addToCart(int itemId, int qty) async =>
      _dio.post('cart/add',
          data: {'item_id': itemId, 'quantity': qty},
          options: _options);

  static Future<Response> updateCart(int itemId, int qty) async =>
      _dio.post('cart/update',
          data: {'item_id': itemId, 'quantity': qty},
          options: _options);

  static Future<Response> removeFromCart(int itemId) async =>
      _dio.post('cart/remove',
          data: {'item_id': itemId}, options: _options);

  static Future<Response> applyCoupon(String code, double subtotal) async =>
      _dio.post('customer/apply-coupon',
          data: {'code': code, 'subtotal': subtotal}, options: _options);

  // ── Orders ────────────────────────────────────────────────────
  static Future<Response> placeOrder(Map<String, dynamic> data) async =>
      _dio.post('orders/place', data: data, options: _options);

  static Future<Response> listOrders() async =>
      _dio.get('orders', options: _options);

  static Future<Response> listRefunds() async =>
      _dio.get('refunds', options: _options);

  static Future<Response> getOrder(int id) async =>
      _dio.get('orders/$id', options: _options);

  static Future<Response> cancelOrder(int id, {String? reason}) async =>
      _dio.post('orders/$id/cancel',
          data: {'reason': reason ?? 'Cancelled by customer'}, options: _options);

  static Future<Response> trackOrder(int id) async =>
      _dio.get('orders/$id/track', options: _options);

  static Future<Response> addTip(int orderId, double tip) async =>
      _dio.post('orders/$orderId/tip',
          data: {'tip_amount': tip}, options: _options);

  // ── Reviews ───────────────────────────────────────────────────
  static Future<Response> postReview(Map<String, dynamic> data) async =>
      _dio.post('reviews', data: data, options: _options);

  // ── Addresses ─────────────────────────────────────────────────
  static Future<Response> listAddresses() async =>
      _dio.get('addresses', options: _options);

  static Future<Response> addAddress(Map<String, dynamic> data) async =>
      _dio.post('addresses', data: data, options: _options);

  static Future<Response> updateAddress(int id, Map<String, dynamic> data) async =>
      _dio.put('addresses/$id', data: data, options: _options);

  static Future<Response> deleteAddress(int id) async =>
      _dio.delete('addresses/$id', options: _options);

  // ── Profile ───────────────────────────────────────────────────
  static Future<Response> getProfile() async =>
      _dio.get('profile', options: _options);

  static Future<Response> updateProfile(Map<String, dynamic> data) async =>
      _dio.put('profile', data: data, options: _options);

  // ── Chat ──────────────────────────────────────────────────────
  static Future<Response> getMessages(int orderId) async =>
      _dio.get('chat/$orderId', options: _options);

  static Future<Response> sendMessage(int orderId, String message) async =>
      _dio.post('chat/$orderId',
          data: {'message': message}, options: _options);
}
