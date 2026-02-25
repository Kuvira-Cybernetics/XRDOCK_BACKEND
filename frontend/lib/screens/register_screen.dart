import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      if (credential.user != null) {
        await credential.user!.updateDisplayName(_nameController.text.trim());
        // In real app, call backend /users to upsert user profile
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
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

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                    width: 450,
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
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'FULL NAME',
                            ),
                            validator: (v) =>
                                v!.isEmpty ? 'Name required' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'EMAIL',
                            ),
                            validator: (v) =>
                                !v!.contains('@') ? 'Invalid email' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'PASSWORD',
                            ),
                            validator: (v) =>
                                v!.length < 6 ? 'Min 6 chars' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'CONFIRM PASSWORD',
                            ),
                            validator: (v) => v != _passwordController.text
                                ? 'Passwords match fail'
                                : null,
                          ),
                          const SizedBox(height: 32),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _register,
                                    child: const Text('CREATE ACCOUNT'),
                                  ),
                                ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('ALREADY HAVE AN ACCOUNT? LOGIN'),
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
    );
  }
}
