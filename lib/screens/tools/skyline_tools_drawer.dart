import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/role_config.dart';
import '../../models/user_model.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/sync_widgets.dart';
import '../seller_create_screen.dart';
import '../music/music_screen.dart';
import '../settings_screen.dart';
import '../storan_picker_screen.dart';
import 'ai_chat_screen.dart';
import 'instagram_downloader_screen.dart';
import 'whatsapp_sender_screen.dart';
import 'whatsapp_home_screen.dart';
import 'tiktok_downloader_screen.dart';

class SkylineToolsDrawer extends StatelessWidget {
  const SkylineToolsDrawer({
    super.key,
    required this.hostContext,
    required this.user,
    required this.online,
    required this.connected,
    required this.onOpenScreen,
    required this.onLogout,
  });

  final BuildContext hostContext;
  final UserModel? user;
  final int online;
  final bool connected;
  final Future<void> Function(Widget screen) onOpenScreen;
  final VoidCallback onLogout;

  static const _categories = <_ToolCategory>[
    _ToolCategory(
      icon: Icons.download_rounded,
      title: 'Downloader',
      subtitle: 'TikTok & media',
      stat: 'Fetch',
    ),
    _ToolCategory(
      icon: Icons.smart_toy_outlined,
      title: 'AI Tools',
      subtitle: 'Void AI chat',
      stat: 'Brain',
    ),
    _ToolCategory(
      icon: Icons.hub_rounded,
      title: 'Sender',
      subtitle: 'Kelola Sender',
      stat: 'Sender',
      directScreen: WhatsAppSenderScreen(),
    ),
    _ToolCategory(
      icon: Icons.music_note_rounded,
      title: 'Music',
      subtitle: 'Search · Play YouTube',
      stat: 'YT Play',
      directScreen: MusicScreen(),
    ),
    _ToolCategory(
      icon: Icons.settings_rounded,
      title: 'Pengaturan',
      subtitle: 'Profil & password',
      stat: 'Akun',
      directScreen: SettingsScreen(),
    ),
  ];

  _ToolCategory? _storanCategory(String role) {
    if (role == 'developer') return null;
    return const _ToolCategory(
      icon: Icons.shopping_bag_rounded,
      title: 'Storan Akun',
      subtitle: 'Member · Reseller · Owner',
      stat: 'Store',
      directScreen: StoranPickerScreen(),
    );
  }

  _ToolCategory? _buatAkunCategory(String role) {
    if (!RoleConfig.canSellerCreate(role)) return null;
    return const _ToolCategory(
      icon: Icons.person_add_alt_1_rounded,
      title: 'Buat Akun',
      subtitle: 'Fee Rp 3.000 + 2 bukti',
      stat: 'Create',
      directScreen: SellerCreateScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = user?.role ?? 'member';
    final storan = _storanCategory(role);
    final buatAkun = _buatAkunCategory(role);
    final categories = [
      ..._categories,
      ?buatAkun,
      ?storan,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      children: [
        _ToolsDrawerHeader(user: user, online: online, connected: connected, toolCount: categories.length),
        const SizedBox(height: 8),
        _ToolsGatewayDivider(),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('Kategori Menu', style: AppTypography.menuTitle().copyWith(fontSize: 14)),
            const Spacer(),
            Text('${categories.length} tools', style: AppTypography.tagline(color: AppColors.dashAccent)),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1,
            mainAxisSpacing: 10,
            childAspectRatio: 3.4,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return _ToolGridCard(
              category: category,
              onTap: () => _onCategoryTap(context, category),
            );
          },
        ),
        const SizedBox(height: 12),
        _DrawerLogoutButton(onTap: onLogout),
      ],
    );
  }

  void _onCategoryTap(BuildContext context, _ToolCategory category) {
    if (category.directScreen != null) {
      onOpenScreen(category.directScreen!);
      return;
    }
    if (category.title == 'Downloader') {
      _showDownloaderSheet(context);
      return;
    }
    if (category.title == 'AI Tools') {
      _showAiSheet(context);
    }
  }

  void _showAiSheet(BuildContext drawerContext) {
    final username = user?.displayName ?? user?.username ?? 'User';
    final role = user?.role ?? 'member';

    _presentToolSheet(
      drawerContext: drawerContext,
      title: 'AI TOOLS',
      subtitle: 'Pilih asisten AI',
      icon: Icons.smart_toy_rounded,
      tools: [
        _SheetToolDef(
          icon: Icons.auto_awesome_rounded,
          label: 'Void AI Chat',
          subtitle: 'Asisten pintar Bahasa Indonesia',
          screen: AiChatScreen(username: username, role: role),
        ),
      ],
    );
  }

  void _showDownloaderSheet(BuildContext drawerContext) {
    _presentToolSheet(
      drawerContext: drawerContext,
      title: 'DOWNLOADER',
      subtitle: 'Pilih tools media',
      icon: Icons.download_rounded,
      tools: const [
        _SheetToolDef(
          icon: Icons.music_video_rounded,
          label: 'TikTok Saver',
          subtitle: 'Download video tanpa watermark',
          screen: TiktokDownloaderScreen(),
        ),
        _SheetToolDef(
          icon: Icons.camera_alt_rounded,
          label: 'Instagram Saver',
          subtitle: 'Download reels, video & foto',
          screen: InstagramDownloaderScreen(),
        ),
      ],
    );
  }

  void _presentToolSheet({
    required BuildContext drawerContext,
    required String title,
    required String subtitle,
    required dynamic icon,
    required List<_SheetToolDef> tools,
  }) {
    Navigator.pop(drawerContext);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hostContext.mounted) return;
      showModalBottomSheet<void>(
        context: hostContext,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetCtx) {
          final bottomPad = MediaQuery.viewPaddingOf(sheetCtx).bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomPad),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.97),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.dashAccent.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: AppColors.dashAccent.withValues(alpha: 0.1),
                                ),
                                child: _DynamicIcon(icon, color: AppColors.dashAccent, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: AppTypography.statLabel().copyWith(letterSpacing: 1.4)),
                                    Text(subtitle, style: AppTypography.menuTitle().copyWith(fontSize: 15)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...tools.map(
                            (tool) => _SheetToolTile(
                              icon: tool.icon,
                              label: tool.label,
                              subtitle: tool.subtitle,
                              onTap: () {
                                Navigator.pop(sheetCtx);
                                onOpenScreen(tool.screen);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

class _ToolsDrawerHeader extends StatelessWidget {
  const _ToolsDrawerHeader({
    required this.user,
    required this.online,
    required this.connected,
    required this.toolCount,
  });

  final UserModel? user;
  final int online;
  final bool connected;
  final int toolCount;

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? user?.username ?? 'User';
    final role = user?.role ?? 'member';
    final roleLabel = RoleConfig.roleLabels[role] ?? role;

    return ElegantCard(
      accent: true,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('VOID TOOLS', style: AppTypography.statLabel().copyWith(letterSpacing: 1.6, color: AppColors.dashAccent)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: connected ? AppColors.success : AppColors.dashTextMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: AppColors.neoBlack, width: 2),
                  boxShadow: NeoShadow.hard(dx: 2, dy: 2),
                ),
                child: Text(
                  connected ? 'ONLINE' : 'OFFLINE',
                  style: AppTypography.tagline(color: Colors.white).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(name, style: AppTypography.menuTitle().copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('$roleLabel · $online device · $toolCount tools', style: AppTypography.welcomeMeta()),
        ],
      ),
    );
  }
}

class _ToolsGatewayDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.dashAccent.withValues(alpha: 0.12))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.build_circle_outlined, size: 13, color: AppColors.dashAccent.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text('TOOLS GATEWAY', style: AppTypography.statLabel().copyWith(letterSpacing: 1.4)),
            ],
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.dashAccent.withValues(alpha: 0.12))),
      ],
    );
  }
}

class _ToolGridCard extends StatelessWidget {
  const _ToolGridCard({required this.category, required this.onTap});

  final _ToolCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        splashColor: AppColors.dashAccent.withValues(alpha: 0.12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: AppColors.dashSurface,
            border: Border.all(color: AppColors.neoBlack, width: 3),
            boxShadow: NeoShadow.hardSm(),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    color: AppColors.dashAccent,
                    border: Border.all(color: AppColors.neoBlack, width: 2.5),
                    boxShadow: NeoShadow.hard(dx: 2, dy: 2),
                  ),
                  child: _DynamicIcon(category.icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(category.title, style: AppTypography.menuTitle().copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(category.subtitle, style: AppTypography.menuSubtitle().copyWith(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.dashAccent.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetToolTile extends StatelessWidget {
  const _SheetToolTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final dynamic icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.dashBg,
                border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.dashAccent.withValues(alpha: 0.1),
                    ),
                    child: _DynamicIcon(icon, color: AppColors.dashAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(label, style: AppTypography.menuTitle().copyWith(fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: AppTypography.menuSubtitle().copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.dashTextMuted.withValues(alpha: 0.7)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerLogoutButton extends StatelessWidget {
  const _DrawerLogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            color: AppColors.error,
            border: Border.all(color: AppColors.neoBlack, width: 2.5),
            boxShadow: NeoShadow.hardSm(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Text('Keluar Akun', style: AppTypography.menuTitle().copyWith(fontSize: 14, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetToolDef {
  const _SheetToolDef({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.screen,
  });

  final dynamic icon;
  final String label;
  final String subtitle;
  final Widget screen;
}

class _ToolCategory {
  const _ToolCategory({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.stat,
    this.directScreen,
  });

  final dynamic icon;
  final String title;
  final String subtitle;
  final String stat;
  final Widget? directScreen;
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
