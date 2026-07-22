/// Profile Screen — Phase 9 — Full Nebula Enhancement
///
/// Starts from a scaffolded-but-unstyled baseline (own Scaffold + AppBar,
/// plain Card widgets, AppTheme.bgCanvas / AppTheme.primary legacy
/// references). This file is a complete ground-up replacement:
///
///   - Token remap: bgCanvas → bgBase, primary → profileAccent
///     (brandIndigo) throughout the whole feature.
///   - Scaffold + AppBar removed — AppShell owns chrome; this file is
///     content only, matching every other migrated screen since Phase 7.
///   - Gradient hero header matching the established vocabulary
///     (profileAccent/brandIndigo → brandPurple — a fresh combo, since
///     Profile wasn't one of the original 8 module accents).
///   - HoverEntrance cascade on every major section.
///   - Plain Cards converted to HoverCard, classified by actual layout
///     shape per Lesson 2/Lesson 3 (see hover_widgets.dart doc + the
///     per-widget comments in profile_header.dart / preferences_form.dart
///     / change_password_dialog.dart):
///       • ProfileHeader  → wide, multi-element card → HoverSize.subtle
///         (gentle zoom — full content width, so a bold zoom would push
///         past its row and read as overshadowing the card below it).
///       • Financial Settings / Notification Preferences sections → tall,
///         field-dense forms → scaleEnabled: false (glow only, no zoom —
///         a big zoom on a tall stacked form pushes past the scroll
///         column's visual rhythm and overlaps the next card).
///       • Account Actions card → scaleEnabled: false on the outer card
///         (it's a tall list-style container); each row inside gets its
///         own small HoverListItem instead, so the *row* hovers, not the
///         whole card.
///   - Lesson 10 proactive: every HoverEntrance call site here wraps a
///     widget, never `HoverEntrance(child: Expanded(...))` directly.
///   - Lesson 11 proactive: _isRefreshing is a local bool on State, not
///     derived from asyncState.value?.anything.
///   - Refresh button uses a RotationTransition spin controller owned by
///     this screen (safe — this widget is not a ListView ancestor).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/hover_widgets.dart';
import '../../providers/profile_provider.dart';
import 'widgets/profile_header.dart';
import 'widgets/preferences_form.dart';
import 'widgets/change_password_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  // Lesson 11 — local bool, never derived from asyncState.value?.isLoading.
  bool _isRefreshing = false;

  // Spin controller for the refresh icon in the hero header. Safe here:
  // this screen widget is NOT a ListView child (Lesson 7).
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    // Lesson 11 — set the local flag BEFORE the await; don't rely on the
    // provider's transient AsyncLoading state for this.
    setState(() => _isRefreshing = true);
    _spinController.repeat();
    await ref.read(profileProvider.notifier).refresh();
    if (mounted) {
      _spinController.stop();
      _spinController.reset();
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(profileProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Gradient hero header (matches Phase 3–8 vocabulary) ────────
        _buildHeroHeader(),

        // ── Body ───────────────────────────────────────────────────────
        Expanded(
          child: asyncState.when(
            loading: _buildLoading,
            error: (error, _) => _buildErrorState(error),
            data: (state) {
              if (!state.hasData) {
                return _buildErrorState('Profile data unavailable');
              }
              return _buildContent(state);
            },
          ),
        ),
      ],
    );
  }

  // ── Hero header ────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Container(
      // Lesson 8 — explicit width: double.infinity so the inner Row's
      // Expanded child has a concrete parent width constraint.
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 22, 22, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // profileAccent (brandIndigo) → brandPurple — a fresh combo
          // distinct from every other module's hero gradient, since
          // Profile isn't one of the original 8 module accents.
          colors: [AppTheme.profileAccent, AppTheme.brandPurple],
        ),
      ),
      child: Row(
        children: [
          // Module icon badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),

          // Title + sub-label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile & Settings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Account details · financial settings · notifications',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Glass refresh button with spinning icon
          _buildRefreshButton(),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return GestureDetector(
      onTap: _isRefreshing ? null : _refresh,
      child: MouseRegion(
        cursor:
            _isRefreshing ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: AppTheme.hoverDuration,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.radiusButtons),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RotationTransition(
                turns: _spinController,
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Refresh',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── States ─────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.profileAccent),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppTheme.danger,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 140,
              child: HoverButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: _refresh,
                expand: false,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main content ───────────────────────────────────────────────────────

  Widget _buildContent(ProfileState state) {
    final notifier = ref.read(profileProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 0 — Profile header (avatar, name, badges). Wide full-width
          // card → HoverSize.subtle is set *inside* ProfileHeader itself
          // (see that file's class doc), not here.
          HoverEntrance(
            index: 0,
            child: ProfileHeader(
              user: state.user!,
              profile: state.profile!,
            ),
          ),
          const SizedBox(height: 16),

          // 1 — Financial Settings + Notification Preferences. Both
          // sections are tall/dense forms → scaleEnabled: false, set
          // inside PreferencesForm itself.
          HoverEntrance(
            index: 1,
            child: PreferencesForm(
              profile: state.profile!,
              preferences: state.preferences!,
              onUpdateProfile: notifier.updateProfile,
              onUpdatePreferences: notifier.updatePreferences,
            ),
          ),
          const SizedBox(height: 16),

          // 2 — Account Actions card
          HoverEntrance(
            index: 2,
            child: _AccountActionsCard(
              onChangePassword: () => _openChangePassword(notifier),
              onLogout: () => _confirmLogout(notifier),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _openChangePassword(ProfileNotifier notifier) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangePasswordDialog(
        onChangePassword: notifier.changePassword,
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmLogout(ProfileNotifier notifier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to log out from AURIXA?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await notifier.logout();
      if (mounted) context.go('/login');
    }
  }
}

// ============================================================================
// _AccountActionsCard
//
// Shape classification: tall, list-style card (3 stacked rows) → outer
// card is scaleEnabled: false (Lesson 2 — dense vertical stack, a whole-
// card zoom here would overshadow the card above/below it in the scroll
// column). Each row inside is individually hoverable via HoverListItem
// instead, so the interactive feedback lives on the row, not the card.
// ============================================================================
class _AccountActionsCard extends StatelessWidget {
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;

  const _AccountActionsCard({
    required this.onChangePassword,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      glowColor: AppTheme.profileAccent,
      scaleEnabled: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.manage_accounts_outlined,
                  size: 18, color: AppTheme.profileAccent),
              SizedBox(width: 8),
              Text(
                'Account Actions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(color: AppTheme.borderColor),
          const SizedBox(height: 4),

          // Change Password
          _ActionRow(
            icon: Icons.lock_outline,
            iconColor: AppTheme.warning,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: onChangePassword,
          ),

          // Account info (not interactive — no glow color won't matter
          // since onTap is null and HoverListItem skips the zoom/glow
          // states entirely when there's nothing to click).
          _ActionRow(
            icon: Icons.info_outline,
            iconColor: AppTheme.profileAccent,
            title: 'Account Status',
            subtitle: 'ACTIVE — Subscription expense governance platform',
            onTap: null,
          ),

          // Logout
          _ActionRow(
            icon: Icons.logout,
            iconColor: AppTheme.danger,
            title: 'Log Out',
            subtitle: 'Sign out from this device',
            titleColor: AppTheme.danger,
            glowColor: AppTheme.danger,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final Color? glowColor;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.titleColor,
    this.glowColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: titleColor ?? AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (onTap != null)
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AppTheme.textSecondary,
          ),
      ],
    );

    // Non-interactive rows (onTap == null, e.g. "Account Status") render
    // as a plain padded row instead of HoverListItem — HoverGlow reacts
    // to MouseRegion.onEnter regardless of onTap, so wrapping a row that
    // can't actually be tapped would still zoom/glow on hover, reading
    // as clickable when it isn't. Only genuinely actionable rows hover.
    if (onTap == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: row,
      );
    }

    return HoverListItem(
      glowColor: glowColor ?? AppTheme.profileAccent,
      onTap: onTap,
      borderRadius: 10,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      // Rows are wide and sit one above another — same density reasoning
      // as a sidebar/list row, so HoverSize.subtle reads better than the
      // punchier default HoverSize.small here.
      size: HoverSize.subtle,
      child: row,
    );
  }
}