import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../common/common.dart';
import '../theme/xrdock_theme.dart';

String _getYouTubeThumbnail(String url) {
  if (url.contains('youtube.com') || url.contains('youtu.be')) {
    final id = _extractYouTubeId(url);
    if (id != null) return 'https://img.youtube.com/vi/$id/0.jpg';
  }
  if (!url.startsWith('http')) {
    return '${CommonData.backendUrl}$url';
  }
  return url;
}

String? _extractYouTubeId(String url) {
  final regExp = RegExp(
    r'^(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
  );
  final match = regExp.firstMatch(url);
  return match?.group(1);
}

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int _selectedTopicIndex = 0;
  final ScrollController _contentScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _topics = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;
  int? _activeSectionId;
  bool _isAutoScrolling = false;

  // Track section keys for TOC jumping
  final Map<int, GlobalKey> _sectionKeys = {};

  @override
  void initState() {
    super.initState();
    _fetchDocumentation();
    _contentScrollController.addListener(_onContentScroll);
  }

  void _onContentScroll() {
    if (_sectionKeys.isEmpty || _isAutoScrolling) return;

    int? newActiveId;
    double minPositive = double.infinity;
    double maxNegative = double.negativeInfinity;
    int? maxNegativeId;

    for (final entry in _sectionKeys.entries) {
      final key = entry.value;
      if (key.currentContext != null) {
        final box = key.currentContext!.findRenderObject() as RenderBox?;
        if (box != null) {
          try {
            final position = box.localToGlobal(Offset.zero).dy;
            if (position > 0 && position < minPositive) {
              minPositive = position;
              if (position < 100) {
                newActiveId = entry.key;
              }
            }
            if (position <= 0 && position > maxNegative) {
              maxNegative = position;
              if (position.abs() < 100) {
                newActiveId = entry.key;
              }
              maxNegativeId = entry.key;
            }
          } catch (e) {}
        }
      }
    }

    newActiveId ??= maxNegativeId;

    if (newActiveId != null && _activeSectionId != newActiveId) {
      setState(() => _activeSectionId = newActiveId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDocumentation() async {
    try {
      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/docs/content'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _topics = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load documentation';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error connecting to server';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final response = await http.get(
        Uri.parse(
          '${CommonData.backendUrl}/docs/search?q=${Uri.encodeComponent(query)}',
        ),
      );
      if (response.statusCode == 200) {
        setState(() {
          _searchResults = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _scrollToSection(int sectionId) async {
    final key = _sectionKeys[sectionId];
    if (key != null && key.currentContext != null) {
      final box = key.currentContext!.findRenderObject() as RenderBox?;
      if (box != null && _contentScrollController.hasClients) {
        setState(() {
          _activeSectionId = sectionId;
          _isAutoScrolling = true;
        });

        final position = box.localToGlobal(Offset.zero).dy;
        // Accounting for the 64px vertical padding and sticky header spacing
        // We want to scroll by the distance from the top of the viewport to the element
        final targetScrollOffset =
            _contentScrollController.offset + position - 64;

        await _contentScrollController.animateTo(
          targetScrollOffset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        if (mounted) setState(() => _isAutoScrolling = false);
      }
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'rocket_launch_outlined':
        return Icons.rocket_launch_outlined;
      case 'folder_outlined':
        return Icons.folder_outlined;
      case 'bug_report_outlined':
        return Icons.bug_report_outlined;
      case 'download_outlined':
        return Icons.download_outlined;
      case 'help_outline':
        return Icons.help_outline;
      case 'settings_outlined':
        return Icons.settings_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: GoogleFonts.poppins(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _fetchDocumentation();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final currentTopic = _topics.isNotEmpty
        ? _topics[_selectedTopicIndex]
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. LEFT SIDEBAR: Topics & Search
        _buildSidebar(isDark),

        // 2. MAIN CONTENT AREA
        Expanded(
          child: Container(
            color: isDark ? CommonData.darkBackground : Colors.white,
            child: currentTopic == null
                ? const Center(child: Text('Select a topic to begin'))
                : _buildMainContent(currentTopic, isDark),
          ),
        ),

        // 3. RIGHT SIDEBAR: On This Page (TOC)
        if (currentTopic != null &&
            (currentTopic['sections'] as List).isNotEmpty)
          _buildTOCSidebar(currentTopic, isDark),
      ],
    );
  }

  Widget _buildSidebar(bool isDark) {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111417) : Colors.grey[50],
        border: Border(right: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          // Search Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DOCUMENTATION',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: _handleSearch,
                  style: GoogleFonts.poppins(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: _isSearching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.search, size: 18),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Results or Topic List
          Expanded(
            child: _searchController.text.isNotEmpty
                ? _buildSearchResults(isDark)
                : _buildTopicHierarchy(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final isTopic = result['type'] == 'topic';

        return ListTile(
          dense: true,
          title: Text(
            result['title'],
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: result['snippet'] != null
              ? Text(
                  result['snippet'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                )
              : Text(
                  isTopic ? 'Topic' : result['topic_title'] ?? '',
                  style: const TextStyle(fontSize: 11),
                ),
          onTap: () {
            if (isTopic) {
              final idx = _topics.indexWhere((t) => t['id'] == result['id']);
              if (idx != -1) setState(() => _selectedTopicIndex = idx);
            } else {
              final idx = _topics.indexWhere(
                (t) => t['id'] == result['topic_id'],
              );
              if (idx != -1) {
                setState(() {
                  _selectedTopicIndex = idx;
                  _activeSectionId = result['id'];
                });
                // Wait for render then scroll
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToSection(result['id']),
                );
              }
            }
          },
        );
      },
    );
  }

  Widget _buildTopicHierarchy(bool isDark) {
    final parents = _topics.where((t) => t['parent_id'] == null).toList();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: parents.length,
      itemBuilder: (context, index) {
        final topic = parents[index];
        final subTopics = _topics
            .where((st) => st['parent_id'] == topic['id'])
            .toList();

        return _buildStickyTopicGroup(topic, subTopics, isDark);
      },
    );
  }

  Widget _buildStickyTopicGroup(
    dynamic topic,
    List<dynamic> children,
    bool isDark,
  ) {
    final isSelected = _topics.indexOf(topic) == _selectedTopicIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopicTile(topic, isSelected, isDark, isHeader: true),
        if (children.isNotEmpty)
          ...children.map((child) {
            final isChildSelected =
                _topics.indexOf(child) == _selectedTopicIndex;
            return Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _buildTopicTile(child, isChildSelected, isDark),
            );
          }).toList(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTopicTile(
    dynamic topic,
    bool isSelected,
    bool isDark, {
    bool isHeader = false,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTopicIndex = _topics.indexOf(topic);
          _activeSectionId = null;
        });
        if (_contentScrollController.hasClients) {
          _contentScrollController.jumpTo(0);
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              _getIconData(topic['icon_name'] ?? ''),
              size: 16,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                topic['title'],
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : (isHeader ? FontWeight.w500 : FontWeight.normal),
                  color: isSelected
                      ? (isDark ? Colors.white : Colors.black)
                      : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(dynamic topic, bool isDark) {
    final sections = topic['sections'] as List;

    // Calculate visual linear order for Prev/Next navigation
    final List<dynamic> visualTopics = [];
    final parents = _topics.where((t) => t['parent_id'] == null).toList();
    for (var p in parents) {
      visualTopics.add(p);
      visualTopics.addAll(_topics.where((t) => t['parent_id'] == p['id']));
    }

    final currentIndex = visualTopics.indexOf(topic);
    final prevTopic = currentIndex > 0 ? visualTopics[currentIndex - 1] : null;
    final nextTopic =
        currentIndex >= 0 && currentIndex < visualTopics.length - 1
        ? visualTopics[currentIndex + 1]
        : null;

    return SingleChildScrollView(
      controller: _contentScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 64),
      child: Container(
        alignment: Alignment.topCenter,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Topic Header
              Text(
                topic['title'],
                style: GoogleFonts.poppins(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : XRDockTheme.deepNavy,
                ),
              ),
              const SizedBox(height: 48),

              // Sections
              ...sections.map((s) {
                final key = _sectionKeys.putIfAbsent(
                  s['id'],
                  () => GlobalKey(),
                );
                return Padding(
                  key: key,
                  padding: const EdgeInsets.only(bottom: 32),
                  child: _buildSectionItem(s, isDark),
                );
              }).toList(),

              const SizedBox(height: 64),
              // Prev / Next Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  prevTopic != null
                      ? InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTopicIndex = _topics.indexOf(prevTopic);
                              _activeSectionId = null;
                            });
                            if (_contentScrollController.hasClients) {
                              _contentScrollController.jumpTo(0);
                            }
                          },
                          child: Row(
                            children: [
                              Icon(
                                Icons.chevron_left,
                                color: isDark ? Colors.white70 : Colors.black87,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                prevTopic['title'],
                                style: GoogleFonts.poppins(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(),
                  nextTopic != null
                      ? InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTopicIndex = _topics.indexOf(nextTopic);
                              _activeSectionId = null;
                            });
                            if (_contentScrollController.hasClients) {
                              _contentScrollController.jumpTo(0);
                            }
                          },
                          child: Row(
                            children: [
                              Text(
                                nextTopic['title'],
                                style: GoogleFonts.poppins(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black87,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                color: isDark ? Colors.white70 : Colors.black87,
                                size: 20,
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(),
                ],
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionItem(dynamic s, bool isDark) {
    switch (s['type']) {
      case 'heading':
        return Text(
          s['title'] ?? '',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        );
      case 'text':
        return MarkdownBody(
          data: s['content_text'] ?? '',
          styleSheet: MarkdownStyleSheet(
            textAlign: WrapAlignment.start,
            h1: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            h1Align: WrapAlignment.start,
            h2: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
            h2Align: WrapAlignment.start,
            h3: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            h3Align: WrapAlignment.start,
            p: GoogleFonts.inter(
              fontSize: 15,
              height: 1.7,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            strong: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
            em: GoogleFonts.inter(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            blockquote: GoogleFonts.inter(
              fontSize: 15,
              color: isDark ? Colors.white54 : Colors.black54,
              fontStyle: FontStyle.italic,
            ),
            code: GoogleFonts.robotoMono(
              fontSize: 13,
              backgroundColor: isDark
                  ? Colors.white10
                  : Colors.black.withOpacity(0.05),
            ),
            codeblockDecoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      case 'video_gallery':
        return _VideoGalleryWidget(mediaListJson: s['media_list']);
      case 'image_gallery':
        return _ImageGalleryWidget(mediaListJson: s['media_list']);
      case 'video':
        return UnifiedVideoPlayer(url: s['media_url'], title: s['title']);
      case 'image':
        return _buildMediaPreview(s['media_url'], false, s['title']);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMediaPreview(String? url, bool isVideo, String? title) {
    if (url == null) return const SizedBox.shrink();

    String fullUrl = url;
    if (!url.startsWith('http')) {
      fullUrl = '${CommonData.backendUrl}$url';
    }

    if (isVideo) {
      return UnifiedVideoPlayer(url: fullUrl, title: title, height: 400);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.network(fullUrl, fit: BoxFit.contain),
          ),
        ),
      ],
    );
  }

  Widget _buildTOCSidebar(dynamic topic, bool isDark) {
    final sections = (topic['sections'] as List)
        .where((s) => s['title'] != null && s['title'] != '')
        .toList();

    return Container(
      width: 240,
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ON THIS PAGE',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 20),
          ...sections.map((s) => _buildTOCItem(s, isDark)).toList(),
        ],
      ),
    );
  }

  Widget _buildTOCItem(dynamic section, bool isDark) {
    final isActive = _activeSectionId == section['id'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _scrollToSection(section['id']),
        child: Text(
          section['title'],
          style: GoogleFonts.poppins(
            fontSize: isActive ? 13 : 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? XRDockTheme.primaryPurple : Colors.grey[600],
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _VideoGalleryWidget extends StatefulWidget {
  final String? mediaListJson;
  const _VideoGalleryWidget({this.mediaListJson});

  @override
  State<_VideoGalleryWidget> createState() => _VideoGalleryWidgetState();
}

class _VideoGalleryWidgetState extends State<_VideoGalleryWidget> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.mediaListJson == null) return const SizedBox.shrink();

    List<dynamic> items = [];
    try {
      final decoded = json.decode(widget.mediaListJson!);
      if (decoded is List) {
        items = decoded;
      }
    } catch (e) {
      debugPrint('JSON parse error in gallery: $e');
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Error displaying gallery: Invalid media list format.',
          style: GoogleFonts.poppins(color: Colors.red, fontSize: 12),
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    final current = items[_selectedIndex];

    return Container(
      height: 450,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          // Main Player Area
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: UnifiedVideoPlayer(
                    key: ValueKey(current['url']),
                    url: current['url'],
                    // Standardizes height handling; height is handled by Expanded
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    current['title'] ?? 'Untitled Video',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // YouTube style Sidebar
          Container(
            width: 200,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.grey.withOpacity(0.1)),
              ),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == _selectedIndex;
                return InkWell(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    color: isSelected
                        ? Theme.of(context).primaryColor.withOpacity(0.05)
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(
                                item['thumbnail']?.isNotEmpty == true
                                    ? (item['thumbnail'].startsWith('http')
                                          ? item['thumbnail']
                                          : '${CommonData.backendUrl}${item['thumbnail']}')
                                    : _getYouTubeThumbnail(item['url']),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['title'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageGalleryWidget extends StatelessWidget {
  final String? mediaListJson;
  const _ImageGalleryWidget({this.mediaListJson});

  @override
  Widget build(BuildContext context) {
    if (mediaListJson == null) return const SizedBox.shrink();
    List<dynamic> items = [];
    try {
      final decoded = json.decode(mediaListJson!);
      if (decoded is List) {
        items = decoded;
      }
    } catch (e) {
      return const SizedBox.shrink();
    }
    if (items.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isDataUri = item['url'].toString().startsWith('data:');
        final isHttp = item['url'].toString().startsWith('http');
        final fullUrl = isDataUri || isHttp
            ? item['url']
            : '${CommonData.backendUrl}${item['url']}';

        // Provide memory or network image based on Data URI.
        final ImageProvider imageProvider = isDataUri
            ? MemoryImage(base64Decode(item['url'].toString().split(',').last))
            : NetworkImage(fullUrl) as ImageProvider;

        return InkWell(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) =>
                  _ImageGalleryViewer(items: items, initialIndex: index),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
              alignment: Alignment.bottomLeft,
              padding: const EdgeInsets.all(8),
              child: Text(
                item['title'] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ImageGalleryViewer extends StatefulWidget {
  final List<dynamic> items;
  final int initialIndex;

  const _ImageGalleryViewer({required this.items, required this.initialIndex});

  @override
  State<_ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<_ImageGalleryViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ImageProvider _getImageProvider(dynamic item) {
    final isDataUri = item['url'].toString().startsWith('data:');
    final isHttp = item['url'].toString().startsWith('http');
    final fullUrl = isDataUri || isHttp
        ? item['url']
        : '${CommonData.backendUrl}${item['url']}';

    if (isDataUri) {
      return MemoryImage(base64Decode(item['url'].toString().split(',').last));
    }
    return NetworkImage(fullUrl);
  }

  void _nextPage() {
    if (_currentIndex < widget.items.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      surfaceTintColor: Colors
          .transparent, // Prevents white tint overlay on transparent background
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
            child: PageView.builder(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image(
                    image: _getImageProvider(widget.items[index]),
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
          ),

          // Left Arrow
          if (_currentIndex > 0)
            Positioned(
              left: 0,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 24,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: _prevPage,
              ),
            ),

          // Right Arrow
          if (_currentIndex < widget.items.length - 1)
            Positioned(
              right: 0,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white,
                  size: 24,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  padding: const EdgeInsets.all(12),
                ),
                onPressed: _nextPage,
              ),
            ),

          // Close Button (Fixed positioning outside of image boundary but inside dialog Stack)
          Positioned(
            top: -16,
            right: -16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
              style: IconButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.all(8),
              ),
              tooltip: 'Close',
            ),
          ),

          // Image Counter (Bottom Center)
          Positioned(
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentIndex + 1} / ${widget.items.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UnifiedVideoPlayer extends StatefulWidget {
  final String? url;
  final String? title;
  final double height; // Made non-nullable with default

  const UnifiedVideoPlayer({
    super.key,
    this.url,
    this.title,
    this.height = 400,
  });

  @override
  State<UnifiedVideoPlayer> createState() => _UnifiedVideoPlayerState();
}

class _UnifiedVideoPlayerState extends State<UnifiedVideoPlayer> {
  YoutubePlayerController? _ytController;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isYouTube = false;

  Widget _buildPlayerContent() {
    return _isYouTube
        ? (_ytController != null
              ? YoutubePlayer(controller: _ytController!)
              : const Center(
                  child: Text(
                    'Invalid YouTube URL',
                    style: TextStyle(color: Colors.white),
                  ),
                ))
        : (_chewieController != null
              ? Chewie(controller: _chewieController!)
              : const Center(child: CircularProgressIndicator()));
  }

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(UnifiedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeControllers();
      _initPlayer();
    }
  }

  void _initPlayer() {
    if (widget.url == null || widget.url!.isEmpty) return;

    final url = widget.url!;
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      _isYouTube = true;
      final videoId = _extractYouTubeId(url);
      if (videoId != null) {
        _ytController = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          autoPlay: false,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
            mute: false,
          ),
        );
      }
    } else {
      _isYouTube = false;
      // Hosted video
      String fullUrl = url;
      if (!url.startsWith('http')) {
        fullUrl = '${CommonData.backendUrl}$url';
      }

      _videoController = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
      _videoController!
          .initialize()
          .then((_) {
            if (mounted) {
              setState(() {
                _chewieController = ChewieController(
                  videoPlayerController: _videoController!,
                  autoPlay: false,
                  looping: false,
                  aspectRatio: 16 / 9,
                  errorBuilder: (context, errorMessage) {
                    return Center(
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                );
              });
            }
          })
          .catchError((e) {
            debugPrint('Video player Init error: $e');
          });
    }
  }

  void _disposeControllers() {
    _ytController?.close();
    _ytController = null;
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url == null || widget.url!.isEmpty)
      return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.title!,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildPlayerContent(),
        ),
      ],
    );
  }
}
