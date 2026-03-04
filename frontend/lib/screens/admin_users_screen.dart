import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
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

  Future<void> _handleDeleteUser(dynamic user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Delete User',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => Navigator.pop(context, false),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${user['name']}? This action will also remove them from Firebase and cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'DELETE',
              style: GoogleFonts.poppins(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        final response = await http.delete(
          Uri.parse('${CommonData.backendUrl}/users/${user['id']}'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          CommonData.showCustomSnackBar(context, 'User deleted successfully');
          _fetchUsers();
        } else {
          CommonData.showCustomSnackBar(context, 'Failed to delete user');
        }
      } catch (e) {
        debugPrint('Error deleting user: $e');
        CommonData.showCustomSnackBar(context, 'Error deleting user');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
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
          child: SizedBox(
            width: double.infinity,
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
                DataColumn(label: _buildColumnLabel('ACTIONS')),
              ],
              rows: _filteredUsers.map((user) {
                return DataRow(
                  onSelectChanged: (_) => _showUserDetail(user),
                  cells: [
                    DataCell(
                      Text(user['name'] ?? 'N/A', style: GoogleFonts.poppins()),
                    ),
                    DataCell(
                      Text(
                        user['email'] ?? 'N/A',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                    DataCell(
                      Text(
                        user['company_name'] ?? 'N/A',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                    DataCell(
                      Text(
                        user['job_title'] ?? 'N/A',
                        style: GoogleFonts.poppins(),
                      ),
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
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _handleDeleteUser(user),
                            tooltip: 'Delete User',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
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
  String? _subscriptionPlan;
  DateTime? _subscriptionExpiry;
  bool _isSaving = false;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user['name']);
    _companyController = TextEditingController(
      text: widget.user['company_name'],
    );
    _roleController = TextEditingController(text: widget.user['job_title']);
    _isAdmin = widget.user['is_admin'] == true;
    _subscriptionPlan = widget.user['subscription_plan'];
    if (widget.user['subscription_expiry'] != null) {
      _subscriptionExpiry = DateTime.parse(widget.user['subscription_expiry']);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _subscriptionExpiry ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _subscriptionExpiry) {
      setState(() {
        _subscriptionExpiry = picked;
      });
    }
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
          'subscription_plan': _subscriptionPlan,
          'subscription_expiry': _subscriptionExpiry?.toIso8601String(),
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
          const SizedBox(height: 16),

          // Subscription Plan
          _buildDropdown(
            'SUBSCRIPTION PLAN',
            _subscriptionPlan,
            ['basic', 'pro', 'enterprise'],
            (val) => setState(() => _subscriptionPlan = val),
          ),
          const SizedBox(height: 16),

          // Expiry Date
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUBSCRIPTION EXPIRY',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _subscriptionExpiry == null
                            ? 'Select Date'
                            : _dateFormat.format(_subscriptionExpiry!),
                        style: GoogleFonts.poppins(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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

  Widget _buildDropdown(
    String label,
    String? value,
    List<String> options,
    Function(String?) onChanged,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text('Select Plan', style: GoogleFonts.poppins()),
              items: options
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(
                        p.toUpperCase(),
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
