import 'package:flutter/material.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpSent = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo placeholder
              Center(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF0F2C59),
                      fontFamily: 'cursive', // Assuming cursive font for "SCAM"
                    ),
                    children: [
                      TextSpan(text: 'SCAM'),
                      TextSpan(
                        text: 'ഉണ്ടോ',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'sans-serif',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              // Phone Number Field
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    hintText: 'Phone Number',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    suffixIcon: TextButton(
                      onPressed: () {
                        if (_phoneController.text.isNotEmpty) {
                          setState(() {
                            _isOtpSent = true;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('OTP sent! Please use 1234 to login.')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter phone number first.')),
                          );
                        }
                      },
                      child: const Text(
                        'Get OTP',
                        style: TextStyle(
                          color: Color(0xFF0F2C59),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_isOtpSent) ...[
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      hintText: 'Enter OTP (Use 1234)',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              // Sign In Button
              ElevatedButton(
                onPressed: () {
                  if (!_isOtpSent) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please click Get OTP first.')),
                    );
                    return;
                  }
                  if (_otpController.text == '1234') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid OTP. Try 1234')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isOtpSent ? const Color(0xFF0F2C59) : Colors.grey.shade200,
                  foregroundColor: _isOtpSent ? Colors.white : Colors.grey.shade600,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Sign In',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 24),
              // Sign up link
              Center(
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(color: Colors.black87, fontSize: 14),
                    children: [
                      TextSpan(text: "Don't have an account? "),
                      TextSpan(
                        text: 'Sign up',
                        style: TextStyle(
                          color: Color(0xFF0F2C59),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
