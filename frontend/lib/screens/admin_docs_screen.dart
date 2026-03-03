import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'help_support_screen.dart';
import '../common/common.dart';
import '../theme/xrdock_theme.dart';

class AdminDocsScreen extends StatefulWidget {
  const AdminDocsScreen({super.key});

  @override
  State<AdminDocsScreen> createState() => _AdminDocsScreenState();
}

class _AdminDocsScreenState extends State<AdminDocsScreen> {
  List<dynamic> _topics = [];
  bool _isLoading = true;
  dynamic _selectedTopic;

  @override
  void initState() {
    super.initState();
    _fetchTopics();
  }

  Future<void> _fetchTopics() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/docs/content'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _topics = json.decode(response.body);
          if (_selectedTopic != null) {
            _selectedTopic = _topics.firstWhere(
              (t) => t['id'] == _selectedTopic['id'],
              orElse: () => null,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching topics: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<bool> _showDeleteConfirm(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              title,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
            content: Text(content, style: GoogleFonts.poppins()),
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
        ) ??
        false;
  }

  Future<void> _deleteTopic(int topicId) async {
    if (!await _showDeleteConfirm(
      'Delete Topic',
      'Are you sure you want to delete this topic and all its sections? This action cannot be undone.',
    )) {
      return;
    }
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.delete(
        Uri.parse('${CommonData.backendUrl}/admin/docs/topics/$topicId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        if (_selectedTopic?['id'] == topicId) _selectedTopic = null;
        _fetchTopics();
      }
    } catch (e) {
      debugPrint('Error deleting topic: $e');
    }
  }

  Future<void> _deleteSection(int id) async {
    if (!await _showDeleteConfirm(
      'Delete Section',
      'Are you sure you want to delete this section? This action cannot be undone.',
    )) {
      return;
    }
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.delete(
        Uri.parse('${CommonData.backendUrl}/admin/docs/sections/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _fetchTopics();
      }
    } catch (e) {
      debugPrint('Error deleting section: $e');
    }
  }

  void _showTopicDialog({dynamic topic}) {
    showDialog(
      context: context,
      builder: (context) => _TopicEditDialog(
        topic: topic,
        allTopics: _topics,
        onSave: _fetchTopics,
      ),
    );
  }

  void _showSectionDialog({int? topicId, dynamic section}) {
    showDialog(
      context: context,
      builder: (context) => _SectionEditDialog(
        topicId: topicId ?? _selectedTopic['id'],
        section: section,
        onSave: _fetchTopics,
      ),
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
            _buildHeader(isDark),
            const SizedBox(height: 32),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Topics List
                        SizedBox(width: 300, child: _buildTopicList(isDark)),
                        const SizedBox(width: 32),
                        // Sections List
                        Expanded(
                          child: _selectedTopic == null
                              ? Center(
                                  child: Text(
                                    'Select a topic to manage content',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : _buildSectionList(isDark),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DOCS MANAGEMENT',
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
        ElevatedButton.icon(
          onPressed: () => _showTopicDialog(),
          icon: const Icon(Icons.add),
          label: Text(
            'NEW TOPIC',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: XRDockTheme.primaryPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        const SizedBox(width: 16),
        IconButton(
          onPressed: _fetchTopics,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildTopicList(bool isDark) {
    // 1. Organize topics into hierarchy
    final parentTopics = _topics.where((t) => t['parent_id'] == null).toList();

    return ListView.builder(
      itemCount: parentTopics.length,
      itemBuilder: (context, index) {
        final topic = parentTopics[index];
        final subTopics = _topics
            .where((t) => t['parent_id'] == topic['id'])
            .toList();

        return Column(
          children: [
            _buildTopicTile(topic, isDark, indent: 0),
            if (subTopics.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Column(
                  children: subTopics
                      .map((st) => _buildTopicTile(st, isDark, indent: 1))
                      .toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTopicTile(dynamic topic, bool isDark, {int indent = 0}) {
    final isSelected = _selectedTopic?['id'] == topic['id'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => setState(() => _selectedTopic = topic),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? XRDockTheme.primaryPurple.withOpacity(0.1)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? XRDockTheme.primaryPurple
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              if (indent > 0)
                const Icon(
                  Icons.subdirectory_arrow_right,
                  size: 14,
                  color: Colors.grey,
                ),
              if (indent > 0) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  topic['title'],
                  style: GoogleFonts.poppins(
                    fontSize: indent > 0 ? 12 : 14,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? XRDockTheme.primaryPurple
                        : (isDark ? Colors.white : Colors.black),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showTopicDialog(topic: topic),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Colors.redAccent,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _deleteTopic(topic['id']),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionList(bool isDark) {
    final sections = _selectedTopic['sections'] as List;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'SECTIONS IN: ${_selectedTopic['title']}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showSectionDialog(),
              icon: const Icon(Icons.add),
              label: Text(
                'ADD SECTION',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: sections.length,
            itemBuilder: (context, index) {
              final section = sections[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: XRDockTheme.primaryPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _getSectionIcon(section['type']),
                  ),
                  title: Text(
                    section['title']?.toUpperCase() ?? '(NO TITLE)',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'TYPE: ${section['type'].toString().toUpperCase()}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey,
                      letterSpacing: 1.1,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showSectionDialog(section: section),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _deleteSection(section['id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _getSectionIcon(String type) {
    switch (type) {
      case 'heading':
        return const Icon(Icons.title);
      case 'text':
        return const Icon(Icons.subject);
      case 'video':
        return const Icon(Icons.play_circle_outline, color: Colors.red);
      case 'image':
        return const Icon(Icons.image_outlined, color: Colors.blue);
      case 'video_gallery':
        return const Icon(
          Icons.video_library_outlined,
          color: Colors.redAccent,
        );
      case 'image_gallery':
        return const Icon(Icons.collections_outlined, color: Colors.blueAccent);
      default:
        return const Icon(Icons.help_outline);
    }
  }
}

class _TopicEditDialog extends StatefulWidget {
  final dynamic topic;
  final List<dynamic> allTopics;
  final VoidCallback onSave;

  const _TopicEditDialog({
    this.topic,
    required this.allTopics,
    required this.onSave,
  });

  @override
  State<_TopicEditDialog> createState() => _TopicEditDialogState();
}

class _TopicEditDialogState extends State<_TopicEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _orderController;
  int? _parentId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.topic?['title'] ?? '',
    );
    _orderController = TextEditingController(
      text: (widget.topic?['order_index'] ?? 0).toString(),
    );
    _parentId = widget.topic?['parent_id'];
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final body = {
        'title': _titleController.text,
        'order_index': int.tryParse(_orderController.text) ?? 0,
        'parent_id': _parentId,
      };

      final url = widget.topic == null
          ? '${CommonData.backendUrl}/admin/docs/topics'
          : '${CommonData.backendUrl}/admin/docs/topics/${widget.topic['id']}';

      final response = await (widget.topic == null
          ? http.post(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
          : http.patch(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            ));

      if (response.statusCode == 200) {
        widget.onSave();
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving topic: $e');
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.topic == null ? 'NEW TOPIC' : 'EDIT TOPIC',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TITLE',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(),
          ),
          const SizedBox(height: 20),
          Text(
            'PARENT TOPIC (FOR SUBTOPICS)',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            value: _parentId,
            decoration: const InputDecoration(),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('NONE (PRIMARY TOPIC)'),
              ),
              ...widget.allTopics
                  .where(
                    (t) =>
                        t['parent_id'] == null &&
                        t['id'] != widget.topic?['id'],
                  )
                  .map(
                    (t) => DropdownMenuItem<int?>(
                      value: t['id'],
                      child: Text(t['title']),
                    ),
                  ),
            ],
            onChanged: (val) => setState(() => _parentId = val),
          ),
          const SizedBox(height: 20),
          Text(
            'ORDER INDEX',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _orderController,
            decoration: const InputDecoration(),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}

class _SectionEditDialog extends StatefulWidget {
  final int topicId;
  final dynamic section;
  final VoidCallback onSave;

  const _SectionEditDialog({
    required this.topicId,
    this.section,
    required this.onSave,
  });

  @override
  State<_SectionEditDialog> createState() => _SectionEditDialogState();
}

class _SectionEditDialogState extends State<_SectionEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _mediaUrlController;
  late TextEditingController _orderController;
  late TextEditingController _mediaListController;
  String _type = 'text';
  bool _isSaving = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.section?['title'] ?? '',
    );
    _contentController = TextEditingController(
      text: widget.section?['content_text'] ?? '',
    );
    _mediaUrlController = TextEditingController(
      text: widget.section?['media_url'] ?? '',
    );
    _orderController = TextEditingController(
      text: (widget.section?['order_index'] ?? 0).toString(),
    );
    _mediaListController = TextEditingController(
      text: widget.section?['media_list'] ?? '[]',
    );
    _type = widget.section?['type'] ?? 'text';
  }

  Future<void> _uploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'mp4', 'mov'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _isUploading = true);
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('${CommonData.backendUrl}/admin/docs/upload'),
        );
        request.headers['Authorization'] = 'Bearer $token';

        final file = result.files.first;
        if (file.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              file.bytes!,
              filename: file.name,
            ),
          );
        }

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _mediaUrlController.text = data['url'];
          });
        }
      } catch (e) {
        debugPrint('Upload error: $e');
      }
      setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final body = {
        'topic_id': widget.topicId,
        'type': _type,
        'title': _titleController.text,
        'content_text': _contentController.text,
        'media_url': _mediaUrlController.text,
        'media_list': _mediaListController.text,
        'order_index': int.tryParse(_orderController.text) ?? 0,
      };

      final url = widget.section == null
          ? '${CommonData.backendUrl}/admin/docs/sections'
          : '${CommonData.backendUrl}/admin/docs/sections/${widget.section['id']}';

      final response = await (widget.section == null
          ? http.post(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
          : http.patch(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            ));

      if (response.statusCode == 200) {
        widget.onSave();
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving section: $e');
    }
    setState(() => _isSaving = false);
  }

  void _addGalleryItem() {
    final list = json.decode(_mediaListController.text) as List;
    list.add({'title': '', 'url': '', 'thumbnail': ''});
    setState(() {
      _mediaListController.text = json.encode(list);
    });
  }

  void _updateGalleryItem(int index, String key, String value) {
    final list = json.decode(_mediaListController.text) as List;
    list[index][key] = value;
    _mediaListController.text = json.encode(list);
  }

  void _removeGalleryItem(int index) {
    final list = json.decode(_mediaListController.text) as List;
    list.removeAt(index);
    setState(() {
      _mediaListController.text = json.encode(list);
    });
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> galleryItems = [];
    try {
      galleryItems = json.decode(_mediaListController.text);
    } catch (_) {
      galleryItems = [];
    }

    return AlertDialog(
      title: Text(
        widget.section == null ? 'NEW SECTION' : 'EDIT SECTION',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONTENT TYPE',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _type,
                items:
                    [
                          'heading',
                          'text',
                          'video',
                          'image',
                          'video_gallery',
                          'image_gallery',
                        ]
                        .map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (val) => setState(() => _type = val!),
                decoration: const InputDecoration(),
              ),
              const SizedBox(height: 20),
              Text(
                'SECTION TITLE',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(),
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 20),
              if (_type == 'text') ...[
                Text(
                  'CONTENT BODY (MARKDOWN)',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                MarkdownToolbar(controller: _contentController),
                const SizedBox(height: 0),
                TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 12,
                  style: GoogleFonts.robotoMono(fontSize: 13),
                ),
              ],
              if (_type == 'video' || _type == 'image') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _mediaUrlController,
                        decoration: InputDecoration(
                          labelText: 'MEDIA URL',
                          labelStyle: GoogleFonts.poppins(fontSize: 12),
                        ),
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isUploading ? null : _uploadFile,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      tooltip: 'Upload Media',
                    ),
                    if (_mediaUrlController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.green,
                        ),
                        tooltip: 'Preview Media',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('MEDIA PREVIEW'),
                              content: SizedBox(
                                width: 600,
                                child: _type == 'video'
                                    ? UnifiedVideoPlayer(
                                        url: _mediaUrlController.text,
                                        title: null,
                                        height: 350,
                                      )
                                    : Image.network(
                                        _mediaUrlController.text.startsWith(
                                              'http',
                                            )
                                            ? _mediaUrlController.text
                                            : '${CommonData.backendUrl}${_mediaUrlController.text}',
                                      ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('CLOSE'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
              if (_type == 'video_gallery' || _type == 'image_gallery') ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'GALLERY ITEMS',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _addGalleryItem,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text(
                        'ADD ITEM',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...galleryItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TITLE',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.withOpacity(0.2),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.withOpacity(0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: XRDockTheme.primaryPurple,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 12,
                                  ),
                                ),
                                controller:
                                    TextEditingController(text: item['title'])
                                      ..selection = TextSelection.fromPosition(
                                        TextPosition(
                                          offset: item['title'].length,
                                        ),
                                      ),
                                onChanged: (val) =>
                                    _updateGalleryItem(index, 'title', val),
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'URL',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.withOpacity(0.2),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: Colors.grey.withOpacity(0.2),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(
                                      color: XRDockTheme.primaryPurple,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 12,
                                  ),
                                ),
                                controller:
                                    TextEditingController(text: item['url'])
                                      ..selection = TextSelection.fromPosition(
                                        TextPosition(
                                          offset: item['url'].length,
                                        ),
                                      ),
                                onChanged: (val) =>
                                    _updateGalleryItem(index, 'url', val),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 22,
                              ),
                              onPressed: () async {
                                if (await (context as Element)
                                    .findAncestorStateOfType<
                                      _AdminDocsScreenState
                                    >()!
                                    ._showDeleteConfirm(
                                      'Remove Item',
                                      'Are you sure you want to remove this item from the gallery?',
                                    )) {
                                  _removeGalleryItem(index);
                                }
                              },
                              tooltip: 'Remove Item',
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.green,
                                size: 22,
                              ),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('GALLERY PREVIEW'),
                                    content: SizedBox(
                                      width: 600,
                                      height: 400,
                                      child: UnifiedVideoPlayer(
                                        url: item['url'],
                                      ),
                                    ),
                                  ),
                                );
                              },
                              tooltip: 'Preview Video',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
              const SizedBox(height: 16),
              Text(
                'DISPLAY ORDER',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _orderController,
                decoration: const InputDecoration(),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: XRDockTheme.primaryPurple,
            foregroundColor: Colors.white,
          ),
          child: const Text('SAVE SECTION'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// MarkdownToolbar — inserts / wraps markdown syntax in a TextEditingController
// ---------------------------------------------------------------------------

class MarkdownToolbar extends StatelessWidget {
  final TextEditingController controller;
  const MarkdownToolbar({super.key, required this.controller});

  void _wrap(String before, String after) {
    final text = controller.text;
    final sel = controller.selection;
    if (!sel.isValid) {
      controller.text = '$text$before$after';
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length - after.length,
      );
      return;
    }
    final selected = sel.textInside(text);
    final newText = text.replaceRange(
      sel.start,
      sel.end,
      '$before$selected$after',
    );
    controller.text = newText;
    controller.selection = TextSelection(
      baseOffset: sel.start + before.length,
      extentOffset: sel.start + before.length + selected.length,
    );
  }

  void _insertAtLineStart(String prefix) {
    final text = controller.text;
    final sel = controller.selection;
    final offset = sel.isValid ? sel.start : text.length;
    final lineStart = text.lastIndexOf('\n', offset - 1) + 1;
    final newText =
        text.substring(0, lineStart) + prefix + text.substring(lineStart);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(
      offset: offset + prefix.length,
    );
  }

  void _insertSnippet(String snippet) {
    final text = controller.text;
    final sel = controller.selection;
    final at = sel.isValid ? sel.start : text.length;
    final newText = text.substring(0, at) + snippet + text.substring(at);
    controller.text = newText;
    controller.selection = TextSelection.collapsed(offset: at + snippet.length);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white24 : Colors.grey.shade300;
    final toolbarBg = isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade50;
    final toolbarText = isDark ? Colors.white70 : Colors.black54;
    final toolbarHover = isDark ? Colors.white10 : Colors.grey.shade200;

    Widget toolBtn(String label, String tip, VoidCallback action) {
      return Tooltip(
        message: tip,
        child: InkWell(
          onTap: action,
          borderRadius: BorderRadius.circular(4),
          hoverColor: toolbarHover,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: toolbarText,
              ),
            ),
          ),
        ),
      );
    }

    Widget divider() => Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: borderColor,
    );

    final groups = [
      [
        toolBtn('B', 'Bold', () => _wrap('**', '**')),
        toolBtn('I', 'Italic', () => _wrap('*', '*')),
        toolBtn('S̶', 'Strikethrough', () => _wrap('~~', '~~')),
      ],
      [
        toolBtn('H1', 'Heading 1', () => _insertAtLineStart('# ')),
        toolBtn('H2', 'Heading 2', () => _insertAtLineStart('## ')),
        toolBtn('H3', 'Heading 3', () => _insertAtLineStart('### ')),
      ],
      [
        toolBtn('•', 'Bullet List', () => _insertAtLineStart('- ')),
        toolBtn('1.', 'Numbered List', () => _insertAtLineStart('1. ')),
        toolBtn('❝', 'Blockquote', () => _insertAtLineStart('> ')),
      ],
      [
        toolBtn('`', 'Inline Code', () => _wrap('`', '`')),
        toolBtn('{}', 'Code Block', () => _wrap('```\n', '\n```')),
      ],
      [
        toolBtn('—', 'Horizontal Rule', () => _insertSnippet('\n\n---\n\n')),
        toolBtn('🔗', 'Link', () => _wrap('[', '](url)')),
      ],
    ];

    return Container(
      decoration: BoxDecoration(
        color: toolbarBg,
        border: Border(
          top: BorderSide(color: borderColor),
          left: BorderSide(color: borderColor),
          right: BorderSide(color: borderColor),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: groups
            .expand<Widget>(
              (group) => [...group, if (group != groups.last) divider()],
            )
            .toList(),
      ),
    );
  }
}
