import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../common/common.dart';
import '../theme/xrdock_theme.dart';
import '../widgets/autodesk_file_browser.dart';
import 'dart:ui';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _localSyncPathController = TextEditingController();
  final _bimUploadHubIdController = TextEditingController();
  final _bimUploadHubNameController = TextEditingController();
  final _bimUploadProjectIdController = TextEditingController();
  final _bimUploadProjectNameController = TextEditingController();
  final _bimUploadFolderIdController = TextEditingController();
  final _bimUploadFolderNameController = TextEditingController();
  final _bimUploadPathDisplayController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            final data = json.decode(response.body);
            _localSyncPathController.text = data['local_sync_path'] ?? '';
            _bimUploadHubIdController.text = data['bim_upload_hub_id'] ?? '';
            _bimUploadHubNameController.text =
                data['bim_upload_hub_name'] ?? '';
            _bimUploadProjectIdController.text =
                data['bim_upload_project_id'] ?? '';
            _bimUploadProjectNameController.text =
                data['bim_upload_project_name'] ?? '';
            _bimUploadFolderIdController.text =
                data['bim_upload_folder_id'] ?? '';
            _bimUploadFolderNameController.text =
                data['bim_upload_folder_name'] ?? '';
            _updatePathDisplay();
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingSettings = false);
    }
  }

  void _updatePathDisplay() {
    String h = _bimUploadHubNameController.text;
    String p = _bimUploadProjectNameController.text;
    String f = _bimUploadFolderNameController.text;

    // Fallback to placeholders if IDs exist but names don't (backwards compatibility)
    if (h.isEmpty && _bimUploadHubIdController.text.isNotEmpty) h = "Hub";
    if (p.isEmpty && _bimUploadProjectIdController.text.isNotEmpty)
      p = "Project";
    if (f.isEmpty && _bimUploadFolderIdController.text.isNotEmpty) f = "Folder";

    if (h.isEmpty && p.isEmpty && f.isEmpty) {
      _bimUploadPathDisplayController.text = "";
    } else {
      _bimUploadPathDisplayController.text = "$h > $p > $f";
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final body = jsonEncode({
        'local_sync_path': _localSyncPathController.text.trim(),
        'bim_upload_hub_id': _bimUploadHubIdController.text.trim(),
        'bim_upload_hub_name': _bimUploadHubNameController.text.trim(),
        'bim_upload_project_id': _bimUploadProjectIdController.text.trim(),
        'bim_upload_project_name': _bimUploadProjectNameController.text.trim(),
        'bim_upload_folder_id': _bimUploadFolderIdController.text.trim(),
        'bim_upload_folder_name': _bimUploadFolderNameController.text.trim(),
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
        CommonData.showCustomSnackBar(
          context,
          'Settings updated successfully!',
        );
      } else if (mounted) {
        throw Exception('Failed to update settings');
      }
    } catch (e) {
      if (mounted) {
        CommonData.showCustomSnackBar(context, 'Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Scrollbar(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
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
                        color: Colors.black.withOpacity(isDark ? 0.4 : 0.05),
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
                          Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [
                                        XRDockTheme.deepNavy,
                                        XRDockTheme.secondaryPurple,
                                      ]
                                    : [
                                        const Color(0xFFE0EAFC),
                                        const Color(0xFFCFDEF3),
                                      ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: Text(
                                  'SETTINGS',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: _isLoadingSettings
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'DESKTOP SYNC SETTINGS',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 2,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black45,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "LOCAL SYNC FOLDER PATH",
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                TextFormField(
                                                  controller:
                                                      _localSyncPathController,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        "e.g. C:\\Models or /Users/Name/Models",
                                                    hintStyle:
                                                        GoogleFonts.poppins(
                                                          color:
                                                              Colors.grey[400],
                                                          fontSize: 13,
                                                        ),
                                                    filled: true,
                                                    fillColor: isDark
                                                        ? Colors.white
                                                              .withOpacity(0.05)
                                                        : Colors.grey[100],
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      borderSide:
                                                          BorderSide.none,
                                                    ),
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 14,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        "This path is where local projects are scanned from on the desktop app host machine.",
                                        style: GoogleFonts.poppins(
                                          color: Colors.grey[500],
                                          fontSize: 11,
                                        ),
                                      ),
                                      if (CommonData.isAutodeskUser) ...[
                                        const SizedBox(height: 32),
                                        Text(
                                          'AUTODESK UPLOAD SETTINGS',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black45,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          "Selected BIM Target Path",
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller:
                                              _bimUploadPathDisplayController,
                                          readOnly: true,
                                          decoration: InputDecoration(
                                            hintText:
                                                "Hub > Project > Folder will appear here",
                                            hintStyle: GoogleFonts.poppins(
                                              color: Colors.grey[400],
                                              fontSize: 13,
                                            ),
                                            filled: true,
                                            fillColor: isDark
                                                ? Colors.white.withOpacity(0.05)
                                                : Colors.grey[100],
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 14,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    const Text(
                                                      'Select Default Upload Folder',
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(
                                                        Icons.close,
                                                        color: Colors.red,
                                                      ),
                                                      onPressed: () =>
                                                          Navigator.pop(ctx),
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(),
                                                      splashRadius: 20,
                                                    ),
                                                  ],
                                                ),
                                                content: SizedBox(
                                                  width: 600,
                                                  height: 500,
                                                  child: AutodeskFileBrowser(
                                                    allowFolderSelection: true,
                                                    initialHubId:
                                                        _bimUploadHubIdController
                                                            .text
                                                            .isNotEmpty
                                                        ? _bimUploadHubIdController
                                                              .text
                                                        : null,
                                                    initialProjectId:
                                                        _bimUploadProjectIdController
                                                            .text
                                                            .isNotEmpty
                                                        ? _bimUploadProjectIdController
                                                              .text
                                                        : null,
                                                    initialFolderId:
                                                        _bimUploadFolderIdController
                                                            .text
                                                            .isNotEmpty
                                                        ? _bimUploadFolderIdController
                                                              .text
                                                        : null,
                                                    onFolderSelected:
                                                        (
                                                          hubId,
                                                          hubName,
                                                          projectId,
                                                          projectName,
                                                          folderId,
                                                          folderName,
                                                        ) {
                                                          setState(() {
                                                            _bimUploadHubIdController
                                                                    .text =
                                                                hubId;
                                                            _bimUploadHubNameController
                                                                    .text =
                                                                hubName;
                                                            _bimUploadProjectIdController
                                                                    .text =
                                                                projectId;
                                                            _bimUploadProjectNameController
                                                                    .text =
                                                                projectName;
                                                            _bimUploadFolderIdController
                                                                    .text =
                                                                folderId;
                                                            _bimUploadFolderNameController
                                                                    .text =
                                                                folderName;
                                                            _updatePathDisplay();
                                                          });
                                                          Navigator.pop(ctx);
                                                        },
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child: const Text('CANCEL'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.folder_open),
                                          label: Text(
                                            'BROWSE AUTODESK HUBS',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blueAccent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 32),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: ElevatedButton(
                                          onPressed: _isLoading
                                              ? null
                                              : _saveSettings,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(
                                              context,
                                            ).primaryColor,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 32,
                                              vertical: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 0,
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                )
                                              : Text(
                                                  'SAVE SETTINGS',
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                        ),
                                      ),
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
          ),
        ),
      ),
    );
  }
}
