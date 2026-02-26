import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../common/common.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<dynamic> _users = [];
  List<dynamic> _projects = [];
  List<dynamic> _issues = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final headers = {'Authorization': 'Bearer $token'};

      final responses = await Future.wait([
        http.get(Uri.parse('${CommonData.backendUrl}/users'), headers: headers),
        http.get(
          Uri.parse('${CommonData.backendUrl}/projects'),
          headers: headers,
        ),
        http.get(
          Uri.parse('${CommonData.backendUrl}/issues'),
          headers: headers,
        ),
      ]);

      if (responses[0].statusCode == 200) {
        _users = json.decode(responses[0].body);
      }
      if (responses[1].statusCode == 200) {
        _projects = json.decode(responses[1].body);
      }
      if (responses[2].statusCode == 200) {
        _issues = json.decode(responses[2].body);
      }
    } catch (e) {
      debugPrint('Error fetching admin data: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteRecord(String endpoint, int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.delete(
        Uri.parse('${CommonData.backendUrl}/$endpoint/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _fetchAllData();
      } else {
        debugPrint('Failed to delete: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error deleting: $e');
    }
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final nameCtrl = TextEditingController(text: user['name']?.toString());
    final companyCtrl = TextEditingController(
      text: user['company_name']?.toString(),
    );
    final roleCtrl = TextEditingController(text: user['job_title']?.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit User: ${user['email']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: companyCtrl,
                decoration: const InputDecoration(labelText: 'Company'),
              ),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(labelText: 'Job Title'),
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
            onPressed: () async {
              try {
                final token = await FirebaseAuth.instance.currentUser
                    ?.getIdToken();
                await http.put(
                  Uri.parse('${CommonData.backendUrl}/users/${user['id']}'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({
                    'name': nameCtrl.text,
                    'company_name': companyCtrl.text,
                    'job_title': roleCtrl.text,
                  }),
                );
                _fetchAllData();
                Navigator.pop(ctx);
              } catch (e) {
                debugPrint('Update error: $e');
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showEditProjectDialog(Map<String, dynamic> project) {
    final nameCtrl = TextEditingController(text: project['name']?.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Project'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
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
            onPressed: () async {
              try {
                final token = await FirebaseAuth.instance.currentUser
                    ?.getIdToken();
                await http.put(
                  Uri.parse(
                    '${CommonData.backendUrl}/projects/${project['id']}',
                  ),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({'name': nameCtrl.text}),
                );
                _fetchAllData();
                Navigator.pop(ctx);
              } catch (e) {
                debugPrint('Update error: $e');
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showEditIssueDialog(Map<String, dynamic> issue) {
    final titleCtrl = TextEditingController(text: issue['title']?.toString());
    String currentStatus = issue['status']?.toString() ?? 'open';
    String currentPriority = issue['priority']?.toString() ?? 'medium';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
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
                  value: currentStatus,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                      value: 'in-progress',
                      child: Text('In Progress'),
                    ),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: (val) =>
                      setStateDialog(() => currentStatus = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: currentPriority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
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
              onPressed: () async {
                try {
                  final token = await FirebaseAuth.instance.currentUser
                      ?.getIdToken();
                  await http.put(
                    Uri.parse('${CommonData.backendUrl}/issues/${issue['id']}'),
                    headers: {
                      'Authorization': 'Bearer $token',
                      'Content-Type': 'application/json',
                    },
                    body: jsonEncode({
                      'title': titleCtrl.text,
                      'status': currentStatus,
                      'priority': currentPriority,
                    }),
                  );
                  _fetchAllData();
                  Navigator.pop(ctx);
                } catch (e) {
                  debugPrint('Update error: $e');
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTable() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PaginatedDataTable(
          header: const Text('Users'),
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Company')),
            DataColumn(label: Text('Actions')),
          ],
          source: _DataSource(_users, (user) {
            return DataRow(
              cells: [
                DataCell(Text(user['id'].toString())),
                DataCell(Text(user['email']?.toString() ?? '')),
                DataCell(Text(user['name']?.toString() ?? '')),
                DataCell(Text(user['company_name']?.toString() ?? '')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditUserDialog(user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteRecord('users', user['id']),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildProjectsTable() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PaginatedDataTable(
          header: const Text('Projects'),
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Created At')),
            DataColumn(label: Text('Actions')),
          ],
          source: _DataSource(_projects, (proj) {
            return DataRow(
              cells: [
                DataCell(Text(proj['id'].toString())),
                DataCell(Text(proj['name']?.toString() ?? '')),
                DataCell(
                  Text(
                    proj['created_at']?.toString() != null
                        ? proj['created_at'].toString().split('T')[0]
                        : '',
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditProjectDialog(proj),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteRecord('projects', proj['id']),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildIssuesTable() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PaginatedDataTable(
          header: const Text('Issues'),
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Title')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Priority')),
            DataColumn(label: Text('Project ID')),
            DataColumn(label: Text('Actions')),
          ],
          source: _DataSource(_issues, (issue) {
            return DataRow(
              cells: [
                DataCell(Text(issue['id'].toString())),
                DataCell(Text(issue['title']?.toString() ?? '')),
                DataCell(Text(issue['status']?.toString().toUpperCase() ?? '')),
                DataCell(
                  Text(issue['priority']?.toString().toUpperCase() ?? ''),
                ),
                DataCell(Text(issue['project_id']?.toString() ?? '')),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showEditIssueDialog(issue),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteRecord('issues', issue['id']),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Text(
                  'ADMIN PANEL',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchAllData,
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Users'),
              Tab(text: 'Projects'),
              Tab(text: 'Issues'),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUsersTable(),
                      _buildProjectsTable(),
                      _buildIssuesTable(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _DataSource extends DataTableSource {
  final List<dynamic> data;
  final DataRow Function(Map<String, dynamic>) buildRow;

  _DataSource(this.data, this.buildRow);

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    return buildRow(data[index]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => data.length;

  @override
  int get selectedRowCount => 0;
}
