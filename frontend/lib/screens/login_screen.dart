import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../common/common.dart';
import 'register_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleCustomToken();
    });
  }

  Future<void> _handleCustomToken() async {
    final uri = Uri.base;
    debugPrint('Checking for token in URL: ${uri.toString()}');
    debugPrint('Fragment: ${uri.fragment}');
    debugPrint('Query Parameters: ${uri.queryParameters}');

    String? token;

    // 1. Try Fragment (Flutter default for hash routing)
    if (uri.fragment.contains('token=')) {
      final fragmentParts = uri.fragment.split('?');
      if (fragmentParts.length > 1) {
        final queryParams = Uri.splitQueryString(fragmentParts.last);
        token = queryParams['token'];
        debugPrint('Token found in fragment: $token');
      }
    }

    // 2. Try Search Params (if redirecting top-level or without hash)
    if (token == null && uri.queryParameters.containsKey('token')) {
      token = uri.queryParameters['token'];
      debugPrint('Token found in query parameters: $token');
    }

    // 3. Try preserved token from startup (CommonData)
    if (token == null && CommonData.pendingAutodeskToken != null) {
      token = CommonData.pendingAutodeskToken;
      debugPrint('Using preserved token from startup: $token');
      // Clear it so it's not used again if navigating back to login
      CommonData.pendingAutodeskToken = null;
    }

    if (token != null) {
      debugPrint('Found custom token, cleaning URL and signing in...');

      if (kIsWeb) {
        // CLEAN THE URL IMMEDIATELY after extracting the token
        // This prevents the token from being read again if the page re-initializes
        html.window.history.replaceState(null, 'XR-DOCK', '/#/');
      }

      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.signInWithCustomToken(token);

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } catch (e) {
        debugPrint('Custom token sign-in error: $e');
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Autodesk sign-in failed: $e',
            isError: true,
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

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
        CommonData.showCustomSnackBar(
          context,
          e.message ?? 'Login failed',
          isError: true,
        );
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
        CommonData.showCustomSnackBar(
          context,
          'Google Sign-In error: $e',
          isError: true,
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
      body: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 100,
                  fit: BoxFit.contain,
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
                              'SIGN IN',
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
                                if (!v.contains('@'))
                                  return 'Enter valid email';
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
                                          child: const Text('LOGIN'),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text('OR'),
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
                                            'Sign-In with Google',
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
                                      const SizedBox(height: 16),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: _signInWithAutodesk,
                                          icon: const Icon(
                                            Icons.settings_input_component,
                                            size: 24,
                                          ),
                                          label: const Text(
                                            'Sign-In with Autodesk',
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
                                  child: const Text('REGISTER'),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/subscribe'),
                              child: const Text('CONTACT SALES / PRICING'),
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

  Future<void> _signInWithAutodesk() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String url = '${CommonData.backendUrl}/auth/autodesk/login';
      if (user != null) {
        url += '?firebase_uid=${user.uid}';
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final loginUrl = data['url'];
        debugPrint('Redirecting to Autodesk: $loginUrl');

        if (kIsWeb) {
          // Use direct JS redirection to avoid opening two tabs
          html.window.location.href = loginUrl;
        } else {
          if (await canLaunchUrl(Uri.parse(loginUrl))) {
            await launchUrl(
              Uri.parse(loginUrl),
              mode: LaunchMode.externalApplication,
            );
          } else {
            throw 'Could not launch $loginUrl';
          }
        }
      } else {
        throw 'Failed to get login URL: ${response.body}';
      }
    } catch (e) {
      if (mounted) {
        CommonData.showCustomSnackBar(
          context,
          'Autodesk login error: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
