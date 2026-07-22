/// Persistent Left Sidebar Navigation
/// PERF FIX 1: withOpacity() replaced with withValues(alpha:)
/// PERF FIX 2: ref.select() so sidebar only rebuilds on collapse toggle,
///             NOT on every route change
/// PERF FIX 3: const on all static children
///
/// Fix pass: nav rows previously used the generic HoverGlow (scale-based)
/// treatment, the same one used for dashboard cards. On a 240px-wide,
/// ~46px-tall row, a 1.10x zoom grows the row ~24px wider than the
/// sidebar itself and overlaps the rows packed directly above/below it
/// (rows only have 3px vertical margin) — that's what looked broken.
/// Swapped to HoverNavItem (core/widgets/hover_widgets.dart), which is
/// purpose-built for nav lists: background tint + a left accent bar that
/// slides in + icon/label color shift + a tight non-overflowing glow, no
/// scale transform at all. This is also the same vocabulary real desktop
/// apps use for sidebars (VS Code, Slack, etc.) — rows never zoom.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/hover_widgets.dart';
import '../../providers/sidebar_provider.dart';
import '../../providers/auth_provider.dart';

class SidebarWidget extends ConsumerWidget {
  const SidebarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PERF FIX: select() — rebuilds ONLY when isCollapsed value changes.
    // Old code: ref.watch(sidebarProvider) rebuilt on every navigation
    // because GoRouterState.of(context) changed on every route push.
    final isCollapsed = ref.watch(
      sidebarProvider.select((collapsed) => collapsed),
    );

    final currentLocation = GoRouterState.of(context).uri.path;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: isCollapsed
          ? AppTheme.sidebarCollapsedWidth
          : AppTheme.sidebarExpandedWidth,
      decoration: BoxDecoration(
        color: AppTheme.sidebarBackground,
        border: Border(
          right: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context, ref, isCollapsed),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildNavItem(context: context, ref: ref, icon: Icons.dashboard, label: 'Dashboard', route: AppConstants.routeDashboard, currentLocation: currentLocation, isCollapsed: isCollapsed),
                _buildNavItem(context: context, ref: ref, icon: Icons.subscriptions, label: 'SubVault', route: AppConstants.routeSubscriptions, currentLocation: currentLocation, isCollapsed: isCollapsed),
                _buildNavItem(context: context, ref: ref, icon: Icons.analytics, label: 'BehaviorLens', route: AppConstants.routeAnalytics, currentLocation: currentLocation, isCollapsed: isCollapsed),
                _buildNavItem(context: context, ref: ref, icon: Icons.speed, label: 'VelocityEngine', route: AppConstants.routeForecast, currentLocation: currentLocation, isCollapsed: isCollapsed),
                _buildNavItem(context: context, ref: ref, icon: Icons.notifications_active, label: 'RiskRadar', route: AppConstants.routeAlerts, currentLocation: currentLocation, isCollapsed: isCollapsed),
                _buildNavItem(context: context, ref: ref, icon: Icons.lightbulb, label: 'Recommendations', route: AppConstants.routeRecommendations, currentLocation: currentLocation, isCollapsed: isCollapsed),
                _buildNavItem(context: context, ref: ref, icon: Icons.timeline, label: 'Score History', route: AppConstants.routeScoreHistory, currentLocation: currentLocation, isCollapsed: isCollapsed),
                _buildNavItem(context: context, ref: ref, icon: Icons.person, label: 'Profile', route: AppConstants.routeProfile, currentLocation: currentLocation, isCollapsed: isCollapsed),
                _buildNavItem(context: context, ref: ref, icon: Icons.account_balance_wallet, label: 'Wallet', route: AppConstants.routeWallet, currentLocation: currentLocation, isCollapsed: isCollapsed),
                _buildNavItem(context: context, ref: ref, icon: Icons.history, label: 'Audit Trail', route: AppConstants.routeAudit, currentLocation: currentLocation, isCollapsed: isCollapsed),
              ],
            ),
          ),
          Divider(color: AppTheme.borderColor, height: 1, thickness: 1),
          _buildNavItem(context: context, ref: ref, icon: Icons.logout, label: 'Logout', route: null, currentLocation: currentLocation, isCollapsed: isCollapsed, isLogout: true),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, bool isCollapsed) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 16),
      child: Row(
        mainAxisAlignment: isCollapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.spaceBetween,
        children: [
          if (!isCollapsed)
            const Expanded(
              child: Text(
                'AURIXA',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryLight,
                  letterSpacing: 1.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Collapse toggle stays a HoverIconBadge — it's a small,
          // isolated square icon with breathing room on every side, so
          // the punchy zoom looks fine here (unlike packed nav rows).
          HoverIconBadge(
            icon: isCollapsed ? Icons.menu_open : Icons.menu,
            glowColor: AppTheme.brandIndigo,
            size: 36,
            onTap: () => ref.read(sidebarProvider.notifier).toggle(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String label,
    required String? route,
    required String currentLocation,
    required bool isCollapsed,
    bool isLogout = false,
  }) {
    final isSelected = route != null && currentLocation == route;
    final accentColor = isLogout ? AppTheme.danger : AppTheme.brandIndigo;
    final iconColor = isLogout
        ? AppTheme.danger
        : (isSelected ? AppTheme.primaryLight : AppTheme.textSecondary);

    Widget item = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 6.0 : 10.0,
        vertical: 3,
      ),
      child: HoverNavItem(
        glowColor: accentColor,
        isSelected: isSelected,
        borderRadius: AppTheme.radiusButtons,
        showAccentBar: !isCollapsed,
        onTap: () {
          if (isLogout) {
            _showLogoutDialog(context, ref);
          } else if (route != null) {
            context.go(route);
          }
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0.0 : 12.0,
            vertical: 11,
          ),
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 22),
              if (!isCollapsed) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: iconColor,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (isCollapsed) {
      item = Tooltip(
        message: label,
        preferBelow: false,
        verticalOffset: 0,
        decoration: BoxDecoration(
          color: AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.borderColor),
        ),
        textStyle: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        child: item,
      );
    }

    return item;
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go(AppConstants.routeLogin);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}