import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../common/common.dart';
import '../theme/xrdock_theme.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<dynamic> _allUsers = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/users'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _allUsers = data;
          _filteredUsers = data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
    setState(() => _isLoading = false);
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredUsers = _allUsers.where((user) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    });
  }

  void _showUserDetail(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UserDetailSheet(user: user, onUpdate: _fetchUsers),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'USER MANAGEMENT',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        color: isDark ? Colors.white : XRDockTheme.deepNavy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 4,
                      width: 60,
                      decoration: BoxDecoration(
                        gradient: XRDockTheme.purpleGradient,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: _fetchUsers,
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 32),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildUserTable(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTable(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            showCheckboxColumn: false,
            headingRowColor: MaterialStateProperty.all(
              isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.withOpacity(0.05),
            ),
            columns: [
              DataColumn(label: _buildColumnLabel('NAME')),
              DataColumn(label: _buildColumnLabel('EMAIL')),
              DataColumn(label: _buildColumnLabel('COMPANY')),
              DataColumn(label: _buildColumnLabel('ROLE')),
              DataColumn(label: _buildColumnLabel('ADMIN')),
            ],
            rows: _filteredUsers.map((user) {
              return DataRow(
                onSelectChanged: (_) => _showUserDetail(user),
                cells: [
                  DataCell(
                    Text(user['name'] ?? 'N/A', style: GoogleFonts.exo2()),
                  ),
                  DataCell(
                    Text(user['email'] ?? 'N/A', style: GoogleFonts.exo2()),
                  ),
                  DataCell(
                    Text(
                      user['company_name'] ?? 'N/A',
                      style: GoogleFonts.exo2(),
                    ),
                  ),
                  DataCell(
                    Text(user['job_title'] ?? 'N/A', style: GoogleFonts.exo2()),
                  ),
                  DataCell(
                    Icon(
                      user['is_admin'] == true
                          ? Icons.check_circle_rounded
                          : Icons.cancel_outlined,
                      color: user['is_admin'] == true
                          ? Colors.green
                          : Colors.grey,
                      size: 20,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildColumnLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _UserDetailSheet extends StatefulWidget {
  final Map<String, dynamic> user;
  final VoidCallback onUpdate;

  const _UserDetailSheet({required this.user, required this.onUpdate});

  @override
  State<_UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<_UserDetailSheet> {
  late TextEditingController _nameController;
  late TextEditingController _companyController;
  late TextEditingController _roleController;
  late bool _isAdmin;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name']);
    _companyController = TextEditingController(
      text: widget.user['company_name'],
    );
    _roleController = TextEditingController(text: widget.user['job_title']);
    _isAdmin = widget.user['is_admin'] == true;
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.put(
        Uri.parse('${CommonData.backendUrl}/users/${widget.user['id']}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': _nameController.text,
          'company_name': _companyController.text,
          'job_title': _roleController.text,
          'is_admin': _isAdmin,
        }),
      );

      if (response.statusCode == 200) {
        widget.onUpdate();
        Navigator.pop(context);
        CommonData.showCustomSnackBar(context, 'User updated successfully');
      }
    } catch (e) {
      debugPrint('Error updating user: $e');
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? XRDockTheme.deepNavy : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'USER DETAILS',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildTextField('FULL NAME', _nameController, Icons.person_outline),
          const SizedBox(height: 16),
          _buildTextField(
            'COMPANY',
            _companyController,
            Icons.business_outlined,
          ),
          const SizedBox(height: 16),
          _buildTextField('JOB TITLE', _roleController, Icons.work_outline),
          const SizedBox(height: 16),
          SwitchListTile(
            title: Text(
              'ADMIN PRIVILEGES',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            value: _isAdmin,
            onChanged: (val) => setState(() => _isAdmin = val),
            activeColor: XRDockTheme.primaryPurple,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: XRDockTheme.primaryPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _isSaving ? null : _saveChanges,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'SAVE CHANGES',
                      style: GoogleFonts.orbitron(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: Colors.black.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
