import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../common/common.dart';
import '../theme/xrdock_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 0: Account Info
  final _nameController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 1: Company Info
  final _companyNameController = TextEditingController();
  final _companyWebsiteController = TextEditingController();
  final _industryController = TextEditingController();
  final _employeeCountController = TextEditingController();
  final _countryController = TextEditingController();

  // Step 2: Use Case
  final _projectTypeController = TextEditingController();
  final _expectedSeatsController = TextEditingController();
  final _linkedinController = TextEditingController();

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;

    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _register();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      // Create user directly, or update if they used Google previously
      // If we got here from Google Sign Up, we just need to send the data, but
      // assuming standard email flow here first.
      if (FirebaseAuth.instance.currentUser == null) {
        UserCredential credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );
        await credential.user!.updateDisplayName(_nameController.text.trim());
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        final body = jsonEncode({
          'name': _nameController.text.trim(),
          'job_title': _jobTitleController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'linkedin_url': _linkedinController.text.trim(),
          'company_name': _companyNameController.text.trim(),
          'company_website': _companyWebsiteController.text.trim(),
          'industry': _industryController.text.trim(),
          'employee_count': _employeeCountController.text.trim(),
          'country': _countryController.text.trim(),
          'project_type': _projectTypeController.text.trim(),
          'expected_seats': int.tryParse(_expectedSeatsController.text.trim()),
        });

        await http.post(
          Uri.parse('${CommonData.backendUrl}/users'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body,
        );

        if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted)
        CommonData.showCustomSnackBar(
          context,
          e.message ?? 'Registration failed',
          isError: true,
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final googleUser = await GoogleSignIn(
        clientId: CommonData.googleClientId,
      ).signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      if (userCredential.user != null) {
        // Pre-fill fields and move to step 1
        _nameController.text = userCredential.user!.displayName ?? '';
        _emailController.text = userCredential.user!.email ?? '';
        setState(() {
          _currentStep = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        CommonData.showCustomSnackBar(
          context,
          'Google Sign-Up failed: $e',
          isError: true,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // Left Side: Branding (Desktop only)
          if (isDesktop)
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/auth_bg.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Container(color: XRDockTheme.deepNavy),
                  ),
                  Container(color: Colors.black.withOpacity(0.4)),
                  Padding(
                    padding: const EdgeInsets.all(64),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset('assets/images/logo.png', height: 48),
                        const Spacer(),
                        Text(
                          'Join XRDOCK\nTransform your Workflow',
                          style: GoogleFonts.orbitron(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Manage XR projects, local data, and issues in one integrated environment.',
                          style: GoogleFonts.exo2(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Right Side: Multi-step Form
          Expanded(
            flex: isDesktop ? 4 : 1,
            child: Container(
              color: isDark ? const Color(0xFF0B1221) : Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? size.width * 0.05 : 24,
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isDesktop) ...[
                            Image.asset('assets/images/logo.png', height: 32),
                            const SizedBox(height: 32),
                          ],
                          Text(
                            'CREATE ACCOUNT',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: isDark
                                  ? Colors.white
                                  : XRDockTheme.deepNavy,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Step Indicator
                          Row(
                            children: List.generate(3, (index) {
                              return Expanded(
                                child: Container(
                                  height: 4,
                                  margin: EdgeInsets.only(
                                    right: index < 2 ? 8 : 0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _currentStep >= index
                                        ? XRDockTheme.secondaryPurple
                                        : Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 48),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _buildCurrentStep(),
                          ),
                          const SizedBox(height: 48),
                          if (_isLoading)
                            const Center(child: CircularProgressIndicator())
                          else
                            Column(
                              children: [
                                Row(
                                  children: [
                                    if (_currentStep > 0)
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: _previousStep,
                                          child: const Text('BACK'),
                                        ),
                                      ),
                                    if (_currentStep > 0)
                                      const SizedBox(width: 16),
                                    Expanded(
                                      child: Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          gradient: XRDockTheme.purpleGradient,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                          ),
                                          onPressed: _nextStep,
                                          child: Text(
                                            _currentStep < 2
                                                ? 'NEXT'
                                                : 'CREATE ACCOUNT',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_currentStep == 0) ...[
                                  const SizedBox(height: 32),
                                  Center(
                                    child: TextButton(
                                      onPressed: _signUpWithGoogle,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.g_mobiledata,
                                            size: 24,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'CONTINUE WITH GOOGLE',
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        'ALREADY HAVE AN ACCOUNT? LOG IN',
                                        style: GoogleFonts.exo2(
                                          color: XRDockTheme.secondaryPurple,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildAccountStep();
      case 1:
        return _buildCompanyStep();
      case 2:
        return _buildUseCaseStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAccountStep() {
    return Column(
      key: const ValueKey(0),
      children: [
        _buildRow([
          _buildField(
            _nameController,
            'FULL NAME',
            'John Doe',
            validator: (v) => v!.isEmpty ? 'Name required' : null,
          ),
          _buildField(
            _jobTitleController,
            'JOB TITLE',
            'Project Manager',
            validator: (v) => v!.isEmpty ? 'Job title required' : null,
          ),
        ]),
        const SizedBox(height: 24),
        _buildRow([
          _buildField(
            _emailController,
            'WORK EMAIL',
            'john@company.com',
            type: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email required';
              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegex.hasMatch(v)) return 'Enter a valid email address';
              return null;
            },
          ),
          _buildField(
            _phoneController,
            'PHONE NUMBER',
            '+1...',
            type: TextInputType.phone,
            validator: (v) {
              if (v != null && v.isNotEmpty) {
                final phoneRegex = RegExp(r'^\+?[\d\s-]{10,}$');
                if (!phoneRegex.hasMatch(v))
                  return 'Enter a valid phone number';
              }
              return null;
            },
          ),
        ]),
        const SizedBox(height: 24),
        _buildRow([
          _buildField(
            _passwordController,
            'PASSWORD',
            '••••••••',
            obscure: true,
            validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
          ),
          _buildField(
            _confirmPasswordController,
            'CONFIRM',
            '••••••••',
            obscure: true,
            validator: (v) =>
                v != _passwordController.text ? 'Passwords do not match' : null,
          ),
        ]),
      ],
    );
  }

  Widget _buildCompanyStep() {
    return Column(
      key: const ValueKey(1),
      children: [
        _buildRow([
          _buildField(
            _companyNameController,
            'COMPANY NAME',
            'XR Co.',
            validator: (v) => v!.isEmpty ? 'Company name required' : null,
          ),
          _buildField(_companyWebsiteController, 'WEBSITE', 'https://...'),
        ]),
        const SizedBox(height: 24),
        _buildRow([
          _buildField(_industryController, 'INDUSTRY', 'Architecture'),
          _buildField(_employeeCountController, 'EMPLOYEES', '50-200'),
        ]),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(
          value: _countryController.text.isEmpty
              ? null
              : _countryController.text,
          decoration: const InputDecoration(labelText: 'COUNTRY'),
          items: [
            'United States',
            'India',
            'United Kingdom',
            'Canada',
            'Australia',
            'Germany',
            'France',
            'Other',
          ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (val) => _countryController.text = val ?? '',
          validator: (v) => v == null || v.isEmpty ? 'Country required' : null,
        ),
      ],
    );
  }

  Widget _buildUseCaseStep() {
    return Column(
      key: const ValueKey(2),
      children: [
        _buildRow([
          _buildField(_projectTypeController, 'PROJECT TYPE', 'BIM / VR'),
          _buildField(
            _expectedSeatsController,
            'EXPECTED SEATS',
            '10',
            type: TextInputType.number,
          ),
        ]),
        const SizedBox(height: 24),
        _buildField(
          _linkedinController,
          'LINKEDIN URL (OPTIONAL)',
          'https://linkedin.com/...',
        ),
      ],
    );
  }

  Widget _buildRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 400)
          return Column(
            children: children
                .expand((w) => [w, const SizedBox(height: 24)])
                .toList(),
          );
        return Row(
          children:
              children
                  .expand(
                    (w) => [Expanded(child: w), const SizedBox(width: 16)],
                  )
                  .toList()
                ..removeLast(),
        );
      },
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    String hint, {
    bool obscure = false,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator:
          validator ??
          (v) => (v == null || v.isEmpty) && label != 'LINKEDIN URL (OPTIONAL)'
              ? 'Required'
              : null,
    );
  }
}
