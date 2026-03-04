import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../common/common.dart';
import 'percentage_circular_progress.dart';

class AutodeskFileBrowser extends StatefulWidget {
  final void Function(
    String hubId,
    String hubName,
    String projectId,
    String projectName,
    String folderId,
    String folderName,
  )?
  onFolderSelected;
  final void Function(String projectId, String itemId, String name)?
  onFileSelected;
  final Future<void> Function(
    String projectId,
    String folderId,
    String name,
    bool isFolder,
  )?
  onDownload;
  final Future<void> Function(
    String projectId,
    String itemId,
    String name,
    bool isFolder,
  )?
  onDelete;
  final bool allowFolderSelection;
  final String? initialHubId;
  final String? initialProjectId;
  final String? initialFolderId;

  const AutodeskFileBrowser({
    super.key,
    this.onFileSelected,
    this.onFolderSelected,
    this.onDownload,
    this.onDelete,
    this.allowFolderSelection = false,
    this.initialHubId,
    this.initialProjectId,
    this.initialFolderId,
  });

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
  String? _selectedHubName;
  String? _selectedProjectId;
  String? _selectedProjectName;
  String? _selectedFolderId;
  String? _selectedFolderName;
  List<Map<String, String>> _folderHistory = []; // List of {id: ..., name: ...}
  final Set<String> _loadingIds = {};
  final Set<String> _deletingIds = {};
  final Map<String, double> _transferProgress = {}; // itemId -> 0.0-1.0

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      // 1. Fetch Hubs (always good to have the list)
      await _fetchHubs(isInit: true);

      if (widget.initialHubId != null) {
        // Find hub name from list or use default
        String hName = 'Hub';
        for (var h in _hubs) {
          if (h['id'] == widget.initialHubId) {
            final attrs = h['attributes'] as Map<String, dynamic>?;
            hName = attrs?['name'] ?? attrs?['displayName'] ?? hName;
            break;
          }
        }

        // 2. Fetch Projects
        await _fetchProjects(widget.initialHubId!, hName, isInit: true);

        if (widget.initialProjectId != null) {
          // Find project name
          String pName = 'Project';
          for (var p in _projects) {
            if (p['id'] == widget.initialProjectId) {
              final attrs = p['attributes'] as Map<String, dynamic>?;
              pName = attrs?['name'] ?? attrs?['displayName'] ?? pName;
              break;
            }
          }

          // 3. Fetch Top Folders
          await _fetchTopFolders(widget.initialProjectId!, pName, isInit: true);

          if (widget.initialFolderId != null) {
            // Find folder name if possible from _folders
            String fName = 'Folder';
            for (var f in _folders) {
              if (f['id'] == widget.initialFolderId) {
                final attrs = f['attributes'] as Map<String, dynamic>?;
                fName = attrs?['name'] ?? attrs?['displayName'] ?? fName;
                break;
              }
            }
            // 4. Fetch Folder Contents
            await _fetchFolderContents(
              widget.initialFolderId!,
              fName,
              isInit: true,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error during initialization: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHubs({bool isInit = false}) async {
    if (!isInit) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = '';
        });
      }
    }
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/autodesk/hubs'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _hubs = json.decode(response.body);
            if (!isInit) _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          CommonData.logout(context, sessionExpired: true);
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load hubs: ${response.body}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('Failed to fetch')) {
          CommonData.logout(context, sessionExpired: true);
        } else {
          setState(() {
            _error = 'Error loading hubs: $e';
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _fetchProjects(
    String hubId,
    String hubName, {
    bool isInit = false,
  }) async {
    if (!isInit) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _selectedHubId = hubId;
          _selectedHubName = hubName;
          _projects = [];
          _folders = [];
          _contents = [];
          _selectedProjectId = null;
          _selectedProjectName = null;
          _selectedFolderId = null;
          _selectedFolderName = null;
          _folderHistory = [];
        });
      }
    } else {
      _selectedHubId = hubId;
      _selectedHubName = hubName;
    }

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/autodesk/projects/$hubId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _projects = json.decode(response.body);
            if (!isInit) _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          CommonData.logout(context, sessionExpired: true);
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('Failed to fetch')) {
          CommonData.logout(context, sessionExpired: true);
        } else {
          setState(() {
            _error = 'Error loading projects: $e';
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _fetchTopFolders(
    String projectId,
    String projectName, {
    bool isInit = false,
  }) async {
    if (!isInit) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _selectedProjectId = projectId;
          _selectedProjectName = projectName;
          _folders = [];
          _contents = [];
          _selectedFolderId = null;
          _selectedFolderName = null;
          _folderHistory = [];
        });
      }
    } else {
      _selectedProjectId = projectId;
      _selectedProjectName = projectName;
    }

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse(
          '${CommonData.backendUrl}/autodesk/folders/$_selectedHubId/$projectId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _folders = json.decode(response.body);
            if (!isInit) _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          CommonData.logout(context, sessionExpired: true);
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('Failed to fetch')) {
          CommonData.logout(context, sessionExpired: true);
        } else {
          setState(() {
            _error = 'Error loading top folders: $e';
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _fetchFolderContents(
    String folderId,
    String folderName, {
    bool isBack = false,
    bool isInit = false,
  }) async {
    if (!isInit && !isBack && _selectedFolderId != null) {
      _folderHistory.add({
        'id': _selectedFolderId!,
        'name': _selectedFolderName ?? 'Folder',
      });
    }
    if (!isInit) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _selectedFolderId = folderId;
          _selectedFolderName = folderName;
          _contents = [];
        });
      }
    } else {
      _selectedFolderId = folderId;
      _selectedFolderName = folderName;
    }

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse(
          '${CommonData.backendUrl}/autodesk/folder-contents/$_selectedProjectId/$folderId',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _contents = json.decode(response.body);
            if (!isInit) _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        if (mounted) {
          CommonData.logout(context, sessionExpired: true);
        }
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('Failed to fetch')) {
          CommonData.logout(context, sessionExpired: true);
        } else {
          setState(() {
            _error = 'Error loading folder contents: $e';
            _isLoading = false;
          });
        }
      }
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
            ElevatedButton(
              onPressed: () => _fetchHubs(),
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedFolderId != null) {
      return Column(
        children: [
          if (widget.allowFolderSelection)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onFolderSelected?.call(
                    _selectedHubId!,
                    _selectedHubName ?? 'Hub',
                    _selectedProjectId!,
                    _selectedProjectName ?? 'Project',
                    _selectedFolderId!,
                    _selectedFolderName ?? 'Folder',
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('SELECT CURRENT FOLDER'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          Expanded(
            child: _buildListView(
              _contents,
              'CONTENTS',
              (item) {
                if (item['type'] == 'items') {
                  final attrs = item['attributes'] as Map<String, dynamic>?;
                  final displayName =
                      attrs?['displayName'] ??
                      attrs?['name'] ??
                      item['id'] ??
                      'Unknown File';
                  widget.onFileSelected?.call(
                    _selectedProjectId!,
                    item['id'],
                    displayName,
                  );
                } else if (item['type'] == 'folders') {
                  final attrs = item['attributes'] as Map<String, dynamic>?;
                  final folderName =
                      attrs?['name'] ?? attrs?['displayName'] ?? 'Folder';
                  _fetchFolderContents(item['id'], folderName);
                }
              },
              onBack: () {
                if (_folderHistory.isNotEmpty) {
                  final prev = _folderHistory.removeLast();
                  _fetchFolderContents(
                    prev['id']!,
                    prev['name']!,
                    isBack: true,
                  );
                } else {
                  setState(() {
                    _selectedFolderId = null;
                    _selectedFolderName = null;
                  });
                }
              },
            ),
          ),
        ],
      );
    }

    if (_selectedProjectId != null) {
      return _buildListView(
        _folders,
        'FOLDERS',
        (folder) {
          final attrs = folder['attributes'] as Map<String, dynamic>?;
          final name = attrs?['name'] ?? attrs?['displayName'] ?? 'Folder';
          _fetchFolderContents(folder['id'], name);
        },
        onBack: () => setState(() {
          _selectedProjectId = null;
          _selectedProjectName = null;
        }),
      );
    }

    if (_selectedHubId != null) {
      return _buildListView(
        _projects,
        'PROJECTS',
        (project) {
          final attrs = project['attributes'] as Map<String, dynamic>?;
          final name = attrs?['name'] ?? attrs?['displayName'] ?? 'Project';
          _fetchTopFolders(project['id'], name);
        },
        onBack: () => setState(() {
          _selectedHubId = null;
          _selectedHubName = null;
        }),
      );
    }

    return _buildListView(_hubs, 'HUBS', (hub) {
      final attrs = hub['attributes'] as Map<String, dynamic>?;
      final name = attrs?['name'] ?? attrs?['displayName'] ?? 'Hub';
      _fetchProjects(hub['id'], name);
    });
  }

  Widget _buildListView(
    List<dynamic> items,
    String defaultTitle,
    Function(dynamic) onTap, {
    VoidCallback? onBack,
  }) {
    List<Widget> breadcrumbs = [];

    // Root - Hubs level title
    breadcrumbs.add(
      InkWell(
        onTap: () {
          setState(() {
            _selectedHubId = null;
            _selectedHubName = null;
            _selectedProjectId = null;
            _selectedProjectName = null;
            _selectedFolderId = null;
            _selectedFolderName = null;
            _folderHistory = [];
          });
        },
        child: const Icon(Icons.home_outlined, size: 20, color: Colors.blue),
      ),
    );

    if (_selectedHubId != null) {
      breadcrumbs.add(const Icon(Icons.chevron_right, size: 16));
      breadcrumbs.add(
        InkWell(
          onTap: () {
            setState(() {
              _selectedProjectId = null;
              _selectedProjectName = null;
              _selectedFolderId = null;
              _selectedFolderName = null;
              _folderHistory = [];
            });
          },
          child: Text(
            _selectedHubName ?? 'Hub',
            style: const TextStyle(color: Colors.blue),
          ),
        ),
      );
    }

    if (_selectedProjectId != null) {
      breadcrumbs.add(const Icon(Icons.chevron_right, size: 16));
      breadcrumbs.add(
        InkWell(
          onTap: () {
            setState(() {
              _selectedFolderId = null;
              _selectedFolderName = null;
              _folderHistory = [];
            });
          },
          child: Text(
            _selectedProjectName ?? 'Project',
            style: const TextStyle(color: Colors.blue),
          ),
        ),
      );
    }

    for (int i = 0; i < _folderHistory.length; i++) {
      final folder = _folderHistory[i];
      breadcrumbs.add(const Icon(Icons.chevron_right, size: 16));
      breadcrumbs.add(
        InkWell(
          onTap: () {
            final targetId = folder['id']!;
            final targetName = folder['name']!;
            setState(() {
              _folderHistory = _folderHistory.sublist(0, i);
              _fetchFolderContents(targetId, targetName, isBack: true);
            });
          },
          child: Text(
            folder['name']!,
            style: const TextStyle(color: Colors.blue),
          ),
        ),
      );
    }

    if (_selectedFolderId != null) {
      breadcrumbs.add(const Icon(Icons.chevron_right, size: 16));
      breadcrumbs.add(
        Text(
          _selectedFolderName ?? 'Folder',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: breadcrumbs),
          ),
        ),
        const Divider(height: 1),
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

                    final isFolder = item['type'] == 'folders';
                    final isItem = item['type'] == 'items';
                    final isNavigable =
                        isFolder ||
                        item['type'] == 'hubs' ||
                        item['type'] == 'projects';

                    return ListTile(
                      leading: Icon(
                        isNavigable ? Icons.folder : Icons.insert_drive_file,
                        color: isFolder
                            ? Colors.amber
                            : (isNavigable ? Colors.blue : null),
                      ),
                      title: Text(name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_loadingIds.contains(item['id']))
                            PercentageCircularProgress(
                              progress: _transferProgress[item['id']] ?? 0.05,
                              size: 32,
                            )
                          else if (_deletingIds.contains(item['id']))
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else ...[
                            if (widget.onDownload != null &&
                                (isFolder || isItem))
                              IconButton(
                                icon: const Icon(
                                  Icons.download_for_offline_outlined,
                                ),
                                onPressed: () async {
                                  setState(() {
                                    _loadingIds.add(item['id']);
                                    _transferProgress[item['id']] = 0.0;
                                  });

                                  // Simulate progress for UI demonstration
                                  // In a real app, this would be updated via a stream or feedback callback
                                  Future.doWhile(() async {
                                    await Future.delayed(
                                      const Duration(milliseconds: 300),
                                    );
                                    if (!mounted ||
                                        !_loadingIds.contains(item['id'])) {
                                      return false;
                                    }
                                    setState(() {
                                      double current =
                                          _transferProgress[item['id']] ?? 0.0;
                                      if (current < 0.9) {
                                        _transferProgress[item['id']] =
                                            current + 0.1;
                                      }
                                    });
                                    return true;
                                  });

                                  try {
                                    await widget.onDownload!(
                                      _selectedProjectId!,
                                      item['id'],
                                      name,
                                      isFolder,
                                    );
                                    if (mounted) {
                                      setState(() {
                                        _transferProgress[item['id']] = 1.0;
                                      });
                                    }
                                  } finally {
                                    if (mounted) {
                                      await Future.delayed(
                                        const Duration(milliseconds: 500),
                                      );
                                      setState(() {
                                        _loadingIds.remove(item['id']);
                                        _transferProgress.remove(item['id']);
                                      });
                                    }
                                  }
                                },
                                tooltip: isFolder
                                    ? 'Download Folder'
                                    : 'Download File',
                              ),
                            if (widget.onDelete != null && (isFolder || isItem))
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Confirm Delete'),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            splashRadius: 20,
                                          ),
                                        ],
                                      ),
                                      content: Text(
                                        'Are you sure you want to delete this ${isFolder ? 'folder' : 'file'}?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('CANCEL'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text(
                                            'DELETE',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    setState(
                                      () => _deletingIds.add(item['id']),
                                    );
                                    try {
                                      await widget.onDelete!(
                                        _selectedProjectId!,
                                        item['id'],
                                        name,
                                        isFolder,
                                      );
                                    } finally {
                                      if (mounted) {
                                        setState(
                                          () => _deletingIds.remove(item['id']),
                                        );
                                      }
                                      // Force refresh to remove deleted item
                                      _initialLoad();
                                    }
                                  }
                                },
                                tooltip: 'Delete Item',
                              ),
                          ],
                        ],
                      ),
                      onTap: () => onTap(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
