import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class AuthService {
  // Store token in memory for now
  String? _token;

  String? get token => _token;

  Future<String?> sendOtp(String phone) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.sendOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phone}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final devOtp = data['data']['dev_otp'].toString();
        print("OTP Sent: $devOtp"); // In dev mode
        return devOtp;
      }
      return null;
    } catch (e) {
      print("Error sending OTP: $e");
      return null;
    }
  }

  Future<bool> verifyOtp(String phone, String otp) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone_number': phone, 'otp': otp}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['data']['access_token'];
        
        final user = data['data']['user'];
        final userName = user != null ? user['full_name'] : null;
        final userPhone = user != null ? user['phone_number'] : null;

        // Save token to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!);
        await prefs.setBool('isLoggedIn', true);
        
        if (userName != null) await prefs.setString('user_name', userName);
        if (userPhone != null) await prefs.setString('user_phone', userPhone);
        
        return true;
      }
      return false;
    } catch (e) {
      print("Error verifying OTP: $e");
      return false;
    }
  }

  // Backwards compatibility with the old MockAuthService signatures
  Future<bool> login(String phone, String otp) async {
    return await verifyOtp(phone, otp);
  }

  Future<bool> register(String name, String phone, String otp) async {
    // The backend auto-registers users upon OTP verification,
    // so we just call verifyOtp. We can ignore 'name' or add a profile update API later.
    return await verifyOtp(phone, otp);
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
  }
}
