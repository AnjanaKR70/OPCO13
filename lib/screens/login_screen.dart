import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../services/localization_service.dart';
import 'permission_onboarding_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _otpSent = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
      _otpSent = false; // reset flow 
      _formKey.currentState?.reset();
    });
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_otpSent) return;

      setState(() {
        _isLoading = true;
      });

      final authService = context.read<AuthService>();
      bool success = false;

      final phone = '+91${_phoneController.text.trim()}';
      final otp = _otpController.text.trim();
      
      if (_isLogin) {
        success = await authService.login(
          phone,
          otp,
        );
      } else {
        success = await authService.register(
          _nameController.text.trim(),
          phone,
          otp,
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (success) {
          // Both Sign In and Sign Up should request permissions natively
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => const PermissionOnboardingScreen()),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationService>();
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    loc.translate('Welcome to SCAMundo'),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: AppTheme.primaryNavy,
                          fontSize: 28,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loc.translate('Enter your phone number to continue.'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF666666),
                        ),
                  ),
                  const SizedBox(height: 32),
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration:
                          InputDecoration(labelText: loc.translate('Full Name')),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return loc.translate('Please enter your name');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: loc.translate('Phone Number'),
                      prefixText: '+91 ',
                      suffixIcon: TextButton(
                        onPressed: () async {
                          if (_phoneController.text.trim().length >= 10) {
                            final phone = _phoneController.text.trim();
                            final authService = context.read<AuthService>();
                            
                            // Call the actual FastAPI backend
                            String? devOtp = await authService.sendOtp('+91$phone');
                            
                            if (devOtp != null) {
                              setState(() {
                                _otpSent = true;
                                _otpController.text = devOtp; // Auto-fill!
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(loc.translate('OTP generated and auto-filled!'))),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(loc.translate('Failed to generate OTP. Check backend.'))),
                              );
                            }
                          }
                        },
                        child: Text(
                          _otpSent ? loc.translate('Resend OTP') : loc.translate('Get OTP'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return loc.translate('Please enter phone number');
                      }
                      if (val.trim().length < 10) {
                        return loc.translate('Enter a valid 10-digit phone number');
                      }
                      return null;
                    },
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _otpController,
                      decoration: InputDecoration(
                        labelText: loc.translate('Enter OTP'),
                      ),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return loc.translate('Please enter OTP sent sequentially to device');
                        }
                        if (val.length < 4) {
                          return loc.translate('Invalid OTP format');
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_otpSent) ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: AppTheme.backgroundWhite,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(_isLogin ? loc.translate('Login') : loc.translate('Create Account'),
                              style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading ? null : _toggleMode,
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryNavy,
                    ),
                    child: Text(_isLogin
                        ? loc.translate("Don't have an account? Sign up")
                        : loc.translate('Already have an account? Sign in')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
