import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/role_config.dart';
import '../services/auth_service.dart';
import '../services/bocchi_companion_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/dashboard_command_hub.dart';
import '../widgets/dashboard_hero_video.dart';
import '../widgets/dashboard_welcome_orb.dart';
import '../widgets/dashboard_wib_clock.dart';
import '../widgets/sync_widgets.dart';
import 'seller_create_screen.dart';
import 'settings_screen.dart';
import 'storan_picker_screen.dart';

class DashboardHomeScreen extends StatelessWidget {
  const DashboardHomeScreen({super.key, required this.onNavigateTab});

  final ValueChanged<int> onNavigateTab;

  CommandHubItem? _storanItem(BuildContext context, String role) {
    if (role == 'developer') return null;
    return CommandHubItem(
      title: 'Storan Akun',
      subtitle: 'Pilih Member · Reseller · Owner',
      tag: 'STORE',
      icon: Icons.shopping_bag_rounded,
      accent: const Color(0xFF00E676),
      onTap: () => Navigator.push(context, syncPageRoute(const StoranPickerScreen())),
    );
  }

  CommandHubItem? _buatAkunItem(BuildContext context) {
    return CommandHubItem(
      title: 'Buat Akun',
      subtitle: 'Buyer + storan fee Rp 5.000',
      tag: 'CREATE',
      icon: Icons.person_add_alt_1_rounded,
      accent: const Color(0xFF7B1FA2),
      onTap: () => Navigator.push(context, syncPageRoute(const SellerCreateScreen())),
    );
  }

  List<CommandHubItem> _buildMenuItems(BuildContext context, {required bool canBuatAkun, required bool canStoran, required bool hasSms}) {
    final storan = canStoran ? _storanItem(context, 'member') : null;
    final buatAkun = canBuatAkun ? _buatAkunItem(context) : null;
    return [
      CommandHubItem(
        title: 'Kelola Device',
        subtitle: 'Daftar perangkat terhubung',
        tag: 'DEVICE',
        icon: Icons.devices_rounded,
        accent: const Color(0xFF00C853),
        onTap: () => onNavigateTab(1),
      ),
      CommandHubItem(
        title: 'This Is My Era',
        subtitle: 'Panel kontrol remote',
        tag: 'ERA',
        icon: Icons.tune_rounded,
        accent: const Color(0xFF39E75F),
        onTap: () => onNavigateTab(2),
      ),
      if (hasSms)
        CommandHubItem(
          title: 'Pesan SMS',
          subtitle: 'Baca SMS device terpilih',
          tag: 'SMS',
          icon: Icons.sms_rounded,
          accent: const Color(0xFF009624),
          onTap: () => onNavigateTab(3),
        ),
      ?buatAkun,
      ?storan,
      CommandHubItem(
        title: 'Pengaturan',
        subtitle: 'Profil, password & logout',
        tag: 'SYS',
        icon: Icons.settings_rounded,
        accent: AppColors.dashAccent,
        onTap: () => Navigator.push(context, syncPageRoute(const SettingsScreen())),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final auth = context.watch<AuthService>();
    final socket = context.watch<SocketService>();
    final role = user?.role ?? 'member';
    final canBuatAkun = RoleConfig.canSellerCreate(role);
    final canStoran = role != 'developer';
    final menuItems = _buildMenuItems(
      context,
      canBuatAkun: canBuatAkun,
      canStoran: canStoran,
      hasSms: socket.selectedDeviceId != null,
    );

    context.read<BocchiCompanionService>().bindContext(
          username: user?.displayName ?? user?.username ?? 'kamu',
          role: role,
          hasDevice: socket.selectedDeviceId != null,
          onNavigateTab: onNavigateTab,
        );

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            FadeSlideIn(
              child: Center(
                child: DashboardWelcomeOrb(
                  name: user?.displayName ?? user?.username ?? 'User',
                  role: role,
                  online: socket.devices.length,
                  avatarPath: auth.avatarPath,
                  onTap: () => Navigator.push(context, syncPageRoute(const SettingsScreen())),
                ),
              ),
            ),
            const SizedBox(height: 10),
            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: const DashboardWibClock(),
            ),
            const SizedBox(height: 12),
            FadeSlideIn(
              delay: const Duration(milliseconds: 55),
              child: const DashboardHeroVideo(),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              delay: const Duration(milliseconds: 60),
              child: Row(
                children: [
                  _StatChip(label: 'DEVICE', value: '${socket.devices.length}', onTap: () => onNavigateTab(1)),
                  const SizedBox(width: 10),
                  _StatChip(label: 'SOCKET', value: socket.connected ? 'ON' : 'OFF', active: socket.connected),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              delay: const Duration(milliseconds: 100),
              child: DashboardCommandHub(items: menuItems),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, this.onTap, this.active = true});

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DashCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTypography.statValue(active: active)),
            const SizedBox(height: 4),
            Text(label, style: AppTypography.statLabel()),
          ],
        ),
      ),
    );
  }
}