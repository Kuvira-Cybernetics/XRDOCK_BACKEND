import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../common/common.dart';
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
  Map<String, dynamic>? _selectedProject; // full project data for detail view
  bool _isLoadingProjects = true;
  bool _showProjectGallery = true; // default: show gallery
  bool _showAllIssues = false; // global all-projects issues view
  int _detailTab = 0; // 0: 3D viewer, 1: issues

  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _checkSubscriptionAndLoad();
  }

  Future<void> _checkSubscriptionAndLoad() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        final expiryStr = userData['subscription_expiry'];
        final isAdmin = userData['is_admin'] == true;
        if (!isAdmin && expiryStr != null) {
          final expiry = DateTime.parse(expiryStr).toLocal();
          if (DateTime.now().isAfter(expiry)) {
            // Plan expired — show dialog and logout
            if (mounted) {
              await showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => AlertDialog(
                  title: const Text('Subscription Expired'),
                  content: const Text(
                    'Your plan has expired. Please renew to continue.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _logout(force: true);
                      },
                      child: const Text('RENEW PLAN'),
                    ),
                  ],
                ),
              );
            }
            return;
          }
        } else if (!isAdmin && expiryStr == null) {
          // No plan at all — send to subscribe
          if (mounted) Navigator.pushReplacementNamed(context, '/subscribe');
          return;
        }
      }
    } catch (e) {
      debugPrint('Subscription check error: $e');
    }
    await _fetchProjects();
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

  void _openProject(Map<String, dynamic> project) {
    setState(() {
      _selectedProject = project;
      _selectedProjectId = project['id'] as int?;
      _selectedModelFile = project['model_filename'] as String?;
      _showProjectGallery = false;
      _detailTab = 0;
    });
  }

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
                // Logo / Collapse toggle
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isCollapsed ? 8.0 : 16.0,
                    vertical: 16,
                  ),
                  child: _isCollapsed
                      ? Center(
                          child: Tooltip(
                            message: 'Expand sidebar',
                            child: InkWell(
                              onTap: () => setState(() => _isCollapsed = false),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.menu_open,
                                  size: 22,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Image.asset(
                                'assets/images/logo.png',
                                height: 34,
                                errorBuilder: (_, __, ___) => Text(
                                  'XR-DOCK',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 3,
                                      ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.chevron_left,
                                size: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                              onPressed: () =>
                                  setState(() => _isCollapsed = true),
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                ),
                UserProfileCard(isCollapsed: _isCollapsed),
                const SizedBox(height: 16),
                _SidebarItem(
                  icon: Icons.folder_special_outlined,
                  label: 'PROJECTS',
                  isCollapsed: _isCollapsed,
                  isSelected: _showProjectGallery,
                  onTap: () => setState(() {
                    _showProjectGallery = true;
                    _showAllIssues = false;
                    _selectedProject = null;
                  }),
                ),
                _SidebarItem(
                  icon: Icons.list_alt_rounded,
                  label: 'ISSUES',
                  isCollapsed: _isCollapsed,
                  isSelected: _showAllIssues,
                  onTap: () => setState(() {
                    _showProjectGallery = false;
                    _showAllIssues = true;
                    _selectedProject = null;
                  }),
                ),
                _SidebarItem(
                  icon: Icons.person_outline_rounded,
                  label: 'PROFILE',
                  isCollapsed: _isCollapsed,
                  isSelected: false,
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                ),
                const Spacer(),
                if (_isCollapsed)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    height: 1,
                    color: Colors.grey.withOpacity(0.2),
                  ),
                _SidebarItem(
                  icon: isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  label: isDark ? 'LIGHT MODE' : 'DARK MODE',
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
              child: _showAllIssues
                  ? _buildAllIssuesView(isDark)
                  : _showProjectGallery
                  ? _buildProjectGallery(isDark)
                  : _selectedProject != null
                  ? _buildProjectDetail(isDark)
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 64,
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Select a project from the sidebar',
                            style: TextStyle(
                              color: Colors.grey,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectDetail(bool isDark) {
    final project = _selectedProject!;
    return Column(
      children: [
        // Header bar
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? CommonData.panelBackground : Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                onPressed: () => setState(() {
                  _showProjectGallery = true;
                  _selectedProject = null;
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (project['name'] as String).toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    fontSize: 14,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              // Tab buttons
              _DetailTab(
                icon: Icons.view_in_ar_outlined,
                label: '3D VIEW',
                isActive: _detailTab == 0,
                onTap: () => setState(() => _detailTab = 0),
              ),
              const SizedBox(width: 8),
              _DetailTab(
                icon: Icons.list_alt_rounded,
                label: 'ISSUES',
                isActive: _detailTab == 1,
                onTap: () => setState(() => _detailTab = 1),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _detailTab == 0
              ? Stack(
                  children: [
                    ModelViewer(
                      key: ValueKey(_selectedProjectId),
                      backgroundColor: Colors.transparent,
                      src:
                          '${CommonData.backendUrl}/static/models/$_selectedModelFile',
                      alt: project['name'],
                      ar: false,
                      autoRotate: true,
                      cameraControls: true,
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Chip(
                        label: const Text('LIVE 3D'),
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.1),
                        labelStyle: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        side: BorderSide(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ],
                )
              : IssueListPanel(projectId: _selectedProjectId!),
        ),
      ],
    );
  }

  Widget _buildAllIssuesView(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? CommonData.panelBackground : Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.list_alt_rounded,
                size: 18,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 10),
              Text(
                'ALL ISSUES',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontSize: 14,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() {
                  _showAllIssues = false;
                  _showProjectGallery = true;
                }),
                icon: const Icon(Icons.folder_open_outlined, size: 16),
                label: const Text('VIEW PROJECTS'),
              ),
            ],
          ),
        ),
        const Expanded(child: IssueListPanel()),
      ],
    );
  }

  Widget _buildProjectGallery(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROJECTS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              fontSize: 22,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a project to render in 3D',
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoadingProjects
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 280,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: _projects.length,
                    itemBuilder: (context, i) {
                      final project = _projects[i];
                      final isSelected = _selectedProjectId == project['id'];
                      final thumbnailUrl = project['thumbnail_url'];
                      return GestureDetector(
                        onTap: () => _openProject(
                          Map<String, dynamic>.from(project as Map),
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? Theme.of(
                                        context,
                                      ).primaryColor.withOpacity(0.35)
                                    : Colors.black.withOpacity(0.08),
                                blurRadius: isSelected ? 20 : 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (thumbnailUrl != null)
                                  Image.network(
                                    thumbnailUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: isDark
                                          ? const Color(0xFF1A2035)
                                          : Colors.grey.shade100,
                                      child: const Icon(
                                        Icons.broken_image_outlined,
                                        size: 40,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    color: isDark
                                        ? const Color(0xFF1A2035)
                                        : Colors.grey.shade100,
                                    child: Icon(
                                      Icons.view_in_ar_outlined,
                                      size: 40,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                // Dark gradient at bottom
                                Positioned.fill(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.7),
                                        ],
                                        stops: const [0.5, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 14,
                                  left: 14,
                                  right: 14,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (project['name'] as String)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          letterSpacing: 0.8,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).primaryColor,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Text(
                                            'ACTIVE',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        )
                                      else
                                        const Text(
                                          'TAP TO RENDER',
                                          style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 10,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
  final VoidCallback? onTap;

  const _SidebarItem({
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

    final item = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 4 : 12,
        vertical: 4,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0 : 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
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

    // Wrap collapsed icons in Tooltip so labels are still accessible
    if (isCollapsed) {
      return Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 400),
        child: item,
      );
    }
    return item;
  }
}

class _DetailTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _DetailTab({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color.withOpacity(0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isActive ? color : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? color : Colors.grey,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
