import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../common/common.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = false;
  String? _loadingPlan;

  static const List<Map<String, dynamic>> plans = [
    {
      'id': 'basic',
      'name': 'BASIC',
      'price': '₹599',
      'period': '/month',
      'color': Color(0xFF4F9CF9),
      'icon': Icons.layers_outlined,
      'features': [
        '1-3 Active Projects',
        '3D Model Viewer',
        'Issue Tracking',
        'Email Support',
      ],
    },
    {
      'id': 'pro',
      'name': 'PRO',
      'price': '₹999',
      'period': '/month',
      'color': Color(0xFF00D4FF),
      'icon': Icons.rocket_launch_outlined,
      'features': [
        '10 Active Projects',
        '3D + AR Viewing',
        'Advanced Issue Tracking',
        'Team Collaboration (5 users)',
        'Priority Support',
      ],
      'recommended': true,
    },
    {
      'id': 'enterprise',
      'name': 'ENTERPRISE',
      'price': '₹1299',
      'period': '/month',
      'color': Color(0xFFB16CEA),
      'icon': Icons.business_outlined,
      'features': [
        'Unlimited Projects',
        '3D + AR + XR Viewing',
        'Full Issue Management Suite',
        'Unlimited Team Members',
        'SLA-backed Support',
        'Custom Integrations',
      ],
    },
  ];

  Future<void> _subscribe(String planId) async {
    // Check if user is logged in first
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        CommonData.showCustomSnackBar(
          context,
          'Please register or log in first to subscribe.',
          isError: true,
        );
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pushNamed(context, '/register');
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingPlan = planId;
    });

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse('${CommonData.backendUrl}/subscribe?plan=$planId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Subscribed to $planId plan! Welcome aboard 🚀',
          );
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        final body = json.decode(response.body);
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            body['detail'] ?? 'Subscription failed. Try again.',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CommonData.showCustomSnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
          _loadingPlan = null;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark
          ? CommonData.darkBackground
          : const Color(0xFFF0F4FF),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // const SizedBox(height: 40),
              // // Header
              // Text(
              //   'CHOOSE YOUR PLAN',
              //   style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              //     fontWeight: FontWeight.bold,
              //     letterSpacing: 4,
              //     color: Theme.of(context).primaryColor,
              //   ),
              // ),
              // const SizedBox(height: 8),
              // Text(
              //   'Unlock spatial intelligence for your projects',
              //   style: TextStyle(
              //     color: isDark ? Colors.white54 : Colors.black45,
              //     letterSpacing: 1,
              //   ),
              // ),
              // const SizedBox(height: 40),
              // // Plan Cards
              // Padding(
              //   padding: const EdgeInsets.symmetric(horizontal: 24),
              //   child: LayoutBuilder(
              //     builder: (context, constraints) {
              //       bool isWide = constraints.maxWidth > 700;
              //       return Flex(
              //         direction: isWide ? Axis.horizontal : Axis.vertical,
              //         mainAxisAlignment: MainAxisAlignment.center,
              //         crossAxisAlignment: CrossAxisAlignment.center,
              //         children: plans.map((plan) {
              //           final bool isRecommended = plan['recommended'] == true;
              //           final Color planColor = plan['color'] as Color;
              //           final bool isBusy =
              //               _isLoading && _loadingPlan == plan['id'];
              //           return Flexible(
              //             child: Container(
              //               margin: const EdgeInsets.all(12),
              //               constraints: isWide
              //                   ? const BoxConstraints(maxWidth: 320)
              //                   : const BoxConstraints(),
              //               decoration: BoxDecoration(
              //                 color: isDark
              //                     ? const Color(0xFF1A2035)
              //                     : Colors.white,
              //                 borderRadius: BorderRadius.circular(24),
              //                 border: Border.all(
              //                   color: isRecommended
              //                       ? planColor
              //                       : Colors.transparent,
              //                   width: 2,
              //                 ),
              //                 boxShadow: [
              //                   BoxShadow(
              //                     color: isRecommended
              //                         ? planColor.withOpacity(0.3)
              //                         : Colors.black.withOpacity(0.06),
              //                     blurRadius: isRecommended ? 30 : 12,
              //                     offset: const Offset(0, 6),
              //                   ),
              //                 ],
              //               ),
              //               child: Column(
              //                 crossAxisAlignment: CrossAxisAlignment.start,
              //                 children: [
              //                   if (isRecommended)
              //                     Container(
              //                       width: double.infinity,
              //                       padding: const EdgeInsets.symmetric(
              //                         vertical: 6,
              //                       ),
              //                       decoration: BoxDecoration(
              //                         color: planColor,
              //                         borderRadius: const BorderRadius.only(
              //                           topLeft: Radius.circular(22),
              //                           topRight: Radius.circular(22),
              //                         ),
              //                       ),
              //                       child: const Center(
              //                         child: Text(
              //                           'MOST POPULAR',
              //                           style: TextStyle(
              //                             color: Colors.black,
              //                             fontWeight: FontWeight.bold,
              //                             fontSize: 11,
              //                             letterSpacing: 2,
              //                           ),
              //                         ),
              //                       ),
              //                     ),
              //                   Padding(
              //                     padding: const EdgeInsets.all(24),
              //                     child: Column(
              //                       crossAxisAlignment:
              //                           CrossAxisAlignment.start,
              //                       children: [
              //                         Icon(
              //                           plan['icon'] as IconData,
              //                           color: planColor,
              //                           size: 32,
              //                         ),
              //                         const SizedBox(height: 12),
              //                         Text(
              //                           plan['name'] as String,
              //                           style: TextStyle(
              //                             fontWeight: FontWeight.bold,
              //                             letterSpacing: 3,
              //                             color: planColor,
              //                             fontSize: 14,
              //                           ),
              //                         ),
              //                         const SizedBox(height: 8),
              //                         Row(
              //                           crossAxisAlignment:
              //                               CrossAxisAlignment.end,
              //                           children: [
              //                             Text(
              //                               plan['price'] as String,
              //                               style: TextStyle(
              //                                 fontSize: 36,
              //                                 fontWeight: FontWeight.bold,
              //                                 color: isDark
              //                                     ? Colors.white
              //                                     : Colors.black87,
              //                               ),
              //                             ),
              //                             Padding(
              //                               padding: const EdgeInsets.only(
              //                                 bottom: 6,
              //                               ),
              //                               child: Text(
              //                                 plan['period'] as String,
              //                                 style: TextStyle(
              //                                   color: isDark
              //                                       ? Colors.white54
              //                                       : Colors.black45,
              //                                 ),
              //                               ),
              //                             ),
              //                           ],
              //                         ),
              //                         const SizedBox(height: 20),
              //                         ...(plan['features'] as List<String>).map(
              //                           (f) => Padding(
              //                             padding: const EdgeInsets.symmetric(
              //                               vertical: 4,
              //                             ),
              //                             child: Row(
              //                               children: [
              //                                 Icon(
              //                                   Icons.check_circle_outline,
              //                                   size: 16,
              //                                   color: planColor,
              //                                 ),
              //                                 const SizedBox(width: 8),
              //                                 Flexible(
              //                                   child: Text(
              //                                     f,
              //                                     style: const TextStyle(
              //                                       fontSize: 13,
              //                                     ),
              //                                   ),
              //                                 ),
              //                               ],
              //                             ),
              //                           ),
              //                         ),
              //                         const SizedBox(height: 24),
              //                         SizedBox(
              //                           width: double.infinity,
              //                           child: ElevatedButton(
              //                             onPressed: _isLoading
              //                                 ? null
              //                                 : () => _subscribe(
              //                                     plan['id'] as String,
              //                                   ),
              //                             style: ElevatedButton.styleFrom(
              //                               backgroundColor: planColor,
              //                               foregroundColor: Colors.black,
              //                               padding: const EdgeInsets.symmetric(
              //                                 vertical: 16,
              //                               ),
              //                               shape: RoundedRectangleBorder(
              //                                 borderRadius:
              //                                     BorderRadius.circular(12),
              //                               ),
              //                             ),
              //                             child: isBusy
              //                                 ? const SizedBox(
              //                                     height: 18,
              //                                     width: 18,
              //                                     child:
              //                                         CircularProgressIndicator(
              //                                           strokeWidth: 2,
              //                                           color: Colors.black,
              //                                         ),
              //                                   )
              //                                 : const Text(
              //                                     'GET STARTED',
              //                                     style: TextStyle(
              //                                       fontWeight: FontWeight.bold,
              //                                       letterSpacing: 2,
              //                                     ),
              //                                   ),
              //                           ),
              //                         ),
              //                       ],
              //                     ),
              //                   ),
              //                 ],
              //               ),
              //             ),
              //           );
              //         }).toList(),
              //       );
              //     },
              //   ),
              // ),
              const SizedBox(height: 30),
              // Contact Section
              Center(
                child: Text(
                  'Contact Section',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 800,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2035) : Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.grey.withOpacity(isDark ? 0.1 : 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'READY FOR ENTERPRISE?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Contact Our Sales Team',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Need a custom solution or 100+ seats? Tell us about your project and we\'ll build a plan just for you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 40),
                    _ContactForm(),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                child: Text(
                  'Already subscribed? Log In',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactForm extends StatefulWidget {
  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    try {
      final response = await http.post(
        Uri.parse('${CommonData.backendUrl}/contact'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'message': _messageController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          _nameController.clear();
          _emailController.clear();
          _messageController.clear();
          CommonData.showCustomSnackBar(
            context,
            data['message'] ?? 'Message sent successfully!',
          );
        }
      } else {
        throw 'Failed to send message';
      }
    } catch (e) {
      if (mounted) {
        CommonData.showCustomSnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NAME',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => v!.isEmpty ? 'Name required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WORK EMAIL',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => v!.isEmpty ? 'Email required' : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TELL US ABOUT YOUR NEEDS',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText:
                      'e.g. Number of seats, specific integrations required...',
                ),
                validator: (v) => v!.isEmpty ? 'Message required' : null,
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSending ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'SEND REQUEST',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
