import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/xrdock_theme.dart';

class DBUser {
  final String id;
  final String email;
  final String name;
  final bool is_admin;
  final String? job_title;
  final String? company_name;
  final String? autodesk_id;
  final String? autodesk_email;

  DBUser({
    required this.id,
    required this.email,
    required this.name,
    this.is_admin = false,
    this.job_title,
    this.company_name,
    this.autodesk_id,
    this.autodesk_email,
  });

  factory DBUser.fromJson(Map<String, dynamic> json) {
    return DBUser(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      is_admin: json['is_admin'] ?? false,
      job_title: json['job_title'],
      company_name: json['company_name'],
      autodesk_id: json['autodesk_id'],
      autodesk_email: json['autodesk_email'],
    );
  }
}

class CommonData {
  // Backend Configuration
  static String get backendUrl =>
      dotenv.env['BACKEND_URL'] ?? 'http://localhost:8001';

  // GOOGLE SIGN-IN CLIENT ID
  static const String googleClientId =
      '816583824921-cn0pkcpi5v94o41culkf2jnpjuhcipr5.apps.googleusercontent.com';

  // App-wide User State
  static String? currentUserId;
  static String? currentUserEmail;
  static String? currentUserName;
  static DBUser? dbUser;
  static bool isAutodeskUser = false;
  static String? pendingAutodeskToken;
  static String? localSyncPath;
  static String? bimUploadHubId;
  static String? bimUploadProjectId;
  static String? bimUploadFolderId;

  static final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(
    false,
  );

  // Compatibility Constants (Legacy)
  static const Color primaryNeon = Color(0xFF00F2FF);
  static const Color darkBackground = XRDockTheme.deepNavy;
  static const Color panelBackground = Color(0xFF1E1E1E);

  static bool showAllIssuesInDashboard = false;
  static bool isIntentionalLogout = false;

  static void showCustomSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
    bool isInfo = false,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Color bgColor = isError
        ? Colors.red
        : (isInfo ? Colors.blueAccent : Colors.green);
    IconData icon = isError
        ? Icons.error_outline
        : (isInfo ? Icons.info_outline : Icons.check_circle_outline);

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
    }
    await FirebaseAuth.instance.signOut();
    dbUser = null;
    currentUserId = null;
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }
}
