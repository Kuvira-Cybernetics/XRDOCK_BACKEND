import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../common/common.dart';
import '../widgets/floating_issue_overlay.dart';
import '../widgets/user_profile_card.dart';
import '../widgets/issue_list_panel.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class DashboardScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;

  const DashboardScreen({super.key, required this.onThemeToggle});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _projects = [];
  int? _selectedProjectId;
  String? _selectedModelFile;
  bool _isLoadingProjects = true;

  int _selectedIndex = 0; // 0: Spatial View, 1: Issues List
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    try {
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/projects'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _projects = data;
          if (_projects.isNotEmpty) {
            _selectedProjectId = _projects[0]['id'];
            _selectedModelFile = _projects[0]['model_filename'];
          }
          _isLoadingProjects = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      setState(() => _isLoadingProjects = false);
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Row(
        children: [
          // Premium Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _isCollapsed ? 80 : 280,
            decoration: BoxDecoration(
              color: isDark ? CommonData.panelBackground : Colors.white,
              border: Border(
                right: BorderSide(color: Colors.grey.withOpacity(0.1)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isCollapsed ? 8.0 : 16.0,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: _isCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceBetween,
                    children: [
                      if (!_isCollapsed)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            if (!_isCollapsed) ...[
                              const SizedBox(width: 12),
                              Text(
                                'XR-DOCK',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 3,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      IconButton(
                        icon: Icon(
                          _isCollapsed
                              ? Icons.chevron_right
                              : Icons.chevron_left,
                          size: 20,
                          color: Theme.of(context).primaryColor,
                        ),
                        onPressed: () =>
                            setState(() => _isCollapsed = !_isCollapsed),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
                UserProfileCard(isCollapsed: _isCollapsed),
                const SizedBox(height: 16),
                _SidebarItem(
                  icon: Icons.view_in_ar_outlined,
                  label: '3D SPATIAL VIEW',
                  isCollapsed: _isCollapsed,
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _SidebarItem(
                  icon: Icons.list_alt_rounded,
                  label: 'ISSUES MANAGEMENT',
                  isCollapsed: _isCollapsed,
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                if (!_isCollapsed && _projects.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'ACTIVE PROJECTS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.withOpacity(0.6),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._projects.map((project) {
                    final bool isProjectSelected =
                        _selectedProjectId == project['id'];
                    return _SidebarItem(
                      icon: Icons.architecture_rounded,
                      label: project['name'],
                      isCollapsed: _isCollapsed,
                      isSelected: isProjectSelected,
                      onTap: () => setState(() {
                        _selectedProjectId = project['id'];
                        _selectedModelFile = project['model_filename'];
                      }),
                    );
                  }).toList(),
                ],
                _SidebarItem(
                  icon: Icons.person_outline_rounded,
                  label: 'USER PROFILE',
                  isCollapsed: _isCollapsed,
                  isSelected: false,
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                ),
                const Spacer(),
                _SidebarItem(
                  icon: isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  label: isDark ? 'SWITCH TO LIGHT' : 'SWITCH TO DARK',
                  isCollapsed: _isCollapsed,
                  isSelected: false,
                  onTap: widget.onThemeToggle,
                ),
                if (!_isCollapsed)
                  const Divider(height: 1, indent: 24, endIndent: 24),
                _SidebarItem(
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
          // Main Content Viewport
          Expanded(
            child: Container(
              color: isDark
                  ? CommonData.darkBackground
                  : const Color(0xFFF8FAFC),
              child: _selectedIndex == 0
                  ? Stack(
                      children: [
                        if (_selectedModelFile != null)
                          ModelViewer(
                            key: ValueKey(_selectedProjectId),
                            backgroundColor: Colors.transparent,
                            src:
                                '${CommonData.backendUrl}/static/models/$_selectedModelFile',
                            alt: 'A 3D building model',
                            ar: false,
                            autoRotate: true,
                            cameraControls: true,
                          )
                        else if (_isLoadingProjects)
                          const Center(child: CircularProgressIndicator())
                        else
                          const Center(child: Text("No Project Selected")),
                        // if (_selectedProjectId != null)
                        //   FloatingIssueOverlay(projectId: _selectedProjectId!),
                        Positioned(
                          top: 24,
                          left: 24,
                          child: Chip(
                            label: const Text('LIVE SPATIAL DATA'),
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            labelStyle: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            side: BorderSide(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    )
                  : _selectedProjectId != null
                  ? IssueListPanel(projectId: _selectedProjectId!)
                  : const Center(child: Text("No Project Selected")),
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
  final bool isCollapsed;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color primaryColor = Theme.of(context).primaryColor;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 4 : 12,
        vertical: 4,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 8 : 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? primaryColor
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? primaryColor
                          : (isDark ? Colors.white70 : Colors.black54),
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
