import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

enum CommandTileSize { hero, grid, wide }

class CommandHubItem {
  const CommandHubItem({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.onTap,
    this.size = CommandTileSize.wide,
    this.accent = AppColors.dashAccent,
  });

  final String title;
  final String subtitle;
  final String tag;
  final dynamic icon;
  final VoidCallback onTap;
  final CommandTileSize size;
  final Color accent;
}

class DashboardCommandHub extends StatelessWidget {
  const DashboardCommandHub({
    super.key,
    required this.items,
  });

  final List<CommandHubItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommandHubHeader(count: items.length),
        const SizedBox(height: 12),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CommandTile(item: item),
          ),
        ),
      ],
    );
  }
}

class _CommandHubHeader extends StatelessWidget {
  const _CommandHubHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('COMMAND HUB', style: AppTypography.statLabel().copyWith(letterSpacing: 1.8, color: AppColors.dashAccent)),
            const SizedBox(height: 2),
            Text('Menu Utama', style: AppTypography.sectionTitle()),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.dashAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.14)),
          ),
          child: Text('$count akses', style: AppTypography.tagline(color: AppColors.dashAccent)),
        ),
      ],
    );
  }
}

class _CommandTile extends StatelessWidget {
  const _CommandTile({required this.item});

  final CommandHubItem item;

  static const _surface = Color(0xFFFFFCFE);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: item.accent.withValues(alpha: 0.08),
        highlightColor: item.accent.withValues(alpha: 0.04),
        child: Ink(
          height: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _surface,
            border: Border.all(color: item.accent.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: item.accent.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3,
                    color: item.accent.withValues(alpha: 0.75),
                  ),
                ),
                Positioned(
                  right: 14,
                  top: 16,
                  child: _DynamicIcon(
                    item.icon,
                    size: 48,
                    color: item.accent.withValues(alpha: 0.1),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Row(
                      children: [
                        _IconBadge(icon: item.icon, accent: item.accent, size: 46),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(item.title, style: AppTypography.menuTitle().copyWith(fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(
                                item.subtitle,
                                style: AppTypography.menuSubtitle().copyWith(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        _TagChip(label: item.tag, accent: item.accent),
                        const SizedBox(width: 8),
                        Icon(Icons.north_east_rounded, size: 18, color: item.accent.withValues(alpha: 0.65)),
                      ],
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
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.accent, required this.size});

  final dynamic icon;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: accent.withValues(alpha: 0.1),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: _DynamicIcon(icon, color: accent, size: size * 0.48),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.accent});

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: accent.withValues(alpha: 0.07),
      ),
      child: Text(
        label,
        style: AppTypography.statLabel().copyWith(fontSize: 9, letterSpacing: 1.1, color: accent),
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
