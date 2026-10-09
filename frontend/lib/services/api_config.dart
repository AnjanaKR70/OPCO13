// lib/services/api_config.dart

class ApiConfig {
  static const String baseUrl = "http://172.16.19.206:8000"; // Laptop IP for physical device testing

  // Endpoints
  static const String sendOtp = "$baseUrl/auth/send-otp";
  static const String verifyOtp = "$baseUrl/auth/verify-otp";
  static const String scanFile = "$baseUrl/scan";
  static const String scanUrl = "$baseUrl/scan/url";
  static const String issues = "$baseUrl/issues";
  static const String permissions = "$baseUrl/user/permissions";
  static const String cyberContacts = "$baseUrl/cybercell/contacts";
  static const String dashboardStats = "$baseUrl/dashboard/stats";
}
