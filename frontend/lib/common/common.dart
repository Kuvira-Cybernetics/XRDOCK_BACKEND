import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CommonData {
  // Backend Configuration

  static String get backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:8001';

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
  static String? localSyncPath;
  static String? bimUploadHubId;
  static String? bimUploadProjectId;
  static String? bimUploadFolderId;

  static bool showAllIssuesInDashboard = false;

  // Theme Variables
  static const Color primaryNeon = Color(0xFF00F2FF);
  static const Color darkBackground = Color(0xFF121212);
  static const Color glassmorphicBackground = Color(
    0x33FFFFFF,
  ); // 20% white for glass
  static const Color panelBackground = Color(0xFF1E1E1E);

  static bool isIntentionalLogout = false;

  static void showCustomSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isInfo = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    Color bgColor = Colors.green;
    IconData icon = Icons.check_circle_outline;

    if (isError) {
      bgColor = Colors.red;
      icon = Icons.error_outline;
    } else if (isInfo) {
      bgColor = Colors.blueAccent;
      icon = Icons.info_outline;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        width: 400,
      ),
    );
  }

  static Future<void> logout(
    BuildContext context, {
    bool sessionExpired = false,
  }) async {
    isIntentionalLogout = !sessionExpired;
    if (sessionExpired && context.mounted) {
      showCustomSnackBar(
        context,
        'Session expired. Please log in again.',
        isInfo: true,
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
    await FirebaseAuth.instance.signOut();
    if (!sessionExpired && context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}
