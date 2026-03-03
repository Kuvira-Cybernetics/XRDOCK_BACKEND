import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../common/common.dart';
import '../theme/xrdock_theme.dart';

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
    }
  }

  Future<void> _fetchIssues({bool isRetry = false}) async {
    if (!isRetry) setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken(isRetry);
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
        await _fetchIssues(isRetry: true);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching issues: $e');
      setState(() => _isLoading = false);
    }
  }

  // REST OF FILE ... simplified/modernized implementation for briefness matching the new design
  void _applyFilters() {
    setState(() {
      _filteredIssues = _issues.where((issue) {
        final title = (issue['title'] ?? issue['Marker_Issue_Name'] ?? '')
            .toString()
            .toLowerCase();
        final status = (issue['status'] ?? issue['Marker_Issue_Status'] ?? '')
            .toString()
            .toLowerCase();
        final priority =
            (issue['priority'] ?? issue['Marker_Issue_Priority'] ?? '')
                .toString()
                .toLowerCase();

        final matchesSearch = title.contains(_searchQuery.toLowerCase());
        final matchesStatus =
            _selectedStatus == null || status == _selectedStatus!.toLowerCase();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        _buildFilters(isDark),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredIssues.isEmpty
              ? Center(
                  child: Text(
                    'NO ISSUES FOUND',
                    style: GoogleFonts.orbitron(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _filteredIssues.length,
                  itemBuilder: (context, index) =>
                      _IssueCard(issue: _filteredIssues[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildFilters(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (v) {
                _searchQuery = v;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Search issues...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.black.withOpacity(0.02),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildDropdown(
            'STATUS',
            _selectedStatus,
            ['OPEN', 'IN-PROGRESS', 'CLOSED'],
            (v) {
              setState(() => _selectedStatus = v);
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String hint,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          items: [
            DropdownMenuItem(value: null, child: Text('ALL $hint')),
            ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
          ],
          onChanged: onChanged,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
          dropdownColor: isDark ? XRDockTheme.deepNavy : Colors.white,
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final Map<String, dynamic> issue;
  const _IssueCard({required this.issue});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String priority =
        (issue['priority'] ?? issue['Marker_Issue_Priority'] ?? 'medium')
            .toString()
            .toLowerCase();

    Color priorityColor = Colors.green;
    if (priority == 'urgent' || priority == 'high')
      priorityColor = Colors.redAccent;
    if (priority == 'medium') priorityColor = Colors.orangeAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: priorityColor,
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
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'STATUS: ${(issue['status'] ?? issue['Marker_Issue_Status'] ?? 'OPEN').toString().toUpperCase()}',
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: Colors.grey.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}
