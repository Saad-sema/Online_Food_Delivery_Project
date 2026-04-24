import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
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

  static Options get _multipartOptions => Options(
    headers: {
      if (_token != null) 'Authorization': 'Bearer $_token',
    },
  );

  // Auth
  static Future<Response> login(String email, String pw) =>
      _dio.post('login', data: {'email': email, 'password': pw});
  static Future<Response> register(Map<String, dynamic> data) =>
      _dio.post('register', data: data);
  static Future<Response> updateFcm(String t) async =>
      _dio.post('update-fcm-token', data: {'fcm_token': t}, options: _options);

  // Orders
  static Future<Response> getOrders({String? status}) async =>
      _dio.get('restaurant/orders', queryParameters: {if (status != null) 'status': status}, options: _options);
  static Future<Response> getOrder(int id) async =>
      _dio.get('restaurant/orders/$id', options: _options);
  static Future<Response> acceptOrder(int id) async =>
      _dio.post('restaurant/orders/$id/accept', options: _options);
  static Future<Response> rejectOrder(int id) async =>
      _dio.post('restaurant/orders/$id/reject', options: _options);
  static Future<Response> markPreparing(int id) async =>
      _dio.post('restaurant/orders/$id/preparing', options: _options);
  static Future<Response> markReady(int id) async =>
      _dio.post('restaurant/orders/$id/ready', options: _options);

  // Operator status
  static Future<Response> updateOperatorStatus(String status) async =>
      _dio.post('restaurant/operator-status', data: {'status': status}, options: _options);

  // Location update (every 5 seconds)
  static Future<Response> updateLocation(double lat, double lng) async =>
      _dio.post('location/update', data: {'lat': lat, 'lng': lng}, options: _options);

  // Menu
  static Future<Response> getCategories() async =>
      _dio.get('restaurant/menu', options: _options);
  static Future<Response> addCategory(Map<String, dynamic> d) async =>
      _dio.post('restaurant/menu/category', data: d, options: _options);
  static Future<Response> updateCategory(int id, Map<String, dynamic> d) async =>
      _dio.put('restaurant/menu/category/$id', data: d, options: _options);
  static Future<Response> deleteCategory(int id) async =>
      _dio.delete('restaurant/menu/category/$id', options: _options);
  static Future<Response> addItem(Map<String, dynamic> d) async =>
      _dio.post('restaurant/menu/item', data: d, options: _options);
  static Future<Response> updateItem(int id, Map<String, dynamic> d) async =>
      _dio.put('restaurant/menu/item/$id', data: d, options: _options);
  static Future<Response> deleteItem(int id) async =>
      _dio.delete('restaurant/menu/item/$id', options: _options);

  /// Upload menu item image (multipart). Returns response with image_url.
  static Future<Response> uploadMenuItemImage(int itemId, String filePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });
    return _dio.post(
      'restaurant/menu/item/$itemId/upload',
      data: formData,
      options: _multipartOptions,
    );
  }

  // Earnings
  static Future<Response> getEarnings({String? period}) async =>
      _dio.get('restaurant/earnings', queryParameters: {if (period != null) 'period': period}, options: _options);

  // Profile
  static Future<Response> getProfile() async =>
      _dio.get('restaurant/profile', options: _options);
  static Future<Response> updateProfile(Map<String, dynamic> d) async =>
      _dio.put('restaurant/profile', data: d, options: _options);

  /// Upload restaurant banner image (multipart). Returns response with image_url.
  static Future<Response> uploadRestaurantImage(String filePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });
    return _dio.post(
      'restaurant/upload',
      data: formData,
      options: _multipartOptions,
    );
  }
}
