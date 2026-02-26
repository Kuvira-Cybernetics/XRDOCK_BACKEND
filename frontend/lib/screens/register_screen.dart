import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../common/common.dart';

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
      UserCredential credential;
      if (FirebaseAuth.instance.currentUser == null) {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
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

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/subscribe');
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Registration failed')),
        );
      }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google Sign-Up failed: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildAccountStep() {
    return Column(
      key: const ValueKey(0),
      children: [
        Text(
          'Step 1: Contact Information',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'FULL NAME'),
                validator: (v) => v!.isEmpty ? 'Name required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _jobTitleController,
                decoration: const InputDecoration(labelText: 'JOB TITLE / ROLE'),
                validator: (v) => v!.isEmpty ? 'Job title required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'WORK EMAIL'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email required';
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(v)) return 'Enter a valid email address';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'PHONE NUMBER'),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    final phoneRegex = RegExp(r'^\+?[\d\s-]{10,}$');
                    if (!phoneRegex.hasMatch(v)) return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'PASSWORD'),
                validator: (v) => v!.length < 6 ? 'Min 6 chars' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'CONFIRM PASSWORD'),
                validator: (v) =>
                    v != _passwordController.text ? 'Passwords match fail' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompanyStep() {
    return Column(
      key: const ValueKey(1),
      children: [
        Text(
          'Step 2: Company Details',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _companyNameController,
                decoration: const InputDecoration(labelText: 'COMPANY NAME'),
                validator: (v) => v!.isEmpty ? 'Company name required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _companyWebsiteController,
                decoration: const InputDecoration(labelText: 'COMPANY WEBSITE'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _industryController,
                decoration: const InputDecoration(labelText: 'INDUSTRY'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _employeeCountController,
                decoration: const InputDecoration(
                  labelText: 'EMPLOYEE COUNT (e.g., 50-200)',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _countryController.text.isEmpty
              ? null
              : _countryController.text,
          decoration: const InputDecoration(labelText: 'COUNTRY'),
          items: const [
            DropdownMenuItem(
              value: 'United States',
              child: Text('United States'),
            ),
            DropdownMenuItem(value: 'India', child: Text('India')),
            DropdownMenuItem(
              value: 'United Kingdom',
              child: Text('United Kingdom'),
            ),
            DropdownMenuItem(value: 'Canada', child: Text('Canada')),
            DropdownMenuItem(value: 'Australia', child: Text('Australia')),
            DropdownMenuItem(value: 'Germany', child: Text('Germany')),
            DropdownMenuItem(value: 'France', child: Text('France')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (val) {
            if (val != null) _countryController.text = val;
          },
          validator: (v) => v == null || v.isEmpty ? 'Country required' : null,
        ),
      ],
    );
  }

  Widget _buildUseCaseStep() {
    return Column(
      key: const ValueKey(2),
      children: [
        Text(
          'Step 3: Business Use Case',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _projectTypeController,
                decoration: const InputDecoration(
                  labelText: 'PROJECT TYPE',
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _expectedSeatsController,
                decoration: const InputDecoration(
                  labelText: 'EXPECTED NUMBER OF SEATS',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _linkedinController,
          decoration: const InputDecoration(
            labelText: 'LINKEDIN URL (Optional)',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    Widget currentStepWidget;
    if (_currentStep == 0)
      currentStepWidget = _buildAccountStep();
    else if (_currentStep == 1)
      currentStepWidget = _buildCompanyStep();
    else
      currentStepWidget = _buildUseCaseStep();

    return Scaffold(
      body: Scrollbar(
        thumbVisibility: true, // Optional but good for desktop
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
            children: [
              Text(
                'JOIN XR-DOCK',
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: 40),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 750,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withAlpha(200),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withOpacity(0.2)),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
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
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 32),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: currentStepWidget,
                          ),
                          const SizedBox(height: 32),
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : Column(
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
                                          child: ElevatedButton(
                                            onPressed: _nextStep,
                                            child: Text(
                                              _currentStep < 2
                                                  ? 'NEXT'
                                                  : 'CREATE ACCOUNT',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_currentStep == 0) ...[
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          const Expanded(child: Divider()),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            child: Text(
                                              'OR',
                                              style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const Expanded(child: Divider()),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: _signUpWithGoogle,
                                          icon: Image.network(
                                            'https://www.google.com/favicon.ico',
                                            height: 18,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.login,
                                                  size: 18,
                                                ),
                                          ),
                                          label: const Text(
                                            'CONTINUE WITH GOOGLE',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            side: BorderSide(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                          const SizedBox(height: 16),
                          if (_currentStep == 0)
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('BACK TO LOGIN'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
