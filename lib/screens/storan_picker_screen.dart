import 'package:flutter/material.dart';

import '../core/role_config.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/sync_backgrounds.dart';
import '../widgets/sync_widgets.dart';
import 'order_screen.dart';

class StoranPickerScreen extends StatelessWidget {
  const StoranPickerScreen({super.key});

  static const _roles = ['member', 'reseller', 'partner', 'owner'];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('PILIH STORAN', style: AppTypography.brand(size: 20)),
        ),
        body: SakuraMeshBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              FadeSlideIn(
                child: ElegantCard(
                  accent: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Buat Akun Baru', style: AppTypography.brand(size: 22)),
                      const SizedBox(height: 6),
                      Text(
                        'Pilih paket storan sesuai role yang ingin dibuat.',
                        style: AppTypography.menuSubtitle(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ..._roles.asMap().entries.map((entry) {
                final role = entry.value;
                final delay = Duration(milliseconds: 40 + entry.key * 50);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FadeSlideIn(
                    delay: delay,
                    child: _StoranRoleCard(
                      role: role,
                      onTap: () => Navigator.push(
                        context,
                        syncPageRoute(OrderScreen(fixedRole: role)),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoranRoleCard extends StatelessWidget {
  const _StoranRoleCard({required this.role, required this.onTap});

  final String role;
  final VoidCallback onTap;

  dynamic get _icon => switch (role) {
        'owner' => Icons.workspace_premium_rounded,
        'reseller' => Icons.storefront_rounded,
        'partner' => Icons.handshake_rounded,
        _ => Icons.person_rounded,
      };

  Color get _accent => switch (role) {
        'owner' => const Color(0xFF9C27B0),
        'reseller' => const Color(0xFF00E676),
        'partner' => const Color(0xFF00838F),
        _ => AppColors.dashAccent,
      };

  @override
  Widget build(BuildContext context) {
    final label = RoleConfig.roleLabels[role] ?? role;
    final price = RoleConfig.productPrices[role] ?? 0;
    final priceText = 'Rp ${price.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 104,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: ElegantCard.surface,
            border: Border.all(color: _accent.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: _accent.withValues(alpha: 0.1),
                    border: Border.all(color: _accent.withValues(alpha: 0.18)),
                  ),
                  child: _DynamicIcon(_icon, color: _accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Storan $label', style: AppTypography.menuTitle()),
                      const SizedBox(height: 2),
                      Text('Upload foto bukti · $priceText', style: AppTypography.menuSubtitle()),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: _accent.withValues(alpha: 0.75)),
              ],
            ),
          ),
        ),
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
