import 'package:flutter/material.dart';

class CommonData {
  // Backend Configuration
  static const String backendUrl =
      'http://localhost:8001'; // Change for production

  // GOOGLE SIGN-IN CLIENT ID
  static const String googleClientId =
      '816583824921-cn0pkcpi5v94o41culkf2jnpjuhcipr5.apps.googleusercontent.com';

  // App-wide User State (Optional: could also stream from FirebaseAuth.instance)
  static String? currentUserId;
  static String? currentUserEmail;

  // Theme Variables
  static const Color primaryNeon = Color(0xFF00F2FF);
  static const Color darkBackground = Color(0xFF121212);
  static const Color glassmorphicBackground = Color(
    0x33FFFFFF,
  ); // 20% white for glass
  static const Color panelBackground = Color(0xFF1E1E1E);
}
