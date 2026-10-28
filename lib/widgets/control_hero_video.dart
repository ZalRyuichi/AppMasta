import 'package:flutter/material.dart';

import '../models/device_model.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Hero header di Device Control — foto 16:9 (bukan video) + overlay info device.
class ControlHeroVideo extends StatelessWidget {
  const ControlHeroVideo({super.key, required this.device});

  final DeviceModel device;

  static final _radius = BorderRadius.circular(AppRadius.lg);

  @override
  Widget build(BuildContext context) {
    final batteryLabel = device.battery >= 0 ? '${device.battery}%' : '?';
    final chargeLabel = device.charging ? ' · Charging' : '';
    final themeLabel = device.status.currentTheme.isNotEmpty && device.status.currentTheme != 'default'
        ? ' · ${device.status.currentTheme}'
        : '';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: AppColors.dashAccent.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.2)),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Foto Bocchi 16:9 (tanpa teks Welcome)
                Image.asset(
                  'assets/images/bocchi_control.png',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.15),
                  errorBuilder: (_, __, ___) => Image.asset(
                    'assets/images/control_panel.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.dashAccent.withValues(alpha: 0.12),
                      child: const Center(
                        child: Icon(Icons.smartphone_rounded, size: 48, color: AppColors.dashAccent),
                      ),
                    ),
                  ),
                ),

                // Gradient overlay biar teks kebaca
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.12),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),

                // Badge ONLINE
                Positioned(
                  left: 14,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'ONLINE',
                          style: AppTypography.statLabel().copyWith(color: Colors.white, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),

                // Info device di bawah
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.smartphone_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              device.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.welcomeName().copyWith(
                                color: Colors.white,
                                fontSize: 18,
                                shadows: const [Shadow(color: Colors.black54, blurRadius: 8)],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Android ${device.androidVersion} · SDK ${device.sdkVersion >= 0 ? device.sdkVersion : '?'} · Bat $batteryLabel$chargeLabel$themeLabel',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.welcomeMeta().copyWith(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: 11,
                          shadows: const [Shadow(color: Colors.black45, blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        device.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.techId().copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 10,
                          shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                        ),
                      ),
                    ],
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
