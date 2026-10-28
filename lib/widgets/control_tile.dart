import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class ControlTile extends StatelessWidget {
  const ControlTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.color = AppColors.dashAccent,
    this.onTap,
    this.trailing,
    this.bottom,
    this.cyber = false,
  });

  final String title;
  final String subtitle;
  final dynamic icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? bottom;
  /// Dark cyber list-row style (control panel reference UI).
  final bool cyber;

  @override
  Widget build(BuildContext context) {
    if (cyber) return _buildCyber();
    return _buildNeo();
  }

  Widget _buildNeo() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.dashSurface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.neoBlack, width: 3),
            boxShadow: NeoShadow.hardSm(),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        color: color,
                        border: Border.all(color: AppColors.neoBlack, width: 2.5),
                        boxShadow: NeoShadow.hard(dx: 2, dy: 2),
                      ),
                      child: _DynamicIcon(icon, size: 22, color: Colors.white),
                    ),
                    const Spacer(),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 10),
                Text(title, style: AppTypography.menuTitle().copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTypography.menuSubtitle().copyWith(fontSize: 11)),
                if (bottom != null) ...[const SizedBox(height: 8), bottom!],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCyber() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF121A28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.55)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10),
                      ],
                    ),
                    child: _DynamicIcon(icon, size: 22, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (bottom != null) ...[const SizedBox(height: 10), bottom!],
            ],
          ),
        ),
      ),
    );
  }
}

class PinkSwitch extends StatelessWidget {
  const PinkSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = AppColors.dashAccent,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.9,
      child: Switch.adaptive(
        value: value,
        activeColor: activeColor,
        activeTrackColor: activeColor.withValues(alpha: 0.5),
        inactiveThumbColor: AppColors.dashTextMuted,
        inactiveTrackColor: AppColors.dashTextMuted.withValues(alpha: 0.3),
        onChanged: onChanged,
      ),
    );
  }
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
