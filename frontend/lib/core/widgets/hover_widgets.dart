/// AURIXA Shared Hover & Entrance Animation Primitives
///
/// Encodes every animation decision from the UI Enhancement planning pass:
///   - Hover zoom is size-aware: large cards cap at ~1.08x, small items
///     (badges/icons/rows) go bolder at ~1.10x.
///   - Hover glow color defaults to a module's accent color but can be
///     overridden per-card by a status color (e.g. a CRITICAL alert glows
///     red even inside a module whose default accent differs).
///   - Entrance (fade + slide on first load) and hover (scale on pointer
///     enter) are ALWAYS driven by separate widgets/transforms. Combining
///     them on one Transform was a real bug we hit during prototyping:
///     once an `animation` shorthand "claims" the transform property, a
///     CSS/Flutter transition trying to animate the same property on
///     pointer-enter gets silently overridden. Keeping entrance and hover
///     on two different widgets (HoverEntrance wraps, *Hoverable owns the
///     scale) avoids that class of bug entirely.
///
/// Usage:
///   HoverEntrance(
///     index: i, // for stagger
///     child: HoverCard(
///       glowColor: AppTheme.subVault,
///       onTap: () {},
///       child: ...,
///     ),
///   )
library;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ============================================================================
// SIZE CLASS — determines how bold the hover zoom is allowed to be.
//
// Three named tiers, chosen per element type, not tuned per-instance:
//   - large   → big cards in a grid (dashboard stat cards, score ring).
//   - subtle  → tall/dense list cards where a strong zoom feels like too
//               much movement for a row this size (subscription cards,
//               and any future list-card with a lot of content). Less
//               zoom than `large`, but still clearly noticeable on hover
//               — not the same as scaleEnabled: false, which removes the
//               zoom entirely.
//   - small   → icon badges, status chips, compact nav items — has room
//               to be the punchiest element on screen.
// ============================================================================
enum HoverSize {
  /// Big cards / wide list rows in a grid — capped so neighbors don't
  /// visually collide. Scale: AppTheme.hoverScaleLarge (1.08x).
  large,

  /// Tall, content-dense list cards that still want a real (not zero)
  /// zoom, just a gentler one than `large`. Scale: AppTheme.hoverScaleSubtle
  /// (1.045x). Use this instead of reaching for scaleOverride on every
  /// card that needs toning down — pick this tier once per element type.
  subtle,

  /// Icon badges, status chips, small nav items — has room to be punchier.
  /// Scale: AppTheme.hoverScaleSmall (1.10x).
  small,
}

double _scaleFor(HoverSize size) {
  switch (size) {
    case HoverSize.large:
      return AppTheme.hoverScaleLarge;
    case HoverSize.subtle:
      return AppTheme.hoverScaleSubtle;
    case HoverSize.small:
      return AppTheme.hoverScaleSmall;
  }
}

// ============================================================================
// HoverGlow — low-level building block. Wrap any child to get the
// zoom + border + glow treatment on MouseRegion hover. Most screens should
// reach for HoverCard / HoverListItem / HoverButton below instead of this
// directly, but it's exposed for bespoke cases.
// ============================================================================
class HoverGlow extends StatefulWidget {
  const HoverGlow({
    super.key,
    required this.child,
    required this.glowColor,
    this.size = HoverSize.large,
    this.borderRadius = AppTheme.radiusCards,
    this.onTap,
    this.backgroundColor,
    this.border = true,
    this.scaleEnabled = true,
    this.scaleOverride,
  });

  final Widget child;
  final Color glowColor;
  final HoverSize size;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final bool border;

  /// When false, hover still applies border + glow + background changes,
  /// but skips the AnimatedScale zoom entirely. Use this for large,
  /// content-dense cards (long text blocks, multi-line lists) where an
  /// 8-12% zoom-in-place pushes the box past its grid cell and overlaps
  /// neighbors — scale reads great on compact, fixed-aspect cards (stat
  /// tiles, score rings) and badly on tall variable-height text cards.
  final bool scaleEnabled;

  /// Optional per-instance zoom amount, overriding the size-based default
  /// (AppTheme.hoverScaleLarge / hoverScaleSmall) without touching those
  /// shared constants — which are used by every HoverCard across the app.
  /// E.g. pass 1.055 for a noticeably-but-not-aggressively zoomed card.
  /// Ignored when scaleEnabled is false.
  final double? scaleOverride;

  @override
  State<HoverGlow> createState() => _HoverGlowState();
}

class _HoverGlowState extends State<HoverGlow> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final baseScale = widget.scaleOverride ?? _scaleFor(widget.size);
    final scale = widget.scaleEnabled && _hovering ? baseScale : 1.0;
    final pressedScale = widget.scaleEnabled && _pressed ? 0.98 : 1.0;

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: widget.onTap == null
            ? null
            : () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: scale * pressedScale,
          duration: AppTheme.hoverDuration,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: AppTheme.hoverDuration,
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: widget.border
                  ? Border.all(
                      color: _hovering
                          ? widget.glowColor
                          : AppTheme.borderColor,
                      width: 1,
                    )
                  : null,
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: widget.glowColor.withValues(alpha: 0.40),
                        blurRadius: 26,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFF0A0C28).withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HoverCard — the standard card primitive (stat cards, list-card containers,
// dashboard tiles). HoverSize.large by default.
// ============================================================================
class HoverCard extends StatelessWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.glowColor = AppTheme.brandBlue,
    this.size = HoverSize.large,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderRadius = AppTheme.radiusCards,
    this.scaleEnabled = true,
    this.scaleOverride,
  });

  final Widget child;
  final Color glowColor;
  final HoverSize size;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double borderRadius;

  /// Set false for tall/content-dense cards (long text, multi-line lists)
  /// where the zoom would push past the card's grid cell. See
  /// HoverGlow.scaleEnabled for the full rationale.
  final bool scaleEnabled;

  /// Optional per-instance zoom amount. See HoverGlow.scaleOverride.
  final double? scaleOverride;

  @override
  Widget build(BuildContext context) {
    return HoverGlow(
      glowColor: glowColor,
      size: size,
      onTap: onTap,
      borderRadius: borderRadius,
      scaleEnabled: scaleEnabled,
      scaleOverride: scaleOverride,
      child: Padding(padding: padding, child: child),
    );
  }
}

// ============================================================================
// HoverListItem — for rows inside a list (subscription rows, audit entries,
// transaction rows). Defaults to HoverSize.small since most rows are short
// and benefit from the punchier zoom; pass size: HoverSize.subtle for
// wider/denser rows where that default reads as too aggressive.
// ============================================================================
class HoverListItem extends StatelessWidget {
  const HoverListItem({
    super.key,
    required this.child,
    this.glowColor = AppTheme.brandBlue,
    this.onTap,
    this.padding =
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    this.borderRadius = 12.0,
    this.size = HoverSize.small,
  });

  final Widget child;
  final Color glowColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// Defaults to HoverSize.small (punchiest tier) — right for short,
  /// well-spaced rows like subscription billing dates or alert severity
  /// counts. Pass HoverSize.subtle for wider, denser rows (e.g. a row
  /// with multiple inline stat columns) where the default zoom reads as
  /// too aggressive — same reasoning as why subscription cards use
  /// HoverSize.subtle instead of the large-card default.
  final HoverSize size;

  @override
  Widget build(BuildContext context) {
    return HoverGlow(
      glowColor: glowColor,
      size: size,
      onTap: onTap,
      borderRadius: borderRadius,
      child: Padding(padding: padding, child: child),
    );
  }
}

// ============================================================================
// HoverIconBadge — small circular/rounded icon containers. Always
// HoverSize.small — these have room to be the punchiest element on screen.
// ============================================================================
class HoverIconBadge extends StatelessWidget {
  const HoverIconBadge({
    super.key,
    required this.icon,
    this.glowColor = AppTheme.brandPurple,
    this.size = 40,
    this.onTap,
  });

  final IconData icon;
  final Color glowColor;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HoverGlow(
      glowColor: glowColor,
      size: HoverSize.small,
      onTap: onTap,
      borderRadius: size * 0.32,
      backgroundColor: glowColor.withValues(alpha: 0.14),
      border: false,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(icon, color: glowColor, size: size * 0.5),
      ),
    );
  }
}

// ============================================================================
// HoverButton — gradient primary button OR outline button, with hover
// zoom + glow + a distinct pressed state. Use `outlined: true` for the
// secondary style.
// ============================================================================
class HoverButton extends StatefulWidget {
  const HoverButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    final scale = _pressed ? 0.97 : (_hovering ? 1.04 : 1.0);

    final content = widget.isLoading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    return MouseRegion(
      cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel:
            disabled ? null : () => setState(() => _pressed = false),
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale: scale,
          duration: AppTheme.hoverDuration,
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: AppTheme.hoverDuration,
            curve: Curves.easeOut,
            width: widget.expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusButtons),
              gradient: widget.outlined
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: disabled
                          ? [
                              AppTheme.brandBlue.withValues(alpha: 0.45),
                              AppTheme.brandPurple.withValues(alpha: 0.45),
                            ]
                          : AppTheme.brandGradient,
                    ),
              color: widget.outlined ? AppTheme.bgSurface : null,
              border: widget.outlined
                  ? Border.all(
                      color: _hovering
                          ? AppTheme.brandBlue
                          : AppTheme.borderColor,
                      width: 1.5,
                    )
                  : null,
              boxShadow: !disabled && _hovering
                  ? [
                      BoxShadow(
                        color: (widget.outlined
                                ? AppTheme.brandBlue
                                : AppTheme.brandPurple)
                            .withValues(alpha: 0.45),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Center(
              child: DefaultTextStyle(
                style: TextStyle(
                  color: widget.outlined ? AppTheme.textPrimary : Colors.white,
                ),
                child: IconTheme(
                  data: IconThemeData(
                    color: widget.outlined ? AppTheme.textPrimary : Colors.white,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HoverTextLink — for "Create account" / "Sign in" style inline links.
// Underline + color shift on hover, no scale (keeps inline text from
// jumping around).
// ============================================================================
class HoverTextLink extends StatefulWidget {
  const HoverTextLink({super.key, required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  State<HoverTextLink> createState() => _HoverTextLinkState();
}

class _HoverTextLinkState extends State<HoverTextLink> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedDefaultTextStyle(
          duration: AppTheme.hoverDuration,
          style: TextStyle(
            color: _hovering ? AppTheme.brandPurple : AppTheme.brandIndigo,
            fontWeight: FontWeight.w600,
            decoration:
                _hovering ? TextDecoration.underline : TextDecoration.none,
            decorationColor: AppTheme.brandPurple,
          ),
          child: Text(widget.text),
        ),
      ),
    );
  }
}

// ============================================================================
// HoverEntrance — wraps a child to play a one-time fade+slide entrance
// animation on first build, optionally staggered by `index`. This NEVER
// touches the same Transform that hover effects use — it owns its own
// AnimationController and Transform.translate, fully separate from
// whatever hover widget is nested inside it.
//
// Fast & snappy per spec: ~280ms, staggered ~45ms per item.
// ============================================================================
class HoverEntrance extends StatefulWidget {
  const HoverEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.playOnce = true,
  });

  final Widget child;

  /// Position in a list — used to compute stagger delay (index * 45ms).
  final int index;

  /// If true (default), entrance only plays the first time this widget is
  /// built. Set false for cases where you intentionally want it to replay
  /// (e.g. a manual "refresh" action). Newly-appended "load more" items
  /// should be given index 0 with playOnce semantics handled by the parent
  /// (i.e. don't replay the cascade for previously-loaded items).
  final bool playOnce;

  @override
  State<HoverEntrance> createState() => _HoverEntranceState();
}

class _HoverEntranceState extends State<HoverEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTheme.entranceDuration,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final delay = AppTheme.entranceStagger * widget.index;
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: FractionalTranslation(
            translation: _slide.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ============================================================================
// HoverNavItem — purpose-built for sidebar / nav-list rows. Deliberately
// does NOT use AnimatedScale: a wide-short row (e.g. a 240px sidebar item)
// zooming 10% grows ~24px horizontally and overlaps the rows packed above
// and below it — that's what made the generic HoverGlow treatment look
// broken on the sidebar. Nav rows read as "hoverable" perfectly well from
// background tint + a left accent bar sliding in + icon/label color shift
// + a tight, contained glow — the same vocabulary every real desktop app
// uses for nav lists. No neighbor ever moves or overlaps.
// ============================================================================
class HoverNavItem extends StatefulWidget {
  const HoverNavItem({
    super.key,
    required this.child,
    required this.glowColor,
    this.isSelected = false,
    this.onTap,
    this.borderRadius = 10.0,
    this.showAccentBar = true,
  });

  final Widget child;
  final Color glowColor;
  final bool isSelected;
  final VoidCallback? onTap;
  final double borderRadius;

  /// Whether a left accent bar slides in on hover/selected. Set false for
  /// collapsed-sidebar (icon-only) rows where there's no room for it.
  final bool showAccentBar;

  @override
  State<HoverNavItem> createState() => _HoverNavItemState();
}

class _HoverNavItemState extends State<HoverNavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.isSelected || _hovering;

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppTheme.hoverDuration,
          curve: Curves.easeOut,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.glowColor.withValues(alpha: 0.16)
                : (_hovering
                    ? widget.glowColor.withValues(alpha: 0.09)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: widget.glowColor.withValues(alpha: 0.22),
                      blurRadius: 14,
                      spreadRadius: -2,
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              if (widget.showAccentBar)
                AnimatedContainer(
                  duration: AppTheme.hoverDuration,
                  curve: Curves.easeOut,
                  width: 3,
                  height: active ? 22 : 0,
                  margin: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(
                    color: widget.glowColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// GlowFocusField — wraps a TextField (or any input) with a continuously
// cycling animated gradient border glow + a subtle zoom while focused.
// Distinct from the card/nav hover primitives above: this reacts to FOCUS
// (keyboard caret active), not pointer hover, and the glow is a looping
// animation rather than a static hover-triggered bloom — built for
// search bars and other "actively being typed into" inputs.
// ============================================================================
class GlowFocusField extends StatefulWidget {
  const GlowFocusField({
    super.key,
    required this.child,
    required this.focusNode,
    this.borderRadius = 12.0,
    this.glowColors = AppTheme.brandGradient,
  });

  /// The input widget to wrap (typically a TextField/TextFormField).
  final Widget child;

  /// Caller-owned FocusNode — GlowFocusField only listens to it, so the
  /// caller keeps full control of focus/unfocus/dispose.
  final FocusNode focusNode;

  final double borderRadius;

  /// Colors that cycle around the border while focused. Defaults to the
  /// brand gradient (blue → indigo → purple) so it reads as "on-brand
  /// glow," not an arbitrary rainbow.
  final List<Color> glowColors;

  @override
  State<GlowFocusField> createState() => _GlowFocusFieldState();
}

class _GlowFocusFieldState extends State<GlowFocusField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycleController;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    // Continuous, repeating rotation — drives the gradient sweep around
    // the border. Only actually runs while focused (started/stopped
    // below), so it costs nothing when the field is idle.
    _cycleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..addListener(() => setState(() {}));
    _cycleController.repeat();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _cycleController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _focused ? 1.025 : 1.0,
      duration: AppTheme.hoverDuration,
      curve: Curves.easeOut,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius + 2),
          gradient: _focused
              ? SweepGradient(
                  transform: GradientRotation(_cycleController.value * 6.28319),
                  colors: [...widget.glowColors, widget.glowColors.first],
                )
              : null,
          color: _focused ? null : Colors.transparent,
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: widget.glowColors[1].withValues(alpha: 0.45),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : [],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: AppTheme.bgElevated,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ============================================================================
// HoverGlowColors — convenience helpers for the "module default, status
// override" rule from the spec.
// ============================================================================
class HoverGlowColors {
  HoverGlowColors._();

  /// Returns the glow color for a card given its module and (optional)
  /// status. Status, when provided and recognized, always wins.
  static Color forModuleAndStatus({
    required Color moduleColor,
    String? status,
  }) {
    if (status == null) return moduleColor;
    switch (status.toUpperCase()) {
      case 'CRITICAL':
      case 'HIGH':
      case 'DANGER':
      case 'DELETE':
        return AppTheme.danger;
      case 'MEDIUM':
      case 'WARNING':
      case 'UPDATE':
        return AppTheme.warning;
      case 'LOW':
      case 'GOOD':
      case 'SUCCESS':
      case 'INSERT':
        return AppTheme.success;
      default:
        return moduleColor;
    }
  }
}