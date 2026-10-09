import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Store token in memory for now
  String? _token;
  bool _isNewUser = false;

  String? get token => _token;
  bool get isNewUser => _isNewUser;

  Future<bool> sendOtp(String phone) async {
    // Simulate network request
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    // Simulate network request
    await Future.delayed(const Duration(seconds: 1));
    
    _token = 'mock_access_token';

    // Save token to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', _token!);
    await prefs.setBool('isLoggedIn', true);
    
    return true;
  }

  // Backwards compatibility with the old MockAuthService signatures
  Future<bool> login(String phone, String otp) async {
    _isNewUser = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isNewUser', false);
    return await verifyOtp(phone, otp);
  }

  Future<bool> register(String name, String phone, String otp) async {
    _isNewUser = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isNewUser', true);
    return await verifyOtp(phone, otp);
  }

  Future<void> loadUserState() async {
    final prefs = await SharedPreferences.getInstance();
    _isNewUser = prefs.getBool('isNewUser') ?? false;
  }

  Future<void> logout() async {
    _token = null;
    _isNewUser = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('isNewUser');
  }
}
