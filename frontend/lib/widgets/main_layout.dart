import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
  // Static so it persists across route changes (pushReplacementNamed rebuilds the widget).
  static bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _ensureUserHydrated();
  }

  Future<void> _ensureUserHydrated() async {
    if (CommonData.dbUser != null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        if (mounted) {
          setState(() {
            CommonData.dbUser = DBUser.fromJson(userData);
          });
        }
      }
    } catch (e) {
      debugPrint('MAIN_LAYOUT: Error hydrating user: $e');
    }
  }

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
                      child: ValueListenableBuilder<DBUser?>(
                        valueListenable: CommonData.userProfileNotifier,
                        builder: (context, dbUser, _) {
                          return ListView(
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
                              // Conditional Admin Modules
                              if (dbUser?.is_admin == true) ...[
                                _SidebarItem(
                                  icon: Icons.people_outline,
                                  label: 'USERS',
                                  isSelected:
                                      widget.currentRoute == '/admin/users',
                                  onTap: () => Navigator.pushReplacementNamed(
                                    context,
                                    '/admin/users',
                                  ),
                                  isCollapsed: _isCollapsed,
                                  isSpecial: true,
                                ),
                                _SidebarItem(
                                  icon: Icons.edit_note_rounded,
                                  label: 'DOCS MGMT',
                                  isSelected:
                                      widget.currentRoute == '/admin/docs',
                                  onTap: () => Navigator.pushReplacementNamed(
                                    context,
                                    '/admin/docs',
                                  ),
                                  isCollapsed: _isCollapsed,
                                  isSpecial: true,
                                ),
                              ],
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
                              _SidebarItem(
                                icon: Icons.help_outline_rounded,
                                label: 'HELP & SUPPORT',
                                isSelected: widget.currentRoute == '/support',
                                onTap: () => Navigator.pushReplacementNamed(
                                  context,
                                  '/support',
                                ),
                                isCollapsed: _isCollapsed,
                                isSpecial: true,
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Bottom Actions: Responsive Icon Layout
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _isCollapsed
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildThemeIcon(isDark),
                                  const SizedBox(height: 20),
                                  _buildLogoutIcon(),
                                ],
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildThemeIcon(isDark),
                                  Container(
                                    width: 1,
                                    height: 16,
                                    color: Colors.grey.withOpacity(0.2),
                                  ),
                                  _buildLogoutIcon(),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: IconButton(
                        onPressed: () =>
                            setState(() => _isCollapsed = !_isCollapsed),
                        icon: Icon(
                          _isCollapsed
                              ? Icons.chevron_right_rounded
                              : Icons.chevron_left_rounded,
                          color: Colors.grey.withOpacity(0.5),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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

  Widget _buildThemeIcon(bool isDark) {
    return Tooltip(
      message: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
      child: IconButton(
        icon: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          size: 20,
        ),
        color: isDark ? Colors.amber : Colors.indigoAccent,
        onPressed: () {
          CommonData.isDarkModeNotifier.value = !isDark;
        },
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildLogoutIcon() {
    return IconButton(
      icon: const Icon(Icons.logout_rounded, size: 18),
      color: Colors.redAccent,
      onPressed: _onLogout,
      tooltip: 'LOGOUT',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
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

    final itemWidget = Padding(
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

    // When the sidebar is collapsed, show a tooltip with the item label.
    // When expanded, labels are visible so no tooltip is needed.
    if (isCollapsed) {
      return Tooltip(
        message: label,
        preferBelow: false,
        verticalOffset: 8,
        child: itemWidget,
      );
    }
    return itemWidget;
  }
}
