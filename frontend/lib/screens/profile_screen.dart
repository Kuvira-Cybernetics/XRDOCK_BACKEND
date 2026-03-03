import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../common/common.dart';
import '../theme/xrdock_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _phoneController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyWebsiteController = TextEditingController();
  final _industryController = TextEditingController();
  final _employeeCountController = TextEditingController();
  final _countryController = TextEditingController();
  final _projectTypeController = TextEditingController();
  final _expectedSeatsController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingProfile = true;
  Map<String, dynamic>? _backendUser;
  String? _base64Image;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _base64Image = base64Encode(bytes);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
    _fetchBackendProfile();
  }

  Future<void> _fetchBackendProfile() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _backendUser = json.decode(response.body);
            // Pre-fill controllers
            _nameController.text =
                _backendUser?['name'] ??
                FirebaseAuth.instance.currentUser?.displayName ??
                '';
            _jobTitleController.text = _backendUser?['job_title'] ?? '';
            _phoneController.text = _backendUser?['phone_number'] ?? '';
            _linkedinController.text = _backendUser?['linkedin_url'] ?? '';
            _companyNameController.text = _backendUser?['company_name'] ?? '';
            _companyWebsiteController.text =
                _backendUser?['company_website'] ?? '';
            _industryController.text = _backendUser?['industry'] ?? '';
            _employeeCountController.text =
                _backendUser?['employee_count'] ?? '';
            _countryController.text = _backendUser?['country'] ?? '';
            _projectTypeController.text = _backendUser?['project_type'] ?? '';
            _expectedSeatsController.text =
                _backendUser?['expected_seats']?.toString() ?? '';
            _base64Image = _backendUser?['profile_image'];
          });
        }
      }
    } catch (_) {
      // silently ignore network errors
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      // 1. Update Firebase Name
      await FirebaseAuth.instance.currentUser?.updateDisplayName(
        _nameController.text.trim(),
      );

      // 2. Update Backend Profile
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final body = jsonEncode({
        'name': _nameController.text.trim(),
        'job_title': _jobTitleController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'linkedin_url': _linkedinController.text.trim(),
        'company_name': _companyNameController.text.trim(),
        'company_website': _companyWebsiteController.text.trim(),
        'industry': _industryController.text.trim(),
        'employee_count': _employeeCountController.text.trim(),
        'country': _countryController.text.trim(),
        'project_type': _projectTypeController.text.trim(),
        'expected_seats': int.tryParse(_expectedSeatsController.text.trim()),
        if (_base64Image != null) 'profile_image': _base64Image,
      });

      final response = await http.post(
        Uri.parse('${CommonData.backendUrl}/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200 && mounted) {
        CommonData.showCustomSnackBar(context, 'Profile updated successfully!');
      } else if (mounted) {
        throw Exception('Failed to update profile on backend.');
      }
    } catch (e) {
      if (mounted) {
        CommonData.showCustomSnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LOG OUT'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await CommonData.logout(context);
    // Routing handled seamlessly via AuthWrapper stream emit.
  }

  String _formatExpiry(String? expiryStr) {
    if (expiryStr == null) return 'No active plan';
    try {
      final dt = DateTime.parse(expiryStr).toLocal();
      final diff = dt.difference(DateTime.now());
      if (diff.isNegative) return 'EXPIRED';
      if (diff.inDays > 365) return 'Lifetime / Admin';
      return '${dt.day}/${dt.month}/${dt.year} (${diff.inDays} days left)';
    } catch (_) {
      return 'N/A';
    }
  }

  String _planLabel(String? plan) {
    switch (plan) {
      case 'basic':
        return '₹599 / mo  •  BASIC';
      case 'pro':
        return '₹999 / mo  •  PRO';
      case 'enterprise':
        return '₹1299 / mo  •  ENTERPRISE';
      default:
        return 'No Plan';
    }
  }

  Color _planColor(String? plan) {
    switch (plan) {
      case 'basic':
        return const Color(0xFF4F9CF9);
      case 'pro':
        return const Color(0xFF00D4FF);
      case 'enterprise':
        return const Color(0xFFB16CEA);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = _backendUser?['subscription_plan'] ?? 'No Plan';
    final isAdmin = _backendUser?['is_admin'] == true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Scrollbar(
        child: SingleChildScrollView(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth > 900;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 32.0,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? XRDockTheme.deepNavy.withOpacity(0.8)
                            : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.withOpacity(0.2),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              isDark ? 0.4 : 0.05,
                            ),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Top Gradient Banner
                              _buildGradientBanner(isDark),

                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  32,
                                  0,
                                  32,
                                  32,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 2. Profile Header Row
                                    _buildProfileHeader(user, isDark),

                                    const SizedBox(height: 32),

                                    if (_isLoadingProfile)
                                      const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(64),
                                          child: CircularProgressIndicator(),
                                        ),
                                      )
                                    else ...[
                                      // 3. Form Grid
                                      _buildFormGrid(isDesktop, isDark),

                                      const SizedBox(height: 48),

                                      // 4. Email Section
                                      _buildEmailSection(user, isDark),

                                      const SizedBox(height: 32),
                                      _buildSubscriptionSummary(
                                        plan,
                                        isAdmin,
                                        isDark,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGradientBanner(bool isDark) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        gradient: LinearGradient(
          colors: isDark
              ? [XRDockTheme.deepNavy, XRDockTheme.secondaryPurple]
              : [const Color(0xFFE0EAFC), const Color(0xFFCFDEF3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildProfileHeader(User? user, bool isDark) {
    return Transform.translate(
      offset: const Offset(0, -30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF15191C) : Colors.white,
                    width: 4,
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                  backgroundImage:
                      _base64Image != null && _base64Image!.isNotEmpty
                      ? MemoryImage(base64Decode(_base64Image!))
                      : (user?.photoURL != null
                            ? NetworkImage(user!.photoURL!) as ImageProvider
                            : null),
                  child:
                      (_base64Image == null || _base64Image!.isEmpty) &&
                          user?.photoURL == null
                      ? Text(
                          (_nameController.text.isNotEmpty
                                  ? _nameController.text
                                  : (user?.email ?? '?'))
                              .substring(0, 1)
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 40,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Name and Email
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _nameController.text.isEmpty
                      ? 'NEW USER'
                      : _nameController.text.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: GoogleFonts.poppins(
                    color: Colors.grey[500],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          // Save Button (Edit/Save)
          ElevatedButton(
            onPressed: _isLoading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'SAVE CHANGES',
                    style: GoogleFonts.orbitron(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormGrid(bool isDesktop, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Contact Information', isDark),
        _buildResponsiveRow(isDesktop, [
          _buildModernField(_nameController, "Full Name", "Your Full Name"),
          _buildModernField(_phoneController, "Phone", "Phone Number"),
        ]),
        _buildResponsiveRow(isDesktop, [
          _buildModernField(_jobTitleController, "Job Title", "e.g. Architect"),
          _buildModernField(_linkedinController, "LinkedIn", "Profile URL"),
        ]),

        _buildSectionHeader('Company Details', isDark),
        _buildResponsiveRow(isDesktop, [
          _buildModernField(
            _companyNameController,
            "Company Name",
            "Your Company",
          ),
          _buildModernField(
            _companyWebsiteController,
            "Website",
            "e.g. https://...",
          ),
        ]),
        _buildResponsiveRow(isDesktop, [
          _buildModernField(
            _industryController,
            "Industry",
            "e.g. Construction",
          ),
          _buildModernField(
            _employeeCountController,
            "Company Size",
            "e.g. 1-10",
          ),
        ]),
        _buildResponsiveRow(isDesktop, [
          _buildModernCountryDropdown(isDark),
          _buildModernField(
            _projectTypeController,
            "Project Type",
            "e.g. Simulation",
          ),
        ]),

        _buildSectionHeader('Primary Use Case', isDark),
        _buildResponsiveRow(isDesktop, [
          _buildModernField(
            _expectedSeatsController,
            "Expected Seats",
            "Quantity",
            isNumber: true,
          ),
          const SizedBox.shrink(), // Spacer for balance
        ]),
      ],
    );
  }

  Widget _buildResponsiveRow(bool isDesktop, List<Widget> children) {
    if (!isDesktop) return Column(children: children);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Expanded(child: children[0]),
          const SizedBox(width: 24),
          Expanded(child: children[1]),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 20),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
          color: isDark ? Colors.white70 : Colors.black45,
        ),
      ),
    );
  }

  Widget _buildModernField(
    TextEditingController controller,
    String label,
    String hint, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: 13,
              ),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCountryDropdown(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Country",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _countryController.text.isEmpty
                ? null
                : _countryController.text,
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items:
                [
                      'United States',
                      'India',
                      'United Kingdom',
                      'Canada',
                      'Australia',
                      'Germany',
                      'France',
                      'Other',
                    ]
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text(c, style: GoogleFonts.exo2(fontSize: 14)),
                      ),
                    )
                    .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _countryController.text = val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmailSection(User? user, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "MY EMAIL ADDRESS",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.blue[50]?.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isDark
                    ? Colors.blue.withOpacity(0.2)
                    : Colors.blue[100],
                child: const Icon(
                  Icons.email_outlined,
                  color: Colors.blue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.email ?? 'N/A',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "PRIMARY EMAIL",
                      style: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionSummary(String plan, bool isAdmin, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAdmin ? 'Plan: ADMIN' : 'Plan: ${plan.toUpperCase()}',
                  style: TextStyle(
                    color: _planColor(plan),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isAdmin
                      ? 'Perpetual Access'
                      : _formatExpiry(_backendUser?['subscription_expiry']),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
            /* 
            if (!isAdmin && plan != 'No Plan') ...[
              const SizedBox(width: 24),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/subscribe'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _planColor(plan),
                  side: BorderSide(color: _planColor(plan).withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'RENEW / UPGRADE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            */
          ],
        ),
        TextButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, size: 18),
          label: Text(
            'LOG OUT',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
        ),
      ],
    );
  }
}
