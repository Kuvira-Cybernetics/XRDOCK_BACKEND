import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../common/common.dart';

class FloatingIssueOverlay extends StatefulWidget {
  final int projectId;

  const FloatingIssueOverlay({super.key, required this.projectId});

  @override
  State<FloatingIssueOverlay> createState() => _FloatingIssueOverlayState();
}

class _FloatingIssueOverlayState extends State<FloatingIssueOverlay> {
  List<dynamic> _issues = [];
  bool _isLoading = true;
  int? _selectedIssueId;

  @override
  void initState() {
    super.initState();
    _fetchIssues();
  }

  @override
  void didUpdateWidget(covariant FloatingIssueOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      _fetchIssues();
    }
  }

  Future<void> _fetchIssues({bool isRetry = false}) async {
    if (!isRetry) setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken(isRetry);

      final response = await http.get(
        Uri.parse('${CommonData.backendUrl}/issues/${widget.projectId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _issues = json.decode(response.body);
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401 && !isRetry) {
        await _fetchIssues(isRetry: true);
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: CommonData.primaryNeon),
      );
    }

    // Placing pins over the 3D viewer space
    return Stack(
      children: _issues.map((issue) {
        final isSelected = _selectedIssueId == issue['id'];
        return Positioned(
          left: issue['x_coord'],
          top: issue['y_coord'],
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedIssueId = issue['id'];
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 48 : 32,
              height: isSelected ? 48 : 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? CommonData.primaryNeon
                    : CommonData.panelBackground,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.white : CommonData.primaryNeon,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: CommonData.primaryNeon.withOpacity(0.8),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ]
                    : [],
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: isSelected ? Colors.black : CommonData.primaryNeon,
                size: isSelected ? 24 : 16,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
