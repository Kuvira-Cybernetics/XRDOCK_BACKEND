import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../common/common.dart';

class IssueListPanel extends StatefulWidget {
  final int? projectId; // null = show all projects' issues
  const IssueListPanel({super.key, this.projectId});

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

  @override
  void initState() {
    super.initState();
    _fetchIssues();
  }

  @override
  void didUpdateWidget(covariant IssueListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _fetchIssues();
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

  void _applyFilters() {
    setState(() {
      _filteredIssues = _issues.where((issue) {
        final matchesSearch = issue['title'].toString().toLowerCase().contains(
          _searchQuery.toLowerCase(),
        );
        final matchesStatus =
            _selectedStatus == null ||
            issue['status'].toString().toLowerCase() ==
                _selectedStatus!.toLowerCase();
        final matchesPriority =
            _selectedPriority == null ||
            issue['priority']?.toString().toLowerCase() ==
                _selectedPriority!.toLowerCase();

        return matchesSearch && matchesStatus && matchesPriority;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROJECT ISSUES',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchIssues,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
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
              _buildFilterDropdown(
                hint: 'STATUS',
                value: _selectedStatus,
                items: ['OPEN', 'IN-PROGRESS', 'CLOSED'],
                onChanged: (val) {
                  setState(() => _selectedStatus = val);
                  _applyFilters();
                },
              ),
              const SizedBox(width: 12),
              _buildFilterDropdown(
                hint: 'PRIORITY',
                value: _selectedPriority,
                items: ['URGENT', 'HIGH', 'MEDIUM', 'LOW'],
                onChanged: (val) {
                  setState(() => _selectedPriority = val);
                  _applyFilters();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredIssues.isEmpty
                ? const Center(child: Text('NO ISSUES FOUND'))
                : ListView.separated(
                    itemCount: _filteredIssues.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final issue = _filteredIssues[index];
                      return _IssueTile(issue: issue);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String hint,
    required String? value,
    required List<String> items,
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
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
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

class _IssueTile extends StatelessWidget {
  final Map<String, dynamic> issue;
  const _IssueTile({required this.issue});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

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
              color: _getStatusColor(issue['priority']),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue['title'].toString().toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'STATUS: ${issue['status'].toString().toUpperCase()}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'ID: #${issue['id']}',
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
          const Icon(Icons.chevron_right, color: Colors.grey),
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
