/// App Shell — Persistent layout that wraps all authenticated screens.
/// The sidebar lives here once. Only the right-hand content area changes
/// when navigating between routes via ShellRoute in main.dart.
///
/// Phase 2 addition — Fullscreen behavior:
///   - On first build after login/register, the whole app window enters
///     TRUE fullscreen (windowManager.setFullScreen(true)), not just a
///     resized chrome window. This only fires ONCE per app session (guard
///     flag in initState), since ShellRoute rebuilds AppShell on every
///     authenticated navigation and we don't want to re-trigger fullscreen
///     every time the user clicks a sidebar item.
///   - A small control sits pinned to the top-right corner of the ENTIRE
///     window (above sidebar + content, via a Stack at the AppShell level
///     per spec) that toggles fullscreen on/off. It is invisible at
///     opacity 0 by default and fades in only when the pointer is near
///     the top-right corner — "hidden unless hovered, otherwise stays
///     hidden." Clicking it exits to a normal resizable window; the same
///     control flips to a "re-enter fullscreen" icon afterward, so the
///     toggle is reversible at any time, not a one-way door.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../core/theme/app_theme.dart';
import '../sidebar/sidebar_widget.dart';
import '../../main.dart' show enterAppFullscreen;

class AppShell extends ConsumerStatefulWidget {
  /// The currently active inner screen, injected by GoRouter's ShellRoute.
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WindowListener {
  // Guards against re-entering fullscreen on every ShellRoute rebuild
  // (e.g. clicking between Dashboard / SubVault / BehaviorLens etc. all
  // rebuild AppShell's parent route but should NOT keep forcing fullscreen
  // back on if the user has explicitly exited it).
  static bool _hasEnteredFullscreenThisSession = false;

  bool _isFullScreen = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    if (!_hasEnteredFullscreenThisSession) {
      _hasEnteredFullscreenThisSession = true;
      // Defer past the current frame — calling window_manager during the
      // very first build of the authenticated shell (immediately after a
      // GoRouter redirect from /login) is safer scheduled as a post-frame
      // callback than awaited synchronously inside initState.
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await enterAppFullscreen();
        if (mounted) setState(() => _isFullScreen = true);
      });
    } else {
      // Re-sync local state in case the user toggled fullscreen off,
      // then navigated (AppShell rebuilds but isn't a fresh session).
      windowManager.isFullScreen().then((value) {
        if (mounted) setState(() => _isFullScreen = value);
      });
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  // WindowListener — keep local state in sync if fullscreen changes from
  // somewhere outside this widget's own toggle (e.g. OS-level F11, or the
  // user dragging the window in a way the platform interprets as an exit).
  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _isFullScreen = false);
  }

  Future<void> _toggleFullScreen() async {
    final next = !_isFullScreen;
    if (next) {
      await enterAppFullscreen();
    } else {
      await windowManager.setFullScreen(false);
      // Land in a comfortably-sized, centered, fully resizable window —
      // per spec, exiting fullscreen does not relock the window, and the
      // toggle remains available to re-enter fullscreen at any time.
      await windowManager.setSize(
        const Size(AppTheme.minWindowWidth, AppTheme.minWindowHeight),
      );
      await windowManager.center();
    }
    if (mounted) setState(() => _isFullScreen = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar — rendered ONCE, never rebuilt on route changes
              const SidebarWidget(),

              // Content area — only this swaps when navigating
              Expanded(
                child: Container(
                  color: AppTheme.bgCanvas,
                  child: widget.child,
                ),
              ),
            ],
          ),

          // Hidden hover-reveal fullscreen toggle — pinned top-right of
          // the WHOLE window (sits above sidebar + content), visible on
          // every authenticated screen.
          Positioned(
            top: 0,
            right: 0,
            child: _FullscreenToggleCorner(
              isFullScreen: _isFullScreen,
              onToggle: _toggleFullScreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// A generously-sized invisible hit zone in the top-right corner. The
/// actual button only fades into view once the pointer enters that zone;
/// otherwise it stays fully hidden so it never competes visually with
/// dashboard content. The hit zone itself is larger than the visible
/// button so it's easy to find without hunting pixel-by-pixel.
class _FullscreenToggleCorner extends StatefulWidget {
  const _FullscreenToggleCorner({
    required this.isFullScreen,
    required this.onToggle,
  });

  final bool isFullScreen;
  final VoidCallback onToggle;

  @override
  State<_FullscreenToggleCorner> createState() =>
      _FullscreenToggleCornerState();
}

class _FullscreenToggleCornerState extends State<_FullscreenToggleCorner> {
  bool _zoneHovering = false;
  bool _buttonHovering = false;

  @override
  Widget build(BuildContext context) {
    final revealed = _zoneHovering || _buttonHovering;

    return MouseRegion(
      onEnter: (_) => setState(() => _zoneHovering = true),
      onExit: (_) => setState(() => _zoneHovering = false),
      child: SizedBox(
        width: 96,
        height: 72,
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 14, right: 16),
            child: AnimatedOpacity(
              opacity: revealed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              // IgnorePointer while hidden so the invisible button can't
              // steal clicks/cursor focus from whatever is underneath it
              // (e.g. dashboard content scrolled up under the corner).
              child: IgnorePointer(
                ignoring: !revealed,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _buttonHovering = true),
                  onExit: (_) => setState(() => _buttonHovering = false),
                  cursor: SystemMouseCursors.click,
                  child: Tooltip(
                    message: widget.isFullScreen
                        ? 'Exit full screen'
                        : 'Enter full screen',
                    decoration: BoxDecoration(
                      color: AppTheme.textPrimary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    child: GestureDetector(
                      onTap: widget.onToggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOut,
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.textPrimary.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.textPrimary.withValues(
                                alpha: 0.25,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.isFullScreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
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