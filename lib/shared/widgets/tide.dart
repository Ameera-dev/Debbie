import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';

class TidePageBackground extends StatelessWidget {
  const TidePageBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppColors.darkBackground : AppColors.background;
    final glow = isDark ? AppColors.darkSurface : AppColors.paperDim;
    final accent = AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.08);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [base, Color.lerp(base, glow, 0.35) ?? base, base],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _GlowOrb(size: 260, color: accent),
          ),
          Positioned(
            top: 120,
            left: -70,
            child: _GlowOrb(
              size: 220,
              color: AppColors.secondary.withValues(
                alpha: isDark ? 0.08 : 0.06,
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -60,
            child: _GlowOrb(
              size: 240,
              color: AppColors.primaryDeep.withValues(
                alpha: isDark ? 0.10 : 0.05,
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class TidePageIntro extends StatelessWidget {
  const TidePageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 0),
  });

  final String eyebrow;
  final Widget title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final subtitleColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TideEyebrow(label: eyebrow),
                const SizedBox(height: 6),
                title,
                if (subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: subtitleColor),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class TideScrollHeader extends StatelessWidget {
  const TideScrollHeader({
    super.key,
    required this.compactTitle,
    required this.eyebrow,
    required this.expandedTitle,
    this.subtitle,
    this.trailing,
    this.actions = const [],
    this.showBackButton = false,
    this.onBackPressed,
    this.leading,
    this.leadingWidth,
    this.expandedHeight = 176,
    this.toolbarHeight = 60,
  });

  final String compactTitle;
  final String eyebrow;
  final Widget expandedTitle;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Widget? leading;
  final double? leadingWidth;
  final double expandedHeight;
  final double toolbarHeight;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TideScrollHeaderDelegate(
        compactTitle: compactTitle,
        eyebrow: eyebrow,
        expandedTitle: expandedTitle,
        subtitle: subtitle,
        trailing: trailing,
        actions: actions,
        showBackButton: showBackButton,
        onBackPressed: onBackPressed,
        leading: leading,
        leadingWidth: leadingWidth,
        expandedHeight: expandedHeight,
        toolbarHeight: toolbarHeight,
        topPadding: topPadding,
      ),
    );
  }
}

class TideEyebrow extends StatelessWidget {
  const TideEyebrow({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fallback = Theme.of(context).brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;

    return Text(
      label.toUpperCase(),
      style: GoogleFonts.nunito(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
        color: color ?? fallback,
      ),
    );
  }
}

class TideHeaderIconButton extends StatelessWidget {
  const TideHeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final child = Material(
      color: isDark ? AppColors.darkSurface : AppColors.surfaceWarm,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 18,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );

    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}

class TideBackPill extends StatelessWidget {
  const TideBackPill({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.surfaceWarm;
    final border = isDark
        ? AppColors.darkTextSecondary.withValues(alpha: 0.16)
        : AppColors.divider;
    final ink = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: AppColors.shadow.withValues(alpha: 0.04),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  size: 15,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TideCard extends StatelessWidget {
  const TideCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
    this.color,
    this.gradient,
    this.radius = 22,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null
            ? color ?? Theme.of(context).cardTheme.color
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color:
              borderColor ??
              (isDark
                  ? AppColors.darkTextSecondary.withValues(alpha: 0.18)
                  : AppColors.divider.withValues(alpha: 0.9)),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class TideSurfaceIcon extends StatelessWidget {
  const TideSurfaceIcon({
    super.key,
    required this.icon,
    this.color,
    this.backgroundColor,
    this.size = 18,
  });

  final IconData icon;
  final Color? color;
  final Color? backgroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color:
            backgroundColor ??
            (isDark ? AppColors.darkSurface : AppColors.surfaceWarm),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkTextSecondary.withValues(alpha: 0.16)
              : AppColors.divider,
        ),
      ),
      child: Icon(
        icon,
        size: size,
        color:
            color ?? (isDark ? AppColors.darkTextPrimary : AppColors.textSoft),
      ),
    );
  }
}

class TidePill extends StatelessWidget {
  const TidePill({
    super.key,
    required this.label,
    this.color,
    this.backgroundColor,
    this.icon,
  });

  final String label;
  final Color? color;
  final Color? backgroundColor;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? Colors.white;
    final background =
        backgroundColor ?? AppColors.primary.withValues(alpha: 0.16);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 6)],
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class TideBarSegment {
  const TideBarSegment({required this.color, required this.value});

  final Color color;
  final double value;
}

class TideStackedBar extends StatelessWidget {
  const TideStackedBar({super.key, required this.segments, this.height = 8});

  final List<TideBarSegment> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(
      0,
      (sum, segment) => sum + segment.value,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: height,
        child: Row(
          children: segments.map((segment) {
            final flex = total == 0
                ? 1
                : (segment.value / total * 1000).round();
            return Expanded(
              flex: flex <= 0 ? 1 : flex,
              child: DecoratedBox(
                decoration: BoxDecoration(color: segment.color),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _TideScrollHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TideScrollHeaderDelegate({
    required this.compactTitle,
    required this.eyebrow,
    required this.expandedTitle,
    required this.subtitle,
    required this.trailing,
    required this.actions,
    required this.showBackButton,
    required this.onBackPressed,
    required this.leading,
    required this.leadingWidth,
    required this.expandedHeight,
    required this.toolbarHeight,
    required this.topPadding,
  });

  final String compactTitle;
  final String eyebrow;
  final Widget expandedTitle;
  final String? subtitle;
  final Widget? trailing;
  final List<Widget> actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Widget? leading;
  final double? leadingWidth;
  final double expandedHeight;
  final double toolbarHeight;
  final double topPadding;

  @override
  double get minExtent => topPadding + toolbarHeight + 12;

  @override
  double get maxExtent => topPadding + expandedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = Theme.of(context);
    final range = (maxExtent - minExtent).clamp(1.0, double.infinity);
    final progress = (shrinkOffset / range).clamp(0.0, 1.0);
    final expandedOpacity = 1 - Curves.easeOut.transform(progress);
    final compactOpacity = Curves.easeOut.transform(progress);
    final bgColor = Color.lerp(
      Colors.transparent,
      theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
      compactOpacity,
    );
    final borderColor = Color.lerp(
      Colors.transparent,
      theme.dividerColor.withValues(alpha: 0.7),
      compactOpacity,
    );
    final subtitleColor = theme.brightness == Brightness.dark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: borderColor ?? Colors.transparent),
        ),
        boxShadow: compactOpacity > 0.02
            ? [
                BoxShadow(
                  color: AppColors.shadow.withValues(
                    alpha: 0.05 * compactOpacity,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: SizedBox.expand(
            child: Stack(
              children: [
                SizedBox(
                  height: toolbarHeight,
                  child: Row(
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 8),
                      ] else if (showBackButton)
                        TideHeaderIconButton(
                          icon: Icons.arrow_back_rounded,
                          onPressed:
                              onBackPressed ??
                              () => Navigator.of(context).maybePop(),
                          tooltip: 'Back',
                        ),
                      if (showBackButton) const SizedBox(width: 8),
                      Expanded(
                        child: Opacity(
                          opacity: compactOpacity,
                          child: Text(
                            compactTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lora(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: theme.brightness == Brightness.dark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      if (actions.isNotEmpty) ...actions,
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: toolbarHeight + 4 - (10 * progress),
                  bottom: 0,
                  child: IgnorePointer(
                    ignoring: progress > 0.75,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final showEyebrow = constraints.maxHeight > 70;
                        final showSubtitle =
                            subtitle != null && constraints.maxHeight > 112;
                        final showTrailing =
                            trailing != null && constraints.maxHeight > 118;

                        return ClipRect(
                          child: Opacity(
                            opacity: expandedOpacity,
                            child: Transform.translate(
                              offset: Offset(0, -10 * progress),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (showEyebrow) ...[
                                          TideEyebrow(label: eyebrow),
                                          const SizedBox(height: 6),
                                        ],
                                        Flexible(
                                          child: Align(
                                            alignment: Alignment.topLeft,
                                            child: expandedTitle,
                                          ),
                                        ),
                                        if (showSubtitle) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            subtitle!,
                                            maxLines: 2,
                                            overflow: TextOverflow.fade,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                                  color: subtitleColor,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (showTrailing) ...[
                                    const SizedBox(width: 12),
                                    trailing!,
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TideScrollHeaderDelegate oldDelegate) {
    return compactTitle != oldDelegate.compactTitle ||
        eyebrow != oldDelegate.eyebrow ||
        subtitle != oldDelegate.subtitle ||
        trailing != oldDelegate.trailing ||
        actions != oldDelegate.actions ||
        showBackButton != oldDelegate.showBackButton ||
        leading != oldDelegate.leading ||
        leadingWidth != oldDelegate.leadingWidth ||
        expandedHeight != oldDelegate.expandedHeight ||
        toolbarHeight != oldDelegate.toolbarHeight ||
        topPadding != oldDelegate.topPadding ||
        onBackPressed != oldDelegate.onBackPressed ||
        expandedTitle != oldDelegate.expandedTitle;
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
