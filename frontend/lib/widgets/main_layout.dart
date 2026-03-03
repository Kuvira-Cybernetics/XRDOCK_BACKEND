import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../common/common.dart';
import '../theme/xrdock_theme.dart';
import 'user_profile_card.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final String currentRoute;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  bool _isCollapsed = false;

  void _onLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'LOGOUT',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: XRDockTheme.primaryPurple,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      CommonData.logout(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dbUser = CommonData.dbUser;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isCollapsed ? 80 : 280,
            decoration: BoxDecoration(
              color: isDark ? XRDockTheme.deepNavy : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(5, 0),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Glassmorphism effect for Dark Mode
                if (isDark)
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(color: Colors.white.withOpacity(0.02)),
                    ),
                  ),

                Column(
                  children: [
                    // Brand / Logo
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32,
                        horizontal: 20,
                      ),
                      child: Row(
                        children: [
                          !_isCollapsed
                              ? Center(
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    height: 28,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/sidebar_logo.png',
                                  height: 28,
                                ),
                        ],
                      ),
                    ),

                    // User Profile
                    UserProfileCard(isCollapsed: _isCollapsed),
                    const SizedBox(height: 32),

                    // Menu Items
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _SidebarItem(
                            icon: Icons.dashboard_outlined,
                            label: 'PROJECTS',
                            isSelected: widget.currentRoute == '/dashboard',
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              '/dashboard',
                            ),
                            isCollapsed: _isCollapsed,
                          ),
                          _SidebarItem(
                            icon: Icons.bug_report_outlined,
                            label: 'ISSUES',
                            isSelected: widget.currentRoute == '/issues',
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              '/issues',
                            ),
                            isCollapsed: _isCollapsed,
                          ),
                          // Conditional Admin Module
                          if (dbUser?.is_admin == true)
                            _SidebarItem(
                              icon: Icons.people_outline,
                              label: 'USERS',
                              isSelected: widget.currentRoute == '/admin/users',
                              onTap: () => Navigator.pushReplacementNamed(
                                context,
                                '/admin/users',
                              ),
                              isCollapsed: _isCollapsed,
                              isSpecial: true,
                            ),
                          _SidebarItem(
                            icon: Icons.person_outline,
                            label: 'PROFILE',
                            isSelected: widget.currentRoute == '/profile',
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              '/profile',
                            ),
                            isCollapsed: _isCollapsed,
                          ),
                          _SidebarItem(
                            icon: Icons.settings_outlined,
                            label: 'SETTINGS',
                            isSelected: widget.currentRoute == '/settings',
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              '/settings',
                            ),
                            isCollapsed: _isCollapsed,
                          ),
                        ],
                      ),
                    ),

                    // Bottom Actions
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          _SidebarItem(
                            icon: isDark
                                ? Icons.light_mode_outlined
                                : Icons.dark_mode_outlined,
                            label: isDark ? 'LIGHT MODE' : 'DARK MODE',
                            isSelected: false,
                            onTap: () {
                              final currentMode =
                                  CommonData.isDarkModeNotifier.value
                                  ? ThemeMode.dark
                                  : ThemeMode.light;
                              CommonData.isDarkModeNotifier.value =
                                  (currentMode == ThemeMode.light);
                            },
                            isCollapsed: _isCollapsed,
                          ),
                          _SidebarItem(
                            icon: Icons.logout_rounded,
                            label: 'LOGOUT',
                            isSelected: false,
                            onTap: _onLogout,
                            isCollapsed: _isCollapsed,
                          ),
                          const SizedBox(height: 16),
                          IconButton(
                            onPressed: () =>
                                setState(() => _isCollapsed = !_isCollapsed),
                            icon: Icon(
                              _isCollapsed
                                  ? Icons.chevron_right_rounded
                                  : Icons.chevron_left_rounded,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Container(
              color: isDark
                  ? XRDockTheme.deepNavy.withOpacity(0.95)
                  : const Color(0xFFF8FAFC),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isCollapsed;
  final bool isSpecial;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isCollapsed,
    this.isSpecial = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isSelected ? XRDockTheme.purpleGradient : null,
            boxShadow: isSelected && isDark
                ? [
                    BoxShadow(
                      color: XRDockTheme.primaryPurple.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isSpecial ? XRDockTheme.accentLavender : Colors.grey),
                size: 20,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 16),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : XRDockTheme.deepNavy),
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    letterSpacing: 1.1,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
