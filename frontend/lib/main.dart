import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/xrdock_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/admin_screen.dart';
import 'common/common.dart';
import 'widgets/main_layout.dart';

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Capture token from URL before the router strips it (especially for Web)
  final uri = Uri.base;
  String? token;
  if (uri.fragment.contains('token=')) {
    final fragmentParts = uri.fragment.split('?');
    if (fragmentParts.length > 1) {
      token = Uri.splitQueryString(fragmentParts.last)['token'];
    }
  } else if (uri.queryParameters.containsKey('token')) {
    token = uri.queryParameters['token'];
  }

  if (token != null) {
    debugPrint('MAIN: Captured token from startup: ${token.substring(0, 10)}...');
    CommonData.pendingAutodeskToken = token;
  }

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
      theme: XRDockTheme.lightTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoTransitionsBuilder(),
            TargetPlatform.iOS: NoTransitionsBuilder(),
            TargetPlatform.windows: NoTransitionsBuilder(),
            TargetPlatform.macOS: NoTransitionsBuilder(),
            TargetPlatform.linux: NoTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: XRDockTheme.darkTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: NoTransitionsBuilder(),
            TargetPlatform.iOS: NoTransitionsBuilder(),
            TargetPlatform.windows: NoTransitionsBuilder(),
            TargetPlatform.macOS: NoTransitionsBuilder(),
            TargetPlatform.linux: NoTransitionsBuilder(),
          },
        ),
      ),
      themeMode: _themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/subscribe': (context) => const SubscriptionScreen(),
        '/dashboard': (context) => MainLayout(
          onThemeToggle: _toggleTheme,
          child: const DashboardScreen(),
        ),
        '/profile': (context) => MainLayout(
          onThemeToggle: _toggleTheme,
          child: const ProfileScreen(),
        ),
        '/admin': (context) => MainLayout(
          onThemeToggle: _toggleTheme,
          child: const AdminScreen(),
        ),
      },
      onGenerateRoute: (settings) {
        // Handle routes with query parameters like "/login?token=..."
        final name = settings.name ?? '';
        if (name.startsWith('/login?') || name.startsWith('/?')) {
          return MaterialPageRoute(
            builder: (context) => const LoginScreen(),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
