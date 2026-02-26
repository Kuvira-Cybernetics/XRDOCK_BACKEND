import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import '../common/common.dart';
import 'user_profile_card.dart';

class MainLayout extends StatefulWidget {
  final Widget child;
  final VoidCallback onThemeToggle;

  const MainLayout({
    super.key,
    required this.child,
    required this.onThemeToggle,
  });

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  static bool _isCollapsed = false; // Static to preserve state across route changes

  void _logout({bool force = false}) async {
    if (!force) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('LOG OUT'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    await FirebaseAuth.instance.signOut();
    
    // Clear global state
    CommonData.currentUserId = null;
    CommonData.currentUserEmail = null;
    CommonData.currentUserName = null;
    CommonData.pendingAutodeskToken = null;

    if (mounted) {
      if (kIsWeb) {
        html.window.history.replaceState(null, 'XR-DOCK', '/#/');
      }
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final currentRoute = ModalRoute.of(context)?.settings.name;

    return Scaffold(
      body: Row(
        children: [
          // Persistent Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isCollapsed ? 80 : 260,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1F24) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 20,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  child: _isCollapsed
                      ? GestureDetector(
                          onTap: () => setState(() => _isCollapsed = false),
                          child: Icon(Icons.menu_open, color: Theme.of(context).primaryColor),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                'XR-DOCK',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 3,
                                    ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_left, size: 20),
                              onPressed: () => setState(() => _isCollapsed = true),
                            ),
                          ],
                        ),
                ),
                UserProfileCard(isCollapsed: _isCollapsed),
                const SizedBox(height: 16),
                SidebarItem(
                  icon: Icons.folder_special_outlined,
                  label: 'PROJECTS',
                  isCollapsed: _isCollapsed,
                  isSelected: currentRoute == '/dashboard' && !CommonData.showAllIssuesInDashboard,
                  onTap: () {
                    setState(() => CommonData.showAllIssuesInDashboard = false);
                    if (currentRoute != '/dashboard') {
                      Navigator.pushReplacementNamed(context, '/dashboard');
                    }
                  },
                ),
                SidebarItem(
                  icon: Icons.list_alt_rounded,
                  label: 'ISSUES',
                  isCollapsed: _isCollapsed,
                  isSelected: currentRoute == '/dashboard' && CommonData.showAllIssuesInDashboard,
                  onTap: () {
                    setState(() => CommonData.showAllIssuesInDashboard = true);
                    if (currentRoute != '/dashboard') {
                      Navigator.pushReplacementNamed(context, '/dashboard');
                    }
                  },
                ),
                SidebarItem(
                  icon: Icons.person_outline_rounded,
                  label: 'PROFILE',
                  isCollapsed: _isCollapsed,
                  isSelected: currentRoute == '/profile',
                  onTap: () {
                    if (currentRoute != '/profile') {
                      Navigator.pushNamed(context, '/profile');
                    }
                  },
                ),
                const Spacer(),
                SidebarItem(
                  icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  label: isDark ? 'LIGHT MODE' : 'DARK MODE',
                  isCollapsed: _isCollapsed,
                  isSelected: false,
                  onTap: widget.onThemeToggle,
                ),
                if (!_isCollapsed)
                  const Divider(height: 1, indent: 24, endIndent: 24),
                SidebarItem(
                  icon: Icons.logout_rounded,
                  label: 'LOG OUT',
                  isCollapsed: _isCollapsed,
                  isSelected: false,
                  onTap: _logout,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // Main Content Area (Child)
          Expanded(
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback? onTap;

  const SidebarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isCollapsed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 4 : 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? primaryColor : (isDark ? Colors.white70 : Colors.black54),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? primaryColor : (isDark ? Colors.white70 : Colors.black54),
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
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
