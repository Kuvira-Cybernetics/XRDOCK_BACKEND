import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../common/common.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? 'Login failed')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // For Web, passing the clientId is required
      final googleSignIn = GoogleSignIn(clientId: CommonData.googleClientId);
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Google Sign-In error: $e')));
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('XR-DOCK', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 10),
              Text(
                'ADVANCED SPATIAL ANALYTICS',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(letterSpacing: 4),
              ),
              const SizedBox(height: 50),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    width: 400,
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
                          Text(
                            'AUTHENTICATION',
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'EMAIL ADDRESS',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Email required';
                              }
                              if (!v.contains('@')) return 'Enter valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'PASSWORD',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password required';
                              }
                              if (v.length < 6) return 'Min 6 characters';
                              return null;
                            },
                          ),
                          const SizedBox(height: 32),
                          _isLoading
                              ? const CircularProgressIndicator()
                              : Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _signInWithEmail,
                                        child: const Text('INITIALIZE ACCESS'),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text('OR CONNECT VIA'),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _signInWithGoogle,
                                        icon: const Icon(
                                          Icons.g_mobiledata,
                                          size: 32,
                                        ),
                                        label: const Text(
                                          'Sign-In with GOOGLE',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          side: BorderSide(
                                            color: Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('NO ACCOUNT?'),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: const Text('REGISTER SYSTEM'),
                              ),
                            ],
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
