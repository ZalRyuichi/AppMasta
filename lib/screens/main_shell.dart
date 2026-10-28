import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/smooth_nav_bar.dart';
import '../widgets/sync_backgrounds.dart';
import '../widgets/sync_widgets.dart';
import 'dashboard_home_screen.dart';
import 'device_control_screen.dart';
import 'devices_screen.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'sms_screen.dart';
import 'whatsapp/whatsapp_home_screen.dart';
import 'tools/skyline_tools_drawer.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthService>();
      if (auth.token != null) context.read<SocketService>().connect(auth.token!);
    });
  }

  @override
  void dispose() {
    context.read<SocketService>().disconnect();
    super.dispose();
  }

  void _goControl() => setState(() => _index = 2);

  void _closeDrawer() {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  Future<void> _openScreen(Widget screen) async {
    _closeDrawer();
    await Navigator.push(context, syncPageRoute(screen));
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.dashSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.neoBlack, width: 3),
        ),
        title: Text('Keluar Akun', style: AppTypography.menuTitle()),
        content: Text('Yakin ingin logout dari sesi ini?', style: AppTypography.menuSubtitle()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal',
                style: TextStyle(color: AppColors.dashTextMuted, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.dashAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AuthService>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
        syncPageRoute(const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final hasDevice = socket.selectedDeviceId != null;

    // ═══════════════════════════════════════════════════════════
    // NAVBAR BAWAH: HOME · BUG · DEVICE · ERA (+ PESAN opsional)
    // ═══════════════════════════════════════════════════════════
    final destinations = <SmoothNavItem>[
      const SmoothNavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Home',
      ),
      const SmoothNavItem(
        icon: Icons.bug_report_outlined,
        activeIcon: Icons.bug_report,
        label: 'Bug',
      ),
      const SmoothNavItem(
        icon: Icons.smartphone_outlined,
        activeIcon: Icons.smartphone_rounded,
        label: 'Device',
      ),
      const SmoothNavItem(
        icon: Icons.tune_outlined,
        activeIcon: Icons.tune,
        label: 'Era',
      ),
      if (hasDevice)
        const SmoothNavItem(
          icon: Icons.forum_outlined,
          activeIcon: Icons.forum_rounded,
          label: 'Pesan',
        ),
    ];

    final pages = <Widget>[
      DashboardHomeScreen(onNavigateTab: (i) => setState(() => _index = i)),
      const WhatsAppHomeScreen(), // ← Bug page
      DevicesScreen(onDeviceSelected: () {
        showSyncSnack(context, 'Device dipilih. Buka tab Era.', success: true);
        _goControl();
      }),
      DeviceControlScreen(onPickDevice: () => setState(() => _index = 2)),
      if (hasDevice) const SmsScreen(),
    ];

    // Clamp supaya kalau `hasDevice` berubah, index tidak out-of-range
    final safeIndex = _index.clamp(0, pages.length - 1);

    // Kalau user pindah ke tab Pesan tapi device hilang, balik ke tab aman
    if (_index >= pages.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _index = 0);
      });
    }

    final user = context.watch<AuthService>().user;

    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        extendBody: true,
        drawer: Drawer(
          width: 320,
          backgroundColor: AppColors.dashBg,
          shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.horizontal(right: Radius.circular(AppRadius.xl))),
          child: SakuraMeshBackground(
            child: SafeArea(
              child: SkylineToolsDrawer(
                hostContext: context,
                user: user,
                online: socket.devices.length,
                connected: socket.connected,
                onOpenScreen: _openScreen,
                onLogout: _logout,
              ),
            ),
          ),
        ),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(58),
          child: AppBar(
            backgroundColor: AppColors.dashSurface,
            foregroundColor: AppColors.dashText,
            elevation: 0,
            title: Text(
              'VOID SPY',
              style: AppTypography.brandLogo(
                  size: 22,
                  color: AppColors.dashText,
                  shadow: AppColors.dashAccent),
            ),
            shape: const Border(
              bottom: BorderSide(color: AppColors.neoBlack, width: 3),
            ),
            actions: [
              if (socket.connected)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AppColors.neoBlack, width: 2),
                        boxShadow: NeoShadow.hard(dx: 2, dy: 2),
                      ),
                      child: Text(
                        '${socket.devices.length} online',
                        style: AppTypography.tagline(color: Colors.white)
                            .copyWith(fontWeight: FontWeight.w800, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              IconButton(
                onPressed: () =>
                    Navigator.push(context, syncPageRoute(const SettingsScreen())),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.neoYellow,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.neoBlack, width: 2),
                    boxShadow: NeoShadow.hard(dx: 2, dy: 2),
                  ),
                  child: const Icon(Icons.settings_outlined,
                      size: 18, color: AppColors.neoBlack),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        body: SakuraMeshBackground(
          child: IndexedStack(index: safeIndex, children: pages),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: SmoothNavBar(
            items: destinations,
            selectedIndex: safeIndex,
            onTap: (i) => setState(() => _index = i),
          ),
        ),
      ),
    );
  }
}