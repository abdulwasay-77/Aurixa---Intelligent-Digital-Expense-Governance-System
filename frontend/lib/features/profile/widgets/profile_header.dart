/// Profile Header Widget — Avatar circle, name, email, member-since badge
///
/// Shape classification (per hover_widgets.dart's size-aware rule): this
/// card spans the full content width and packs an avatar + multi-line
/// text block + a Wrap of 3 badges into one row — that's a *wide,
/// multi-element* shape, not a compact isolated tile. Per Lesson 2
/// ("looks compact ≠ is compact") it gets HoverSize.subtle (1.045x), the
/// same gentler tier used for SubVault's subscription cards and the
/// Recommendations stat tiles — a bigger card like this zooming at the
/// punchier 1.08x `large` tier would push past its own row and read as
/// overshadowing the Financial Settings card sitting right below it.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hover_widgets.dart';
import '../../../providers/profile_provider.dart';

class ProfileHeader extends StatelessWidget {
  final UserInfo user;
  final UserProfile profile;

  const ProfileHeader({
    super.key,
    required this.user,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      glowColor: AppTheme.profileAccent,
      size: HoverSize.subtle,
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Avatar
          _buildAvatar(),
          const SizedBox(width: 20),

          // User Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (user.phone != null && user.phone!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.phone,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        user.phone!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                // Member since + status badges
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildBadge(
                      icon: Icons.calendar_today,
                      label: 'Member since ${_formatDate(user.createdAt)}',
                      color: AppTheme.profileAccent,
                    ),
                    _buildBadge(
                      icon: Icons.verified_user,
                      label: user.status,
                      color: user.status == 'ACTIVE'
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                    _buildBadge(
                      icon: Icons.account_balance_wallet,
                      label: profile.baseCurrencyCode,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final initials = _getInitials(user.fullName);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.profileAccent,
            AppTheme.profileAccent.withValues(alpha: 0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.profileAccent.withValues(alpha: 0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}