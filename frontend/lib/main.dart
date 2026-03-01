import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme/xrdock_theme.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
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

  const String environment = String.fromEnvironment('ENV', defaultValue: 'dev');
  debugPrint('MAIN: Loading environment configs for: $environment');
  await dotenv.load(fileName: ".env.$environment");

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
    debugPrint(
      'MAIN: Captured token from startup: ${token.substring(0, 10)}...',
    );
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
      title: 'XR-DOCK',
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
        '/': (context) => AuthWrapper(onThemeToggle: _toggleTheme),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/subscribe': (context) => const SubscriptionScreen(),
        '/dashboard': (context) =>
            MainLayout(onThemeToggle: _toggleTheme, child: DashboardScreen()),
        '/issues': (context) =>
            MainLayout(onThemeToggle: _toggleTheme, child: DashboardScreen()),
        '/profile': (context) =>
            MainLayout(onThemeToggle: _toggleTheme, child: ProfileScreen()),
        '/settings': (context) =>
            MainLayout(onThemeToggle: _toggleTheme, child: SettingsScreen()),
        '/admin': (context) =>
            MainLayout(onThemeToggle: _toggleTheme, child: AdminScreen()),
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

class AuthWrapper extends StatelessWidget {
  final VoidCallback onThemeToggle;
  const AuthWrapper({super.key, required this.onThemeToggle});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While checking auth state, optionally show a loader
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If a user is actively signed in, route directly to Dashboard
        if (snapshot.hasData && snapshot.data != null) {
          return MainLayout(
            onThemeToggle: onThemeToggle,
            child: DashboardScreen(),
          );
        }

        // Otherwise, show Login Screen
        return const LoginScreen();
      },
    );
  }
}
