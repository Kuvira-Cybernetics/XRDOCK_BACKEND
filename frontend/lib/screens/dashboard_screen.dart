import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../common/common.dart';
import '../widgets/user_profile_card.dart';
import '../widgets/issue_list_panel.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import '../widgets/autodesk_file_browser.dart';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  void _logout({bool force = false}) async {
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

  List<dynamic> _projects = [];
  int? _selectedProjectId;
  String? _selectedModelFile;
  Map<String, dynamic>? _selectedProject; // full project data for detail view
  bool _isLoadingProjects = true;
  int _detailTab = 0; // 0: 3D viewer, 1: issues

  bool get _showAllIssues => CommonData.showAllIssuesInDashboard;
  bool get _showProjectGallery =>
      !CommonData.showAllIssuesInDashboard && _selectedProject == null;

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

        // Sync user details to global state
        CommonData.currentUserName = userData['name'];
        CommonData.currentUserEmail = userData['email'];
        CommonData.currentUserId = userData['uid'];
        CommonData.isAutodeskUser =
            userData.containsKey('autodesk_id') &&
            userData['autodesk_id'] != null;

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
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/projects'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _projects = data;
          if (_projects.isNotEmpty && _selectedProject == null) {
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

  Future<void> _createProject(String name, PlatformFile? modelFile) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final body = {'name': name};
      final response = await http.post(
        Uri.parse('${CommonData.backendUrl}/projects'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        final newProject = jsonDecode(response.body);
        if (modelFile != null) {
          await _uploadModel(newProject['id'], modelFile);
        }
        if (mounted) {
          CommonData.showCustomSnackBar(context, 'Project created');
        }
        _fetchProjects();
      }
    } catch (e) {
      debugPrint('Error creating project: $e');
    }
  }

  Future<void> _uploadModel(int projectId, PlatformFile file) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${CommonData.backendUrl}/projects/$projectId/model'),
      );
      request.headers['Authorization'] = 'Bearer $token';

      if (file.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            file.bytes!,
            filename: file.name,
          ),
        );
      }

      var response = await request.send();
      if (response.statusCode != 200) {
        debugPrint('Model upload failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error uploading model: $e');
    }
  }

  Future<void> _deleteProject(int id) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.delete(
        Uri.parse('${CommonData.backendUrl}/projects/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (_selectedProjectId == id) {
          setState(() {
            _selectedProject = null;
            _selectedProjectId = null;
            _selectedModelFile = null;
          });
        }
        if (mounted) {
          CommonData.showCustomSnackBar(context, 'Project deleted');
        }
        _fetchProjects();
      }
    } catch (e) {
      debugPrint('Error deleting project: $e');
    }
  }

  Future<void> _updateProject(
    int id,
    String name,
    PlatformFile? modelFile,
  ) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final body = {'name': name};
      final response = await http.put(
        Uri.parse('${CommonData.backendUrl}/projects/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        if (modelFile != null) {
          await _uploadModel(id, modelFile);
        }
        if (_selectedProjectId == id && _selectedProject != null) {
          setState(() {
            _selectedProject!['name'] = name;
          });
        }
        if (mounted) {
          CommonData.showCustomSnackBar(context, 'Project updated');
        }
        _fetchProjects();
      }
    } catch (e) {
      debugPrint('Error updating project: $e');
    }
  }

  void _showCreateProjectDialog() {
    final nameCtrl = TextEditingController();
    PlatformFile? pickedFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Project Name'),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pickedFile?.name ?? 'No 3D model selected',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        debugPrint('Attempting to pick file...');
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['glb'],
                          withData: true,
                        );
                        if (result != null) {
                          debugPrint('File picked: ${result.files.first.name}');
                          setDialogState(() => pickedFile = result.files.first);
                        } else {
                          debugPrint('File picking cancelled.');
                        }
                      } catch (e) {
                        debugPrint('FilePicker error: $e');
                      }
                    },
                    child: const Text('SELECT .GLB'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  _createProject(nameCtrl.text.trim(), pickedFile);
                  Navigator.pop(context);
                }
              },
              child: const Text('CREATE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProjectDialog(Map<String, dynamic> project) {
    final nameCtrl = TextEditingController(text: project['name']);
    PlatformFile? pickedFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Project'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Project Name'),
                autofocus: true,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pickedFile?.name ?? 'Change 3D model (Optional)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        debugPrint('Attempting to pick file (edit)...');
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['glb'],
                          withData: true,
                        );
                        if (result != null) {
                          debugPrint(
                            'File picked (edit): ${result.files.first.name}',
                          );
                          setDialogState(() => pickedFile = result.files.first);
                        } else {
                          debugPrint('File picking (edit) cancelled.');
                        }
                      } catch (e) {
                        debugPrint('FilePicker error (edit): $e');
                      }
                    },
                    child: const Text('SELECT .GLB'),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  _updateProject(
                    project['id'],
                    nameCtrl.text.trim(),
                    pickedFile,
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAutodeskImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import from Autodesk'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: AutodeskFileBrowser(
            onFileSelected: (projectId, itemId, name) async {
              Navigator.pop(context);
              await _importAutodeskFile(projectId, itemId, name);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  Future<void> _importAutodeskFile(
    String projectId,
    String itemId,
    String name,
  ) async {
    try {
      setState(() => _isLoadingProjects = true);
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse('${CommonData.backendUrl}/autodesk/import'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'project_id': projectId,
          'item_id': itemId,
          'name': name,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          if (data['translation_status'] == 'already_imported') {
            CommonData.showCustomSnackBar(context, 'Synced');
          } else {
            CommonData.showCustomSnackBar(context, 'Synced');
          }
        }
        _fetchProjects();
      } else {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Import failed: ${response.statusCode}',
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error importing Autodesk file: $e');
      if (mounted) {
        CommonData.showCustomSnackBar(
          context,
          'An error occurred during import',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingProjects = false);
    }
  }

  void _openProject(Map<String, dynamic> project) {
    setState(() {
      _selectedProject = project;
      _detailTab = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? CommonData.darkBackground : const Color(0xFFF8FAFC),
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
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select a project from the sidebar',
                    style: TextStyle(color: Colors.grey, letterSpacing: 1),
                  ),
                ],
              ),
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
                  CommonData.showAllIssuesInDashboard = false;
                  _selectedProject = null;
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
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                if (CommonData.isAutodeskUser) ...[
                  ElevatedButton.icon(
                    onPressed: _showAutodeskImportDialog,
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('IMPORT FROM AUTODESK'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                ElevatedButton.icon(
                  onPressed: _showCreateProjectDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('NEW PROJECT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Select a project to render in 3D',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoadingProjects
                ? const Center(child: CircularProgressIndicator())
                : Scrollbar(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(32),
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
                                  ModelViewer(
                                    key: ValueKey('thumb_${project['id']}'),
                                    backgroundColor: isDark
                                        ? const Color(0xFF1A2035)
                                        : Colors.grey.shade100,
                                    src:
                                        '${CommonData.backendUrl}/static/models/${project['model_filename']}',
                                    alt: project['name'],
                                    ar: false,
                                    autoRotate: true,
                                    cameraControls:
                                        false, // strictly a thumbnail
                                    disableZoom: true,
                                    interactionPrompt: InteractionPrompt.none,
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
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
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
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(
                                                      context,
                                                    ).primaryColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    'ACTIVE',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            color: Colors.blueGrey,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            _showEditProjectDialog(
                                              Map<String, dynamic>.from(
                                                project as Map,
                                              ),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.redAccent,
                                            size: 20,
                                          ),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text(
                                                  'Delete Project?',
                                                ),
                                                content: const Text(
                                                  'This action cannot be undone. All issues associated with this project will also be deleted.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child: const Text('CANCEL'),
                                                  ),
                                                  ElevatedButton(
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.redAccent,
                                                        ),
                                                    onPressed: () {
                                                      Navigator.pop(ctx);
                                                      _deleteProject(
                                                        project['id'],
                                                      );
                                                    },
                                                    child: const Text(
                                                      'DELETE',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
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
