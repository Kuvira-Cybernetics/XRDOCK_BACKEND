import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../common/common.dart';

class IssueListPanel extends StatefulWidget {
  final int? projectId; // null = show all projects' issues
  final List<dynamic>? localIssues;
  const IssueListPanel({super.key, this.projectId, this.localIssues});

  @override
  State<IssueListPanel> createState() => _IssueListPanelState();
}

class _IssueListPanelState extends State<IssueListPanel> {
  List<Map<String, dynamic>> _issues = [];
  List<Map<String, dynamic>> _filteredIssues = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedPriority;
  int? _selectedFilterProjectId;
  List<Map<String, dynamic>> _allFilterProjects = [];

  @override
  void initState() {
    super.initState();
    if (widget.localIssues != null) {
      _issues = widget.localIssues!
          .map((e) => e as Map<String, dynamic>)
          .toList();
      _filteredIssues = List.from(_issues);
      _isLoading = false;
    } else {
      _fetchIssues();
    }
    if (widget.projectId == null && widget.localIssues == null) {
      _fetchAllProjectsForFilter();
    }
  }

  @override
  void didUpdateWidget(covariant IssueListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId ||
        oldWidget.localIssues != widget.localIssues) {
      if (widget.localIssues != null) {
        setState(() {
          _issues = widget.localIssues!
              .map((e) => e as Map<String, dynamic>)
              .toList();
          _filteredIssues = List.from(_issues);
          _isLoading = false;
        });
      } else {
        _fetchIssues();
      }
      if (widget.projectId == null && widget.localIssues == null) {
        _fetchAllProjectsForFilter();
      }
    }
  }

  Future<void> _fetchAllProjectsForFilter() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      // Fetch cloud projects
      final responseBim = await http.get(
        Uri.parse('${CommonData.backendUrl}/projects'),
        headers: {'Authorization': 'Bearer $token'},
      );
      // Fetch local projects
      final responseLocal = await http.get(
        Uri.parse('${CommonData.backendUrl}/projects/local'),
        headers: {'Authorization': 'Bearer $token'},
      );

      List<Map<String, dynamic>> projects = [];
      if (responseBim.statusCode == 200) {
        final List<dynamic> data = json.decode(responseBim.body);
        projects.addAll(data.map((e) => e as Map<String, dynamic>));
      }
      if (responseLocal.statusCode == 200) {
        final List<dynamic> data = json.decode(responseLocal.body);
        // Only include local projects that have been uploaded (and thus have an ID)
        final localProjects = data
            .map((e) => e as Map<String, dynamic>)
            .where((p) => p['id'] != null)
            .toList();
        projects.addAll(localProjects);
      }
      if (mounted) {
        setState(() {
          _allFilterProjects = projects;
        });
      }
    } catch (e) {
      debugPrint('Error fetching projects for filter: $e');
    }
  }

  Future<void> _fetchIssues({bool isRetry = false}) async {
    if (!isRetry) setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      // Get token, potentially forcing refresh if this is a retry
      final token = await user?.getIdToken(isRetry);

      // Use /issues for all projects, /issues/{id} for specific project
      final url = widget.projectId != null
          ? '${CommonData.backendUrl}/issues/${widget.projectId}'
          : '${CommonData.backendUrl}/issues';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _issues = data.map((e) => e as Map<String, dynamic>).toList();
          _applyFilters();
          _isLoading = false;
        });
      } else if (response.statusCode == 401 && !isRetry) {
        // Token might have expired, try once more with a fresh token
        debugPrint('401 Unauthorized, attempting token refresh...');
        await _fetchIssues(isRetry: true);
      } else {
        debugPrint(
          'Failed to fetch issues: ${response.statusCode} - ${response.body}',
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching issues: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteIssue(int id) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.delete(
        Uri.parse('${CommonData.backendUrl}/issues/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          CommonData.showCustomSnackBar(context, 'Issue deleted');
        }
        _fetchIssues();
      }
    } catch (e) {
      debugPrint('Error deleting issue: $e');
    }
  }

  Future<void> _updateIssue(int id, Map<String, dynamic> data) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.put(
        Uri.parse('${CommonData.backendUrl}/issues/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          CommonData.showCustomSnackBar(context, 'Issue updated');
        }
        _fetchIssues();
      }
    } catch (e) {
      debugPrint('Error updating issue: $e');
    }
  }

  Future<void> _createIssue(Map<String, dynamic> data) async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse('${CommonData.backendUrl}/issues'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          CommonData.showCustomSnackBar(context, 'Issue created');
        }
        _fetchIssues();
      }
    } catch (e) {
      debugPrint('Error creating issue: $e');
    }
  }

  void _showCreateDialog(BuildContext context) async {
    // Show a loading indicator while fetching projects
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    List<Map<String, dynamic>> allProjects = [];
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/projects'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        allProjects = data.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint('Error fetching projects: $e');
    }

    // Dismiss loading indicator
    if (context.mounted) Navigator.pop(context);

    if (!context.mounted) return;

    String currentStatus = 'open';
    String currentPriority = 'medium';
    int? selectedProjectForIssue = widget.projectId;

    // If widget.projectId is set but isn't in the list (unlikely), reset it.
    if (selectedProjectForIssue != null &&
        !allProjects.any((p) => p['id'] == selectedProjectForIssue)) {
      selectedProjectForIssue = null;
    }

    final titleCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Add Issue'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title'),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selectedProjectForIssue,
                      decoration: const InputDecoration(labelText: 'Project'),
                      hint: const Text('Select a Project'),
                      items: allProjects.map((p) {
                        return DropdownMenuItem<int>(
                          value: p['id'] as int,
                          child: Text(p['name'].toString()),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setStateDialog(() => selectedProjectForIssue = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: currentStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                        DropdownMenuItem(
                          value: 'in-progress',
                          child: Text('In Progress'),
                        ),
                        DropdownMenuItem(
                          value: 'closed',
                          child: Text('Closed'),
                        ),
                      ],
                      onChanged: (val) =>
                          setStateDialog(() => currentStatus = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: currentPriority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgent'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                      ],
                      onChanged: (val) =>
                          setStateDialog(() => currentPriority = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isNotEmpty &&
                        selectedProjectForIssue != null) {
                      _createIssue({
                        'title': titleCtrl.text.trim(),
                        'status': currentStatus,
                        'priority': currentPriority,
                        'project_id': selectedProjectForIssue,
                      });
                      Navigator.pop(ctx);
                    } else if (selectedProjectForIssue == null) {
                      CommonData.showCustomSnackBar(
                        context,
                        'Please select a project to proceed.',
                        isError: true,
                      );
                    }
                  },
                  child: const Text('CREATE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyFilters() {
    setState(() {
      _filteredIssues = _issues.where((issue) {
        final title = (issue['title'] ?? issue['Marker_Issue_Name'] ?? '')
            .toString()
            .toLowerCase();
        final matchesSearch = title.contains(_searchQuery.toLowerCase());

        final status = (issue['status'] ?? issue['Marker_Issue_Status'] ?? '')
            .toString()
            .toLowerCase();
        final matchesStatus =
            _selectedStatus == null || status == _selectedStatus!.toLowerCase();

        final priority =
            (issue['priority'] ?? issue['Marker_Issue_Priority'] ?? '')
                .toString()
                .toLowerCase();
        final matchesPriority =
            _selectedPriority == null ||
            priority == _selectedPriority!.toLowerCase();

        final matchesProject =
            _selectedFilterProjectId == null ||
            issue['project_id'] == _selectedFilterProjectId;

        return matchesSearch &&
            matchesStatus &&
            matchesPriority &&
            matchesProject;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PROJECT ISSUES',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.localIssues == null) ...[
                      ElevatedButton.icon(
                        onPressed: () => _showCreateDialog(context),
                        icon: const Icon(Icons.add, size: 20),
                        label: const Text('NEW ISSUE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _fetchIssues,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 250,
                    child: TextField(
                      onChanged: (value) {
                        _searchQuery = value;
                        _applyFilters();
                      },
                      decoration: InputDecoration(
                        hintText: 'SEARCH BY TITLE...',
                        prefixIcon: const Icon(Icons.search),
                        fillColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.black.withOpacity(0.02),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (widget.projectId == null) ...[
                    _buildFilterDropdown(
                      hint: 'PROJECT',
                      value: _selectedFilterProjectId?.toString(),
                      items: _allFilterProjects
                          .map(
                            (p) => {
                              "value": p['id'].toString(),
                              "label": p['name'].toString(),
                            },
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(
                          () => _selectedFilterProjectId = val == null
                              ? null
                              : int.tryParse(val),
                        );
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 12),
                  ],
                  _buildFilterDropdown(
                    hint: 'STATUS',
                    value: _selectedStatus,
                    items: [
                      {"value": "OPEN", "label": "OPEN"},
                      {"value": "IN-PROGRESS", "label": "IN-PROGRESS"},
                      {"value": "CLOSED", "label": "CLOSED"},
                    ],
                    onChanged: (val) {
                      setState(() => _selectedStatus = val);
                      _applyFilters();
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildFilterDropdown(
                    hint: 'PRIORITY',
                    value: _selectedPriority,
                    items: [
                      {"value": "URGENT", "label": "URGENT"},
                      {"value": "HIGH", "label": "HIGH"},
                      {"value": "MEDIUM", "label": "MEDIUM"},
                      {"value": "LOW", "label": "LOW"},
                    ],
                    onChanged: (val) {
                      setState(() => _selectedPriority = val);
                      _applyFilters();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredIssues.isEmpty
                ? const Center(child: Text('NO ISSUES FOUND'))
                : Scrollbar(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _filteredIssues.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final issue = _filteredIssues[index];
                        return _IssueTile(
                          issue: issue,
                          onDelete: widget.localIssues != null
                              ? null
                              : () => _deleteIssue(issue['id']),
                          onEdit: widget.localIssues != null
                              ? null
                              : (updatedData) =>
                                    _updateIssue(issue['id'], updatedData),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String hint,
    required String? value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
          items: [
            DropdownMenuItem(value: null, child: Text('ALL $hint')),
            ...items.map(
              (e) =>
                  DropdownMenuItem(value: e["value"], child: Text(e["label"]!)),
            ),
          ],
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        ),
      ),
    );
  }
}

class _IssueTile extends StatefulWidget {
  final Map<String, dynamic> issue;
  final VoidCallback? onDelete;
  final Function(Map<String, dynamic>)? onEdit;

  const _IssueTile({required this.issue, this.onDelete, this.onEdit});

  @override
  State<_IssueTile> createState() => _IssueTileState();
}

class _IssueTileState extends State<_IssueTile> {
  void _showEditDialog(BuildContext context) {
    String currentTitle = widget.issue['title'] ?? '';
    String currentStatus = widget.issue['status'] ?? 'open';
    String currentPriority = widget.issue['priority'] ?? 'medium';

    final titleCtrl = TextEditingController(text: currentTitle);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Edit Issue'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: currentStatus.toLowerCase(),
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                        DropdownMenuItem(
                          value: 'in-progress',
                          child: Text('In Progress'),
                        ),
                        DropdownMenuItem(
                          value: 'closed',
                          child: Text('Closed'),
                        ),
                      ],
                      onChanged: (val) =>
                          setStateDialog(() => currentStatus = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: currentPriority.toLowerCase(),
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgent'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                      ],
                      onChanged: (val) =>
                          setStateDialog(() => currentPriority = val!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isNotEmpty &&
                        widget.onEdit != null) {
                      widget.onEdit!({
                        'title': titleCtrl.text.trim(),
                        'status': currentStatus,
                        'priority': currentPriority,
                      });
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('SAVE'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final issue = widget.issue;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.05),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor(
                (issue['priority'] ??
                        issue['Marker_Issue_Priority'] ??
                        'medium')
                    .toString(),
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (issue['title'] ?? issue['Marker_Issue_Name'] ?? 'UNTITLED')
                      .toString()
                      .toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'STATUS: ${(issue['status'] ?? issue['Marker_Issue_Status'] ?? 'OPEN').toString().toUpperCase()}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'ID: #${issue['id'] ?? issue['Marker_Issue_ID'] ?? issue['Marker_Issue_Index'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.onEdit != null && widget.onDelete != null) ...[
            IconButton(
              icon: const Icon(
                Icons.edit_outlined,
                color: Colors.blueGrey,
                size: 20,
              ),
              onPressed: () => _showEditDialog(context),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 20,
              ),
              onPressed: () {
                // Confirm deletion
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Issue?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('CANCEL'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          widget.onDelete!();
                        },
                        child: const Text(
                          'DELETE',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.redAccent;
      case 'high':
        return Colors.orangeAccent;
      case 'medium':
        return Colors.blueAccent;
      default:
        return Colors.greenAccent;
    }
  }
}
