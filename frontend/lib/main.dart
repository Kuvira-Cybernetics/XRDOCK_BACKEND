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
import 'screens/admin_users_screen.dart';
import 'screens/admin_docs_screen.dart';
import 'screens/help_support_screen.dart';
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

class XRDockApp extends StatelessWidget {
  const XRDockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CommonData.isDarkModeNotifier,
      builder: (context, isDark, child) {
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
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthWrapper(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/subscribe': (context) => const SubscriptionScreen(),
            '/dashboard': (context) => const MainLayout(
              currentRoute: '/dashboard',
              child: DashboardScreen(),
            ),
            '/issues': (context) => const MainLayout(
              currentRoute: '/issues',
              child: DashboardScreen(),
            ), // Note: usually goes to a separate IssuesScreen or Tab
            '/profile': (context) => const MainLayout(
              currentRoute: '/profile',
              child: ProfileScreen(),
            ),
            '/settings': (context) => const MainLayout(
              currentRoute: '/settings',
              child: SettingsScreen(),
            ),
            '/admin/users': (context) => const MainLayout(
              currentRoute: '/admin/users',
              child: UsersScreen(),
            ),
            '/admin': (context) =>
                const MainLayout(currentRoute: '/admin', child: AdminScreen()),
            '/admin/docs': (context) => const MainLayout(
              currentRoute: '/admin/docs',
              child: AdminDocsScreen(),
            ),
            '/support': (context) => const MainLayout(
              currentRoute: '/support',
              child: HelpSupportScreen(),
            ),
          },
          onGenerateRoute: (settings) {
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
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          // Need to fetch DB user profile here or in Dashboard
          return const MainLayout(
            currentRoute: '/dashboard',
            child: DashboardScreen(),
          );
        }
        return const LoginScreen();
      },
    );
  }
}
