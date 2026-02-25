import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/xrdock_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Analytics is usually enabled by default; manual call was causing a crash on web
  runApp(const XRDockApp());
}

class XRDockApp extends StatefulWidget {
  const XRDockApp({super.key});

  @override
  State<XRDockApp> createState() => _XRDockAppState();
}

class _XRDockAppState extends State<XRDockApp> {
  ThemeMode _themeMode = ThemeMode.light; // Light mode default for user

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XR-DOCK BIM',
      debugShowCheckedModeBanner: false,
      theme: XRDockTheme.lightTheme,
      darkTheme: XRDockTheme.darkTheme,
      themeMode: _themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/dashboard': (context) => DashboardScreen(onThemeToggle: _toggleTheme),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
