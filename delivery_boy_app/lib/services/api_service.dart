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

  // Auth
  static Future<Response> login(String email, String pw) =>
      _dio.post('login', data: {'email': email, 'password': pw});
  static Future<Response> register(Map<String, dynamic> data) =>
      _dio.post('register', data: data);
  static Future<Response> updateFcm(String t) async =>
      _dio.post('update-fcm-token', data: {'fcm_token': t}, options: _options);

  // Delivery requests (with optional GPS location for nearby sorting)
  static Future<Response> getRequests({double? lat, double? lng}) async =>
      _dio.get('delivery/requests',
          queryParameters: {
            if (lat != null) 'lat': lat,
            if (lng != null) 'lng': lng,
          },
          options: _options);

  static Future<Response> acceptRequest(int requestId) async =>
      _dio.post('delivery/requests/$requestId/accept', options: _options);
  static Future<Response> rejectRequest(int requestId) async =>
      _dio.post('delivery/requests/$requestId/reject', options: _options);

  // Active delivery management
  static Future<Response> getActiveDelivery() async =>
      _dio.get('delivery/active', options: _options);

  static Future<Response> reachedRestaurant(int orderId) async =>
      _dio.post('delivery/orders/$orderId/reached-restaurant', options: _options);

  static Future<Response> startDelivery(int orderId) async =>
      _dio.post('delivery/orders/$orderId/start', options: _options);

  static Future<Response> verifyOtp(int orderId, String otp) async =>
      _dio.post('delivery/orders/$orderId/verify-otp',
          data: {'otp': otp}, options: _options);

  static Future<Response> updateLocation(double lat, double lng) async =>
      _dio.post('delivery/location',
          data: {'lat': lat, 'lng': lng}, options: _options);

  // Chat
  static Future<Response> getMessages(int orderId) async =>
      _dio.get('chat/$orderId', options: _options);
  static Future<Response> sendMessage(int orderId, String message) async =>
      _dio.post('chat/$orderId',
          data: {'message': message}, options: _options);

  // History & Earnings
  static Future<Response> getHistory() async =>
      _dio.get('delivery/history', options: _options);
  static Future<Response> getEarnings({String? period}) async =>
      _dio.get('delivery/earnings',
          queryParameters: {if (period != null) 'period': period},
          options: _options);

  // Status
  static Future<Response> updateStatus(String status) async =>
      _dio.post('delivery/status', data: {'status': status}, options: _options);
}
