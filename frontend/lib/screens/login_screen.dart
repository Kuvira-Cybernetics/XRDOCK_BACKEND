import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import '../common/common.dart';
import 'register_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../theme/xrdock_theme.dart';

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
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleCustomToken();
    });
  }

  Future<void> _handleCustomToken() async {
    final uri = Uri.base;
    String? token;
    if (uri.fragment.contains('token=')) {
      final fragmentParts = uri.fragment.split('?');
      if (fragmentParts.length > 1) {
        final queryParams = Uri.splitQueryString(fragmentParts.last);
        final customToken = queryParams['token'];
        if (customToken != null) {
          CommonData.isAutodeskUser = true;
          token = customToken;
        }
      }
    }
    if (token == null && uri.queryParameters.containsKey('token')) {
      token = uri.queryParameters['token'];
      if (token != null) CommonData.isAutodeskUser = true;
    }
    if (token == null && CommonData.pendingAutodeskToken != null) {
      token = CommonData.pendingAutodeskToken;
      CommonData.pendingAutodeskToken = null;
      if (token != null) CommonData.isAutodeskUser = true;
    }

    if (token != null) {
      if (kIsWeb) {
        html.window.history.replaceState(null, 'XR-DOCK', '/#/');
      }

      setState(() => _isLoading = true);
      try {
        await FirebaseAuth.instance.signInWithCustomToken(token);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } catch (e) {
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
    // Note: _isLoading handled by caller or here
    bool previouslyLoading = _isLoading;
    if (!previouslyLoading) setState(() => _isLoading = true);

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
      if (mounted && !previouslyLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSmartSignIn() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      CommonData.showCustomSnackBar(
        context,
        'Please enter your email',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse(
          '${CommonData.backendUrl}/auth/check-provider?email=${Uri.encodeComponent(email)}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final provider = data['provider'];

        if (provider == 'google') {
          debugPrint('Smart Routing: Found Google account for $email');
          // If it's a Google account, trigger Google Sign-In immediately
          await _signInWithGoogle();
          return; // _signInWithGoogle handled Navigator and loading
        } else if (provider == 'autodesk') {
          debugPrint('Smart Routing: Found Autodesk account for $email');
          await _signInWithAutodesk();
          return;
        } else {
          // Standard password flow
          debugPrint('Smart Routing: Defaulting to password for $email');
          if (_passwordController.text.trim().isEmpty) {
            CommonData.showCustomSnackBar(
              context,
              'This email is registered with an XRDOCK account. Please enter your password.',
              isInfo: true,
            );
            setState(() => _isLoading = false);
            return;
          } else {
            await _signInWithEmail();
            return;
          }
        }
      } else {
        // Fallback to email/password if check fails
        await _signInWithEmail();
      }
    } catch (e) {
      debugPrint('Smart Sign-In Error: $e');
      await _signInWithEmail();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
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

  Future<void> _signInWithAutodesk() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String url = '${CommonData.backendUrl}/auth/autodesk/login';
      if (user != null) url += '?firebase_uid=${user.uid}';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final loginUrl = data['url'];
        if (kIsWeb) {
          html.window.location.href = loginUrl;
        } else {
          if (await canLaunchUrl(Uri.parse(loginUrl))) {
            await launchUrl(
              Uri.parse(loginUrl),
              mode: LaunchMode.externalApplication,
            );
          }
        }
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // Left Side: Branding & Image (Desktop only)
          if (isDesktop)
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/auth_bg.webp', // Fallback to asset if exists, or use generated
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF060918), Color(0xFF1A1F24)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.art_track_rounded,
                          size: 100,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ),
                  Container(color: Colors.black.withOpacity(0.3)),
                  Padding(
                    padding: const EdgeInsets.all(64.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 48,
                          filterQuality: FilterQuality.high,
                        ),
                        // const Spacer(),
                        // Text(
                        //   'Capturing Moments,\nCreating Memories',
                        //   style: GoogleFonts.poppins(
                        //     fontSize: 48,
                        //     fontWeight: FontWeight.bold,
                        //     color: Colors.white,
                        //     letterSpacing: 2,
                        //   ),
                        // ),
                        // const SizedBox(height: 24),
                        // Text(
                        //   'The ultimate platform for XR Project Management',
                        //   style: GoogleFonts.poppins(
                        //     fontSize: 18,
                        //     color: Colors.white70,
                        //     letterSpacing: 1.2,
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Right Side: Login Form
          Expanded(
            flex: isDesktop ? 3 : 1,
            child: Container(
              color: isDark ? const Color(0xFF0B1221) : Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? size.width * 0.05 : 32,
              ),
              child: Center(
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isDesktop) ...[
                            Image.asset('assets/images/logo.png', height: 40),
                            const SizedBox(height: 48),
                          ],
                          Text(
                            'SIGN IN',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: isDark
                                  ? Colors.white
                                  : XRDockTheme.deepNavy,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: GoogleFonts.poppins(color: Colors.grey),
                              ),
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                                child: Text(
                                  'Register',
                                  style: TextStyle(
                                    color: XRDockTheme.secondaryPurple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 48),
                          Text(
                            'EMAIL ADDRESS',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              hintText: 'name@company.com',
                            ),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Valid email required'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'PASSWORD',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Min 6 characters'
                                : null,
                          ),
                          const SizedBox(height: 48),
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: Container(
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
                                          onPressed: _handleSmartSignIn,
                                          child: const Text('SIGN IN'),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    Row(
                                      children: [
                                        const Expanded(child: Divider()),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          child: Text(
                                            'OR LOGIN WITH',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              color: Colors.grey,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ),
                                        const Expanded(child: Divider()),
                                      ],
                                    ),
                                    const SizedBox(height: 32),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _SocialButton(
                                            assetPath:
                                                'assets/images/google_g.png',
                                            label: 'GOOGLE',
                                            onTap: _signInWithGoogle,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _SocialButton(
                                            assetPath:
                                                'assets/images/autodesk_logo.png',
                                            label: 'AUTODESK',
                                            onTap: _signInWithAutodesk,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 48),
                          Center(
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/subscribe'),
                              child: Text(
                                'CONTACT SALES / PRICING',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  letterSpacing: 1,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
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
}

class _SocialButton extends StatelessWidget {
  final String? assetPath;
  final String label;
  final VoidCallback onTap;

  const _SocialButton({
    this.assetPath,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (assetPath != null) Image.asset(assetPath!, height: 24),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: isDark ? Colors.white : XRDockTheme.deepNavy,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
