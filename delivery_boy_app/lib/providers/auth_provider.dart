import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoggedIn = false;

  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;

  AuthProvider() { tryAutoLogin(); }

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      _isLoggedIn = true;
      _user = {'name': prefs.getString('user_name') ?? '', 'email': prefs.getString('user_email') ?? ''};
      notifyListeners();
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final res = await ApiService.login(email, password);
      if (res.data['success'] == true) {
        final d = res.data['data'];
        if (d['user']['role'] != 'delivery_boy') return 'This app is for delivery partners only';
        _token = d['token'];
        _user = d['user'];
        _isLoggedIn = true;
        ApiService.setToken(_token!);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user_name', _user?['name'] ?? '');
        await prefs.setString('user_email', _user?['email'] ?? '');
        notifyListeners();
        return null;
      }
      return res.data['message'] ?? 'Login failed';
    } catch (e) {
      return 'Connection error';
    }
  }

  Future<String?> register(Map<String, dynamic> data) async {
    try {
      final res = await ApiService.register(data);
      if (res.data['success'] == true) {
        final d = res.data['data'];
        _token = d['token'];
        _user = {'id': d['user_id'], 'role': d['role']};
        _isLoggedIn = true;
        ApiService.setToken(_token!);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        notifyListeners();
        return null;
      }
      return res.data['message'] ?? 'Registration failed';
    } catch (e) {
      return 'Connection error';
    }
  }

  Future<void> logout() async {
    _token = null; _user = null; _isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
