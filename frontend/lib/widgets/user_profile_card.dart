import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../common/common.dart';
import '../theme/xrdock_theme.dart';

class UserProfileCard extends StatelessWidget {
  final bool isCollapsed;
  const UserProfileCard({super.key, this.isCollapsed = false});

  @override
  Widget build(BuildContext context) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final dbUser = CommonData.dbUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final String name = dbUser?.name ?? firebaseUser?.displayName ?? 'Operator';
    final String email =
        dbUser?.email ?? firebaseUser?.email ?? 'Unknown Identity';
    final String initials =
        (name.isNotEmpty ? name[0] : (email.isNotEmpty ? email[0] : '?'))
            .toUpperCase();

    // Collapsed: plain centered avatar
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: CircleAvatar(
            radius: 20,
            backgroundColor: XRDockTheme.primaryPurple.withOpacity(0.1),
            child: Text(
              initials,
              style: GoogleFonts.poppins(
                color: XRDockTheme.primaryPurple,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    // Expanded: full card with branding
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: XRDockTheme.primaryPurple.withOpacity(0.15),
            child: Text(
              initials,
              style: GoogleFonts.poppins(
                color: XRDockTheme.primaryPurple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : XRDockTheme.deepNavy,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: GoogleFonts.poppins(color: Colors.grey, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
