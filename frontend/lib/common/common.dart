import 'package:flutter/material.dart';

class CommonData {
  // Backend Configuration

  //Dev
  // static const String backendUrl =
  //     'http://localhost:8001'; // Change for production

  //Prod
  static const String backendUrl = 'https://api.xrdock.in';

  // GOOGLE SIGN-IN CLIENT ID
  static const String googleClientId =
      '816583824921-cn0pkcpi5v94o41culkf2jnpjuhcipr5.apps.googleusercontent.com';

  // App-wide User State (Optional: could also stream from FirebaseAuth.instance)
  static String? currentUserId;
  static String? currentUserEmail;
  static String? currentUserName;
  static bool isAutodeskUser =
      false; // Whether the user has a linked Autodesk account
  static String? pendingAutodeskToken; // For deep-link capture

  static bool showAllIssuesInDashboard = false;

  // Theme Variables
  static const Color primaryNeon = Color(0xFF00F2FF);
  static const Color darkBackground = Color(0xFF121212);
  static const Color glassmorphicBackground = Color(
    0x33FFFFFF,
  ); // 20% white for glass
  static const Color panelBackground = Color(0xFF1E1E1E);

  static void showCustomSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        width: 400,
      ),
    );
  }
}
