import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileCard extends StatelessWidget {
  final bool isCollapsed;
  const UserProfileCard({super.key, this.isCollapsed = false});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(isCollapsed ? 4 : 16),
      margin: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 4 : 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isCollapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isCollapsed ? 18 : 20,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
            child: Text(
              (user?.displayName ?? user?.email ?? '?')
                  .substring(0, 1)
                  .toUpperCase(),
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user?.displayName ?? 'Operator',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    user?.email ?? 'Unknown Identity',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontSize: 10,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
