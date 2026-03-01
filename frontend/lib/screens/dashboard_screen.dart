import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../common/common.dart';
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
    await CommonData.logout(context, sessionExpired: force);

    // Clear global state
    CommonData.currentUserId = null;
    CommonData.currentUserEmail = null;
    CommonData.currentUserName = null;
    CommonData.pendingAutodeskToken = null;

    // Routing handled seamlessly via AuthWrapper stream emit.
    // Ensure URL matches for web explicitly if needed.
    if (mounted && kIsWeb) {
      html.window.history.replaceState(null, 'XR-DOCK', '/#/');
    }
  }

  List<dynamic> _projects = [];
  List<dynamic> _localProjects = [];
  int? _selectedProjectId;
  String? _selectedModelFile;
  Map<String, dynamic>? _selectedProject; // full project data for detail view
  Map<String, dynamic>? _selectedLocalProject;
  bool _isLoadingProjects = true;
  int _detailTab = 0; // 0: 3D viewer, 1: metadata, 2: issues
  int _localDetailTab = 0; // 0: metadata, 1: issues
  int _galleryTab = 0; // 0: Local, 1: BIM (only if Autodesk user)
  final Set<int> _loadingCloudProjectIds = {};
  final Set<String> _uploadingLocalProjectNames = {};
  bool get _showAllIssues {
    if (!mounted) return false;
    final currentRoute = ModalRoute.of(context)?.settings.name;
    return currentRoute == '/issues';
  }

  bool get _showProjectGallery =>
      !_showAllIssues &&
      _selectedProject == null &&
      _selectedLocalProject == null;

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
      if (response.statusCode == 401) {
        _logout(force: true);
        return;
      }
      if (response.statusCode == 200) {
        final userData = json.decode(response.body);

        // Sync user details to global state
        CommonData.currentUserName = userData['name'];
        CommonData.currentUserEmail = userData['email'];
        CommonData.currentUserId = userData['uid'];
        CommonData.isAutodeskUser =
            userData.containsKey('autodesk_id') &&
            userData['autodesk_id'] != null;

        CommonData.localSyncPath = userData['local_sync_path'];
        CommonData.bimUploadHubId = userData['bim_upload_hub_id'];
        CommonData.bimUploadProjectId = userData['bim_upload_project_id'];
        CommonData.bimUploadFolderId = userData['bim_upload_folder_id'];

        /* 
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
        }
        final expiryStr = userData['subscription_expiry'];
        final isAdmin = userData['is_admin'] == true;
        if (!isAdmin && expiryStr == null) {
          // No plan at all — send to subscribe
          if (mounted) Navigator.pushReplacementNamed(context, '/subscribe');
          return;
        }
        */
      }
    } catch (e) {
      debugPrint('Subscription check error: $e');
    }
    await _fetchProjects();
  }

  Future<void> _fetchProjects() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();

      // Fetch BIM / Cloud Projects
      final responseBim = await http.get(
        Uri.parse('${CommonData.backendUrl}/projects'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (responseBim.statusCode == 401) {
        _logout(force: true);
        return;
      }
      if (responseBim.statusCode == 200) {
        final data = json.decode(responseBim.body);
        if (mounted) {
          setState(() {
            _projects = data;
            if (_projects.isNotEmpty && _selectedProject == null) {
              // Only auto-select if we are on the BIM tab, or just select first cloud project
              _selectedProjectId = _projects[0]['id'];
              _selectedModelFile = _projects[0]['model_filename'];
            }
          });
        }
      }

      // Fetch Local Projects (Unsynced directories)
      final responseLocal = await http.get(
        Uri.parse('${CommonData.backendUrl}/projects/local'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (responseLocal.statusCode == 401) {
        _logout(force: true);
        return;
      }
      if (responseLocal.statusCode == 200) {
        if (mounted) {
          setState(() {
            _localProjects = json.decode(responseLocal.body);
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProjects = false);
    }
  }

  Future<void> _uploadLocalProject(
    String projectName,
    String projectPath,
  ) async {
    setState(() => _uploadingLocalProjectNames.add(projectName));
    try {
      if (mounted) {
        CommonData.showCustomSnackBar(
          context,
          'Uploading $projectName to cloud...',
        );
      }
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final body = {'name': projectName, 'path': projectPath};
      final response = await http.post(
        Uri.parse('${CommonData.backendUrl}/projects/upload_local'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            '$projectName uploaded successfully!',
          );
        }
        // Refresh lists
        _fetchProjects();
      } else {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Failed to upload: ${response.statusCode}',
            isError: true,
          );
        }
      }
    } finally {
      if (mounted)
        setState(() => _uploadingLocalProjectNames.remove(projectName));
    }
  }

  Future<void> _uploadAutodeskFile() async {
    String? localPath;
    if (!kIsWeb) {
      try {
        localPath = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Select Folder to Upload',
        );
      } catch (e) {
        if (mounted)
          CommonData.showCustomSnackBar(
            context,
            'Error picking folder: $e',
            isError: true,
          );
        return;
      }
    } else {
      try {
        final uploadInput = html.FileUploadInputElement();
        uploadInput.setAttribute('webkitdirectory', '');
        uploadInput.setAttribute('directory', '');
        uploadInput.multiple = true;

        uploadInput.click();

        await uploadInput.onChange.first;
        final files = uploadInput.files;
        if (files == null || files.isEmpty) return;

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Select Autodesk Destination'),
              content: SizedBox(
                width: 600,
                height: 500,
                child: AutodeskFileBrowser(
                  allowFolderSelection: true,
                  onFolderSelected:
                      (
                        hubId,
                        hubName,
                        projectId,
                        projectName,
                        folderId,
                        folderName,
                      ) async {
                        Navigator.pop(ctx);
                        await _performWebAutodeskFolderUpload(
                          files,
                          projectId,
                          folderId,
                        );
                      },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL'),
                ),
              ],
            ),
          );
        }
        return; // Early return for web flow
      } catch (e) {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Error picking folder: $e',
            isError: true,
          );
        }
        return;
      }
    }

    if (localPath == null || localPath.isEmpty) return;

    // Now ask for the target Autodesk folder
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Autodesk Destination'),
        content: SizedBox(
          width: 600,
          height: 500,
          child: AutodeskFileBrowser(
            allowFolderSelection: true,
            onFolderSelected:
                (
                  hubId,
                  hubName,
                  projectId,
                  projectName,
                  folderId,
                  folderName,
                ) async {
                  Navigator.pop(ctx);
                  await _performAutodeskFolderUpload(
                    localPath!,
                    projectId,
                    folderId,
                  );
                },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAutodeskFolderUpload(
    String localPath,
    String projectId,
    String folderId,
  ) async {
    setState(() {
      _isLoadingProjects = true;
    });

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final body = {
        'local_path': localPath,
        'project_id': projectId,
        'folder_id': folderId,
      };

      final response = await http.post(
        Uri.parse('${CommonData.backendUrl}/autodesk/upload_local_folder'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Successfully uploaded folder to Autodesk Cloud',
          );
        }
      } else {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Upload failed: ${response.body}',
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading to Autodesk: $e');
      if (mounted) {
        CommonData.showCustomSnackBar(
          context,
          'An error occurred during upload',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
        });
      }
    }
  }

  Future<void> _performWebAutodeskFolderUpload(
    List<html.File> files,
    String projectId,
    String baseFolderId,
  ) async {
    setState(() {
      _isLoadingProjects = true;
    });

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token == null) return;

      if (mounted) {
        CommonData.showCustomSnackBar(
          context,
          'Creating folder structure...',
          isInfo: true,
        );
      }

      // 1. Gather relative paths
      final Set<String> paths = {};
      for (final file in files) {
        String path = file.relativePath ?? '';
        if (path.isEmpty || path == 'null') {
          try {
            path = (file as dynamic).webkitRelativePath?.toString() ?? '';
          } catch (_) {}
        }
        if (path.isNotEmpty) {
          final parts = path.split('/');
          if (parts.length > 1) {
            final dirPath = parts.sublist(0, parts.length - 1).join('/');
            paths.add(dirPath);
          }
        }
      }

      // 2. Ask backend to bulk create folders
      final structureBody = {
        'project_id': projectId,
        'base_folder_id': baseFolderId,
        'paths': paths.toList(),
      };

      final structureResponse = await http.post(
        Uri.parse('${CommonData.backendUrl}/autodesk/create_folder_structure'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(structureBody),
      );

      if (structureResponse.statusCode != 200) {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Failed to create folder structure: ${structureResponse.body}',
            isError: true,
          );
        }
        return;
      }

      final folderMap =
          json.decode(structureResponse.body)['folder_map']
              as Map<String, dynamic>;

      if (mounted) {
        CommonData.showCustomSnackBar(
          context,
          'Uploading ${files.length} files...',
          isInfo: true,
        );
      }

      // 3. Upload files individually
      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < files.length; i++) {
        final file = files[i];
        String path = file.relativePath ?? '';
        if (path.isEmpty || path == 'null') {
          try {
            path = (file as dynamic).webkitRelativePath?.toString() ?? '';
          } catch (_) {}
        }

        String targetFolderId = baseFolderId;
        if (path.isNotEmpty) {
          final parts = path.split('/');
          if (parts.length > 1) {
            final dirPath = parts.sublist(0, parts.length - 1).join('/');
            targetFolderId = folderMap[dirPath] ?? baseFolderId;
          }
        }

        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${CommonData.backendUrl}/autodesk/upload'),
        );
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['project_id'] = projectId;
        request.fields['folder_id'] = targetFolderId;

        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoad.first;
        final bytes = reader.result as Uint8List;

        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: file.name),
        );

        final response = await request.send();
        if (response.statusCode == 200) {
          successCount++;
        } else {
          failCount++;
          debugPrint('Failed to upload ${file.name}: ${response.statusCode}');
        }
      }

      if (mounted) {
        if (failCount == 0) {
          CommonData.showCustomSnackBar(
            context,
            'Successfully uploaded folder with $successCount files to Autodesk Cloud',
          );
        } else {
          CommonData.showCustomSnackBar(
            context,
            'Uploaded $successCount files, but $failCount failed',
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading to Autodesk via web: $e');
      if (mounted) {
        CommonData.showCustomSnackBar(
          context,
          'An error occurred during web upload',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProjects = false;
        });
      }
    }
  }

  void _openProject(Map<String, dynamic> project) {
    setState(() {
      _selectedProject = project;
      _selectedProjectId = project['id'];
      _selectedModelFile = project['model_filename'];
      _detailTab =
          (_selectedModelFile != null && _selectedModelFile!.isNotEmpty)
          ? 0
          : 1;
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
          : _selectedLocalProject != null
          ? _buildLocalProjectDetail(isDark)
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
              if (_selectedModelFile != null && _selectedModelFile!.isNotEmpty)
                _DetailTab(
                  icon: Icons.view_in_ar_outlined,
                  label: '3D VIEW',
                  isActive: _detailTab == 0,
                  onTap: () => setState(() => _detailTab = 0),
                ),
              const SizedBox(width: 8),
              _DetailTab(
                icon: Icons.data_object,
                label: 'METADATA',
                isActive: _detailTab == 1,
                onTap: () => setState(() => _detailTab = 1),
              ),
              const SizedBox(width: 8),
              _DetailTab(
                icon: Icons.list_alt_rounded,
                label: 'ISSUES',
                isActive: _detailTab == 2,
                onTap: () => setState(() => _detailTab = 2),
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
              : _detailTab == 1
              ? _buildProjectMetadataView(project, isDark)
              : IssueListPanel(projectId: _selectedProjectId!),
        ),
      ],
    );
  }

  Widget _buildProjectMetadataView(Map<String, dynamic> project, bool isDark) {
    // Defines the fields to show and their labels
    final metadataFields = [
      {'key': 'loaded_model_offset_position', 'label': 'Model Offset Position'},
      {'key': 'loaded_model_offset_rotation', 'label': 'Model Offset Rotation'},
      {'key': 'loaded_model_offset_scale', 'label': 'Model Offset Scale'},
      {'key': 'vrmenu_model_position', 'label': 'VR Menu Model Position'},
      {'key': 'vrmenu_model_scale', 'label': 'VR Menu Model Scale'},
      {'key': 'created_model_center', 'label': 'Created Model Center'},
      {'key': 'teleport_last_index', 'label': 'Teleport Last Index'},
      {'key': 'ruler_last_index', 'label': 'Ruler Last Index'},
      {'key': 'marker_issue_last_index', 'label': 'Marker Issue Last Index'},
      {'key': 'marker_lable_last_index', 'label': 'Marker Label Last Index'},
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'UNITY SPATIAL DATA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2328) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: Column(
            children: metadataFields.map((field) {
              final value = project[field['key']];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        field['label']!,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        value != null ? value.toString() : 'Not Set',
                        style: TextStyle(
                          color: value != null
                              ? (isDark ? Colors.white : Colors.black)
                              : Colors.grey,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'COMPLEX ARRAYS / PATHS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildCodeBlock(
          'List_Of_Teleport_Locations',
          project['list_of_teleport_locations'],
          isDark,
        ),
        _buildCodeBlock('List_Of_Rules', project['list_of_rules'], isDark),
        // Visualized AR Locations
        _buildDataList(
          'AR LOCATIONS',
          project['list_of_ar_location_file_path'],
          isDark,
          Icons.location_on,
        ),
        // Visualized Marker Issues
        _buildDataList(
          'MARKER ISSUES',
          project['list_of_marker_issue'],
          isDark,
          Icons.report_problem,
        ),
        _buildCodeBlock(
          'List_Of_Marker_Lable',
          project['list_of_marker_lable'],
          isDark,
        ),
        _buildCodeBlock(
          'List_Of_Custom_Model_Data',
          project['list_of_custom_model_data'],
          isDark,
        ),
        _buildCodeBlock(
          'List_Of_Custom_Model_XrPath',
          project['list_of_custom_model_xrpath'],
          isDark,
        ),
        _buildCodeBlock(
          'Project_geometry_Path',
          project['project_geometry_path'],
          isDark,
        ),
        _buildCodeBlock(
          'Project_material_Path',
          project['project_material_path'],
          isDark,
        ),
        _buildCodeBlock(
          'Project_udata_Path',
          project['project_udata_path'],
          isDark,
        ),
        const SizedBox(height: 48),
        Text(
          'PROJECT ISSUES',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 600, // Fixed height for embedded panel
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2328) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IssueListPanel(projectId: project['id']),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeBlock(String title, dynamic data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF15191C) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Text(
              data != null && data.toString().isNotEmpty
                  ? data.toString()
                  : '[]',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isDark ? Colors.greenAccent[100] : Colors.green[800],
              ),
            ),
          ),
        ],
      ),
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
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/dashboard'),
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

                Container(
                  height: 40,
                  margin: const EdgeInsets.only(left: 32),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2328) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildGalleryTab('LOCAL', 0, isDark),
                      _buildGalleryTab(
                        CommonData.isAutodeskUser ? 'BIM' : 'CLOUD',
                        1,
                        isDark,
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                if (CommonData.isAutodeskUser && _galleryTab == 1) ...[
                  ElevatedButton.icon(
                    onPressed: _uploadAutodeskFile,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('UPLOAD TO AUTODESK'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _galleryTab == 0
                  ? 'Select a local project to render in 3D'
                  : (CommonData.isAutodeskUser
                        ? 'Select an Autodesk BIM project to browse and download'
                        : 'Select a cloud project to render in 3D'),
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black45),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoadingProjects
                ? const Center(child: CircularProgressIndicator())
                : _galleryTab == 0
                ? _buildLocalProjectsGrid(isDark)
                : (CommonData.isAutodeskUser
                      ? _buildAutodeskHubView(isDark)
                      : _buildCloudProjectsGrid(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryTab(String title, int index, bool isDark) {
    bool isSelected = _galleryTab == index;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _galleryTab = index;
            // Unselect project when switching tabs
            _selectedProject = null;
            _selectedProjectId = null;
            _selectedModelFile = null;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[400] : Colors.grey[700]),
            fontSize: 13,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildLocalProjectDetail(bool isDark) {
    if (_selectedLocalProject == null) return const SizedBox.shrink();
    final project = _selectedLocalProject!;

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
                  _selectedLocalProject = null;
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
              const Spacer(),
              if (project['is_uploaded'] == true) ...[
                ElevatedButton.icon(
                  onPressed:
                      _uploadingLocalProjectNames.contains(project['name'])
                      ? null
                      : () => _uploadLocalProject(
                          project['name'],
                          project['path'],
                        ),
                  icon: _uploadingLocalProjectNames.contains(project['name'])
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 16),
                  label: Text(
                    _uploadingLocalProjectNames.contains(project['name'])
                        ? "SYNCING..."
                        : "SYNC CHANGES",
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    foregroundColor: Colors.blue,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              _DetailTab(
                icon: Icons.data_object,
                label: 'METADATA',
                isActive: _localDetailTab == 0,
                onTap: () => setState(() => _localDetailTab = 0),
              ),
              const SizedBox(width: 8),
              _DetailTab(
                icon: Icons.list_alt_rounded,
                label: 'ISSUES',
                isActive: _localDetailTab == 1,
                onTap: () => setState(() => _localDetailTab = 1),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: Container(
            color: isDark ? CommonData.darkBackground : const Color(0xFFF1F5F9),
            child: _localDetailTab == 0
                ? ListView(
                    padding: const EdgeInsets.all(40),
                    children: [_buildLocalDetailBody(isDark, project)],
                  )
                : IssueListPanel(
                    localIssues:
                        (project['project_data']
                            as Map<String, dynamic>?)?['List_Of_Marker_Issue'],
                  ),
          ),
        ),
      ],
    );
  }

  String _formatVec3(dynamic vec) {
    if (vec is Map) {
      double x = (vec['x'] is num) ? (vec['x'] as num).toDouble() : 0.0;
      double y = (vec['y'] is num) ? (vec['y'] as num).toDouble() : 0.0;
      double z = (vec['z'] is num) ? (vec['z'] as num).toDouble() : 0.0;
      return "(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})";
    }
    return "N/A";
  }

  Widget _buildConfigItem(String label, String? value, bool isDark) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                size: 16,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPill(String text, bool isGreen, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isGreen
            ? Colors.green.withOpacity(0.15)
            : (isDark ? Colors.white12 : Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isGreen
              ? Colors.green
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildStatusAndScaleItem({
    required String label,
    required Widget valueWidget,
    required Widget trailingWidget,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
              const SizedBox(height: 6),
              valueWidget,
            ],
          ),
          trailingWidget,
        ],
      ),
    );
  }

  Widget _buildLocalDetailBody(bool isDark, Map<String, dynamic> project) {
    final Map<String, dynamic> data = project['project_data'] ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _buildDetailCard("PROJECT CONFIGURATION", [
                _buildConfigItem(
                  "Export Path",
                  data["Project_Navis_Export_Path"],
                  isDark,
                ),
                _buildConfigItem(
                  "Geometry Path",
                  data["Project_geometry_Path"],
                  isDark,
                ),
                _buildConfigItem(
                  "Material Path",
                  data["Project_material_Path"],
                  isDark,
                ),
                _buildConfigItem(
                  "UData Path",
                  data["Project_udata_Path"],
                  isDark,
                ),
              ], isDark),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: _buildDetailCard("STATUS & SCALE", [
                _buildStatusAndScaleItem(
                  label: "Converted",
                  valueWidget: _buildPill(
                    data["is_ConvertedStored"]?.toString() ?? "false",
                    data["is_ConvertedStored"] == true,
                    isDark,
                  ),
                  trailingWidget: const Icon(
                    Icons.incomplete_circle,
                    size: 20,
                    color: Colors.blue,
                  ),
                  isDark: isDark,
                ),
                _buildStatusAndScaleItem(
                  label: "Layer Method",
                  valueWidget: Row(
                    children: [
                      Icon(
                        Icons.zoom_out_map,
                        size: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        (data["Show_Layer_Method"]?.toString() ?? "SIZE")
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  trailingWidget: Icon(
                    Icons.signal_cellular_alt,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                  isDark: isDark,
                ),
                _buildStatusAndScaleItem(
                  label: "Markers",
                  valueWidget: Text(
                    data["List_Of_Marker_Issue"]?.length.toString() ?? "0",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  trailingWidget: Icon(
                    Icons.push_pin_outlined,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.black54,
                  ),
                  isDark: isDark,
                ),
                _buildStatusAndScaleItem(
                  label: "Labels",
                  valueWidget: Text(
                    data["List_Of_Marker_Lable"]?.length.toString() ?? "0",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  trailingWidget: Icon(
                    Icons.label_outline,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.black54,
                  ),
                  isDark: isDark,
                ),
              ], isDark),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 400,
          child: _buildDetailCard("SPATIAL METADATA", [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailItem(
                        "Model Offset",
                        _formatVec3(data["LOADED_MODEL_OFFSET_Position"]),
                        isDark,
                      ),
                      _buildDetailItem(
                        "VR Menu Pos",
                        _formatVec3(data["VRMenu_Model_Position"]),
                        isDark,
                      ),
                      _buildDetailItem(
                        "Model Center",
                        _formatVec3(data["Created_Model_Center"]),
                        isDark,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.02)
                          : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.view_in_ar_outlined,
                            size: 40,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "3D Bounding Box\nPlaceholder",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ], isDark),
        ),
        if (project['id'] != null) ...[
          const SizedBox(height: 48),
          Text(
            'PROJECT ISSUES',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              fontSize: 16,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 600, // Fixed height for embedded panel
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2328) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IssueListPanel(projectId: project['id']),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2328) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value, bool isDark) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalProjectsGrid(bool isDark) {
    if (_localProjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_off_outlined,
              size: 64,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              "No local projects found.",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              CommonData.localSyncPath != null &&
                      CommonData.localSyncPath!.isNotEmpty
                  ? "Scanning: ${CommonData.localSyncPath}"
                  : "Local sync path is not configured.",
              style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(Icons.settings),
              label: const Text("CONFIGURE SYNC PATH"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).primaryColor,
                side: BorderSide(color: Theme.of(context).primaryColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Scrollbar(
      child: GridView.builder(
        padding: const EdgeInsets.all(32),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 1.4,
        ),
        itemCount: _localProjects.length,
        itemBuilder: (context, i) {
          final project = _localProjects[i];
          final String pName = project['name'] ?? "Unknown";
          final String pPath = project['path'] ?? "";
          final bool isUploaded = project['is_uploaded'] ?? false;

          return InkWell(
            onTap: () => setState(() {
              _selectedLocalProject = project;
            }),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2328) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Main Content
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.folder_rounded,
                          size: 48,
                          color: Colors.blue.withOpacity(0.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          pName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Top Right Action
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _uploadingLocalProjectNames.contains(pName)
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            child: const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : isUploaded
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_done_rounded,
                              size: 20,
                              color: Colors.green,
                            ),
                          )
                        : GestureDetector(
                            onTap: () => _uploadLocalProject(pName, pPath),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.cloud_upload_outlined,
                                size: 20,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCloudProjectsGrid(bool isDark) {
    if (_projects.isEmpty) {
      return Center(
        child: Text(
          "No cloud projects found.",
          style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
        ),
      );
    }
    return Scrollbar(
      child: GridView.builder(
        padding: const EdgeInsets.all(32),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
            onTap: () =>
                _openProject(Map<String, dynamic>.from(project as Map)),
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
                        ? Theme.of(context).primaryColor.withOpacity(0.35)
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
                    Container(
                      color: isDark
                          ? const Color(0xFF1A2035)
                          : Colors.blueGrey.shade50,
                      child: const Center(
                        child: Icon(
                          Icons.cloud_outlined,
                          size: 50,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (project['name'] as String).toUpperCase(),
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
                          const Text(
                            'BIM 360',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action Buttons
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _loadingCloudProjectIds.contains(project['id'])
                          ? Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              children: [
                                if (project['model_filename'] != null)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.download_for_offline,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        final pid = project['id'] is int
                                            ? project['id']
                                            : int.tryParse(
                                                project['id'].toString(),
                                              );
                                        if (pid != null) {
                                          _downloadCloudProject(
                                            Map<String, dynamic>.from(
                                              project as Map,
                                            ),
                                          );
                                        }
                                      },
                                      tooltip: 'Sync to Local',
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      final pid = project['id'] is int
                                          ? project['id']
                                          : int.tryParse(
                                              project['id'].toString(),
                                            );
                                      if (pid != null) {
                                        _deleteCloudProject(
                                          pid,
                                          project['name'],
                                        );
                                      }
                                    },
                                    tooltip: 'Delete from Cloud',
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    padding: EdgeInsets.zero,
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
    );
  }

  Widget _buildAutodeskHubView(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D21) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AutodeskFileBrowser(
          initialHubId: CommonData.bimUploadHubId,
          initialProjectId: CommonData.bimUploadProjectId,
          initialFolderId: CommonData.bimUploadFolderId,
          onDownload: (projId, itemId, name, isFolder) =>
              _downloadAutodeskItem(projId, itemId, name, isFolder: isFolder),
          onDelete: (projId, itemId, name, isFolder) =>
              _deleteAutodeskItem(projId, itemId, name, isFolder: isFolder),
        ),
      ),
    );
  }

  Future<void> _downloadAutodeskItem(
    String projectId,
    String itemId,
    String name, {
    bool isFolder = false,
  }) async {
    try {
      if (mounted) {
        CommonData.showCustomSnackBar(context, 'Downloading $name...');
      }
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final body = {
        'project_id': projectId,
        'item_id': itemId,
        'name': name,
        'is_folder': isFolder,
      };

      final response = await http.post(
        Uri.parse('${CommonData.backendUrl}/autodesk/download'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          final data = json.decode(response.body);
          CommonData.showCustomSnackBar(
            context,
            data['message'] ?? 'Successfully downloaded $name!',
          );
        }
        // Refresh local projects list automatically
        _fetchProjects();
      } else {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Download failed: ${response.body}',
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error downloading item: $e');
      if (mounted) {
        CommonData.showCustomSnackBar(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _deleteAutodeskItem(
    String projectId,
    String itemId,
    String name, {
    bool isFolder = false,
  }) async {
    try {
      if (mounted) {
        CommonData.showCustomSnackBar(
          context,
          'Deleting $name from BIM Cloud...',
        );
      }
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final type = isFolder ? 'folder' : 'item';
      final response = await http.delete(
        Uri.parse(
          '${CommonData.backendUrl}/autodesk/$type?project_id=$projectId&${type}_id=$itemId&name=${Uri.encodeComponent(name)}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          CommonData.showCustomSnackBar(context, 'Successfully deleted $name!');
        }
        // Force refresh of BOTH tabs
        _fetchProjects();
        // The Autodesk browser refreshes itself if we use the same key or if we manually trigger a reload.
        // For now, let's assume the user will navigate or we can force a rebuild if needed.
        setState(() {});
      } else {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Delete failed: ${response.body}',
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting Autodesk item: $e');
      if (mounted) {
        CommonData.showCustomSnackBar(context, 'Error: $e', isError: true);
      }
    }
  }

  Future<void> _deleteCloudProject(int projectId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(
          'Are you sure you want to delete project "$name" from Cloud?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loadingCloudProjectIds.add(projectId));
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.delete(
        Uri.parse('${CommonData.backendUrl}/projects/$projectId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Project deleted successfully',
          );
        }
        _fetchProjects();
      } else {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Failed to delete: ${response.body}',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CommonData.showCustomSnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingCloudProjectIds.remove(projectId));
      }
    }
  }

  Future<void> _downloadCloudProject(Map<String, dynamic> project) async {
    final name = project['name'] ?? 'Project';
    final modelUrl = project['model_url'];

    if (modelUrl == null) {
      if (mounted) {
        CommonData.showCustomSnackBar(
          context,
          'No model file for this project',
          isError: true,
        );
      }
      return;
    }

    final projectId = project['id'];
    setState(() => _loadingCloudProjectIds.add(projectId));
    try {
      if (mounted) {
        CommonData.showCustomSnackBar(
          context,
          'Starting download for $name...',
        );
      }

      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse('${CommonData.backendUrl}/projects/$projectId/sync-to-local'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Successfully synced $name to local storage!',
          );
        }
        _fetchProjects();
      } else {
        if (mounted) {
          CommonData.showCustomSnackBar(
            context,
            'Sync failed: ${response.body}',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CommonData.showCustomSnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingCloudProjectIds.remove(projectId));
      }
    }
  }

  Widget _buildDataList(
    String title,
    dynamic data,
    bool isDark,
    IconData icon,
  ) {
    List<dynamic> items = [];
    if (data is List) {
      items = data;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2328) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: Text(
                'No $title defined.',
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2328) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.1)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                itemBuilder: (context, index) {
                  final item = items[index];
                  String label = 'Item $index';
                  if (item is Map) {
                    label =
                        item['Teleport_Place_Title'] ??
                        item['Issue_Title'] ??
                        item['Name'] ??
                        'Item $index';
                  }

                  return ListTile(
                    leading: Icon(
                      icon,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      item.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black54,
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
