import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoggedIn => _token != null;

  final Dio _dio = Dio(BaseOptions(baseUrl: baseUrl));

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token  = prefs.getString('token');
    final name   = prefs.getString('user_name');
    final role   = prefs.getString('user_role');
    if (token != null && name != null) {
      _token = token;
      _user  = {'name': name, 'role': role};
      ApiService.setToken(token);
      notifyListeners();
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final res = await _dio.post('login', data: {'email': email, 'password': password});
      if (res.data['success'] == true) {
        _token = res.data['data']['token'];
        _user  = res.data['data']['user'];
        ApiService.setToken(_token!);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user_name', _user!['name'] ?? '');
        await prefs.setString('user_role', _user!['role'] ?? '');
        notifyListeners();
        return null; // success
      }
      return res.data['message'];
    } on DioException catch (e) {
      final data = e.response?.data;
      return (data is Map ? data['message'] : null) ?? 'Login failed';
    }
  }

  Future<String?> register(Map<String, String> data) async {
    try {
      final res = await _dio.post('register', data: data);
      if (res.data['success'] == true) {
        _token = res.data['data']['token'];
        ApiService.setToken(_token!);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        notifyListeners();
        return null;
      }
      return res.data['message'];
    } on DioException catch (e) {
      final data = e.response?.data;
      return (data is Map ? data['message'] : null) ?? 'Registration failed';
    }
  }

  Future<void> logout() async {
    _token = null;
    _user  = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  Dio get dio {
    _dio.options.headers['Authorization'] = 'Bearer $_token';
    return _dio;
  }
}
