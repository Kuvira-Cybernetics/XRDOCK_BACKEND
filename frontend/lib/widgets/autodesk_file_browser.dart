import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../common/common.dart';

class AutodeskFileBrowser extends StatefulWidget {
  final Function(String project_id, String item_id, String name) onFileSelected;

  const AutodeskFileBrowser({super.key, required this.onFileSelected});

  @override
  State<AutodeskFileBrowser> createState() => _AutodeskFileBrowserState();
}

class _AutodeskFileBrowserState extends State<AutodeskFileBrowser> {
  bool _isLoading = true;
  String _error = '';

  List<dynamic> _hubs = [];
  List<dynamic> _projects = [];
  List<dynamic> _folders = [];
  List<dynamic> _contents = [];

  String? _selectedHubId;
  String? _selectedProjectId;
  String? _selectedFolderId;
  List<String> _folderHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchHubs();
  }

  Future<void> _fetchHubs() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/autodesk/hubs'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _hubs = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load hubs: ${response.body}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading hubs: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchProjects(String hubId) async {
    setState(() {
      _isLoading = true;
      _selectedHubId = hubId;
      _projects = [];
      _folders = [];
      _contents = [];
      _selectedFolderId = null;
      _folderHistory = [];
    });
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/autodesk/projects/$hubId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _projects = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading projects: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTopFolders(String projectId) async {
    setState(() {
      _isLoading = true;
      _selectedProjectId = projectId;
      _folders = [];
      _contents = [];
      _selectedFolderId = null;
      _folderHistory = [];
    });
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse(
          '${CommonData.backendUrl}/autodesk/folders/$_selectedHubId/$projectId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _folders = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading folders: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchFolderContents(
    String folderId, {
    bool isBack = false,
  }) async {
    if (!isBack && _selectedFolderId != null) {
      _folderHistory.add(_selectedFolderId!);
    }
    setState(() {
      _isLoading = true;
      _selectedFolderId = folderId;
      _contents = [];
    });
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse(
          '${CommonData.backendUrl}/autodesk/folder-contents/$_selectedProjectId/$folderId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _contents = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading folder contents: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error, style: const TextStyle(color: Colors.red)),
            ElevatedButton(onPressed: _fetchHubs, child: const Text('RETRY')),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedFolderId != null) {
      return _buildListView(
        _contents,
        'CONTENTS',
        (item) {
          if (item['type'] == 'items') {
            // If the attributes are missing, pass the item ID as a fallback name.
            final attrs = item['attributes'] as Map<String, dynamic>?;
            final displayName =
                attrs?['displayName'] ??
                attrs?['name'] ??
                item['id'] ??
                'Unknown File';
            widget.onFileSelected(_selectedProjectId!, item['id'], displayName);
          } else if (item['type'] == 'folders') {
            _fetchFolderContents(item['id']);
          }
        },
        onBack: () {
          if (_folderHistory.isNotEmpty) {
            final prevFolder = _folderHistory.removeLast();
            _fetchFolderContents(prevFolder, isBack: true);
          } else {
            setState(() => _selectedFolderId = null);
          }
        },
      );
    }

    if (_selectedProjectId != null) {
      return _buildListView(_folders, 'FOLDERS', (folder) {
        _fetchFolderContents(folder['id']);
      }, onBack: () => setState(() => _selectedProjectId = null));
    }

    if (_selectedHubId != null) {
      return _buildListView(_projects, 'PROJECTS', (project) {
        _fetchTopFolders(project['id']);
      }, onBack: () => setState(() => _selectedHubId = null));
    }

    return _buildListView(_hubs, 'HUBS', (hub) {
      _fetchProjects(hub['id']);
    });
  }

  Widget _buildListView(
    List<dynamic> items,
    String title,
    Function(dynamic) onTap, {
    VoidCallback? onBack,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              if (onBack != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onBack,
                ),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No items found.'))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final attrs = item['attributes'] as Map<String, dynamic>?;
                    final name =
                        attrs?['name'] ??
                        attrs?['displayName'] ??
                        item['id'] ??
                        'Unknown';

                    final type = item['type'] ?? 'unknown';
                    final isFolder =
                        type == 'folders' ||
                        type == 'hubs' ||
                        type == 'projects';

                    return ListTile(
                      leading: Icon(
                        isFolder ? Icons.folder : Icons.insert_drive_file,
                      ),
                      title: Text('$name ($type)'),
                      onTap: () {
                        // Let items and folders be clickable, log if clicked something else
                        onTap(item);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
