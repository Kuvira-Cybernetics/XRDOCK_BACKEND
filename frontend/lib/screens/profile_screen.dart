import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../common/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? CommonData.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'USER PROFILE',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.2),
                        child: Text(
                          (user?.displayName ?? user?.email ?? '?')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 32,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        user?.displayName ?? 'OPERATOR',
                        style: Theme.of(
                          context,
                        ).textTheme.displaySmall?.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user?.email ?? 'N/A',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 40),
                      _ProfileInfoTile(
                        label: 'FIREBASE UID',
                        value: user?.uid ?? 'N/A',
                        icon: Icons.fingerprint,
                      ),
                      const SizedBox(height: 16),
                      _ProfileInfoTile(
                        label: 'SYSTEM LEVEL',
                        value: 'ADMINISTRATOR',
                        icon: Icons.verified_user_outlined,
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              Navigator.pushReplacementNamed(context, '/'),
                          icon: const Icon(Icons.logout),
                          label: const Text('DISCONNECT FROM HUB'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.1),
                            foregroundColor: Colors.redAccent,
                            elevation: 0,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
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
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileInfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.2)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  value,
                  style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
