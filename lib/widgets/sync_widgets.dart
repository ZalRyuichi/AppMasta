import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'sync_backgrounds.dart';

class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero, this.offsetY = 18});

  final Widget child;
  final Duration delay;
  final double offsetY;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: AppMotion.normal);
    _fade = CurvedAnimation(parent: _ctrl, curve: AppMotion.curve);
    _slide = Tween<Offset>(begin: Offset(0, widget.offsetY / 100), end: Offset.zero).animate(_fade);
    Future<void>.delayed(widget.delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class SyncCard extends StatelessWidget {
  const SyncCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(padding: padding, child: child);
  }
}

class DashCard extends StatelessWidget {
  const DashCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: AppColors.dashSurface,
        border: Border.all(color: AppColors.neoBlack, width: 3),
        boxShadow: NeoShadow.hardSm(),
      ),
      child: child,
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        splashColor: AppColors.dashAccent.withValues(alpha: 0.12),
        highlightColor: AppColors.dashAccent.withValues(alpha: 0.06),
        child: card,
      ),
    );
  }
}

class ElegantCard extends StatelessWidget {
  const ElegantCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.accent = false, this.onTap});

  final Widget child;
  final EdgeInsets padding;
  final bool accent;
  final VoidCallback? onTap;

  static const surface = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: surface,
        border: Border.all(color: AppColors.neoBlack, width: 3),
        boxShadow: NeoShadow.hardSm(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md - 1),
        child: Stack(
          children: [
            if (accent)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 6,
                  color: AppColors.dashAccent,
                ),
              ),
            Padding(
              padding: padding.copyWith(left: accent ? padding.left + 8 : padding.left),
              child: child,
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: AppColors.dashAccent.withValues(alpha: 0.12),
        child: card,
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.icon, required this.title, required this.subtitle});

  final dynamic icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: AppColors.dashAccent.withValues(alpha: 0.07),
            border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.14)),
          ),
          child: _DynamicIcon(icon, color: AppColors.dashAccent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.menuTitle()),
              Text(subtitle, style: AppTypography.menuSubtitle()),
            ],
          ),
        ),
      ],
    );
  }
}

class SyncPrimaryButton extends StatefulWidget {
  const SyncPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.variant = ButtonVariant.dark,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final dynamic icon;
  final ButtonVariant variant;

  @override
  State<SyncPrimaryButton> createState() => _SyncPrimaryButtonState();
}

enum ButtonVariant { dark, light, outline }

class _SyncPrimaryButtonState extends State<SyncPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.variant == ButtonVariant.dark;
    final isOutline = widget.variant == ButtonVariant.outline;

    final bg = isOutline
        ? Colors.transparent
        : (isDark ? AppColors.accent : AppColors.dashAccent);

    final fg = isOutline
        ? (isDark ? AppColors.accent2 : AppColors.dashText)
        : Colors.white;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.loading ? null : widget.onPressed,
          onHighlightChanged: (v) => setState(() => _pressed = v),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: bg,
              border: Border.all(
                color: AppColors.neoBlack,
                width: 2.5,
              ),
              boxShadow: isOutline ? null : NeoShadow.hard(dx: 4, dy: 4),
            ),
            child: Center(
              child: widget.loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[_DynamicIcon(widget.icon, size: 18, color: fg), const SizedBox(width: 8)],
                        Text(
                          widget.label,
                          style: AppTypography.menuTitle().copyWith(fontSize: 13, letterSpacing: 0.6, color: fg),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.light = false});

  final String title;
  final String? subtitle;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final accent = light ? AppColors.dashAccent : AppColors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: light ? AppTypography.sectionTitle() : AppTypography.sectionTitle(light: false),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: light ? AppTypography.sectionSubtitle() : AppTypography.sectionSubtitle(light: false),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0)]),
          ),
        ),
      ],
    );
  }
}

Route<T> syncPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: AppMotion.normal,
    reverseTransitionDuration: AppMotion.fast,
    transitionsBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key, required this.label, this.active = true, this.light = true});

  final String label;
  final bool active;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: color.withValues(alpha: light ? 0.1 : 0.14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: active ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)] : null),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: light ? (active ? const Color(0xFF2E7D4A) : AppColors.dashTextMuted) : color)),
        ],
      ),
    );
  }
}

class SyncHeroBanner extends StatelessWidget {
  const SyncHeroBanner({super.key, required this.title, required this.subtitle, this.light = true});

  final String title;
  final String subtitle;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: light
              ? [AppColors.dashAccent.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.95), AppColors.dashAccent2.withValues(alpha: 0.1)]
              : [AppColors.accent.withValues(alpha: 0.2), AppColors.card, AppColors.accent2.withValues(alpha: 0.08)],
        ),
        border: Border.all(color: (light ? AppColors.dashAccent : AppColors.accent).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: (light ? AppColors.dashAccent : AppColors.accent).withValues(alpha: 0.1),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: light ? const Color(0xFF6B2848) : AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: light ? AppColors.dashText.withValues(alpha: 0.85) : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

bool _scaffoldHasBottomChrome(BuildContext context) {
  final scaffold = Scaffold.maybeOf(context);
  if (scaffold == null) return false;
  return scaffold.widget.bottomNavigationBar != null ||
      scaffold.widget.persistentFooterButtons != null ||
      scaffold.widget.floatingActionButton != null;
}

void showSyncSnack(BuildContext context, String message, {bool error = false, bool success = false}) {
  final icon = error
      ? Icons.error_outline_rounded
      : success
          ? Icons.check_circle_outline_rounded
          : Icons.info_outline_rounded;
  final color = error ? AppColors.error : success ? AppColors.success : AppColors.accent2;
  final pinned = _scaffoldHasBottomChrome(context);

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            _DynamicIcon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: AppTypography.menuSubtitle().copyWith(fontWeight: FontWeight.w600, color: Colors.white))),
          ],
        ),
        behavior: pinned ? SnackBarBehavior.fixed : SnackBarBehavior.floating,
        margin: pinned ? null : const EdgeInsets.fromLTRB(16, 12, 16, 16),
        duration: const Duration(seconds: 3),
      ),
    );
}

// WEBA2APK_DYNAMIC_ICON_START
class _DynamicIcon extends StatelessWidget {
  final dynamic icon;
  final double? size;
  final Color? color;

  const _DynamicIcon(this.icon, {Key? key, this.size, this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (icon == null) return const SizedBox(width: 0, height: 0);
    return Center(widthFactor: 1.0, heightFactor: 1.0, child: Icon(icon, size: size, color: color));
  }
}
// WEBA2APK_DYNAMIC_ICON_END
