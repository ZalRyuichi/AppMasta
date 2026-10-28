import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/test_login.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/design_watermark.dart';
import '../widgets/sync_backgrounds.dart';
import '../widgets/sync_widgets.dart';
import 'helper_screen.dart';
import 'storan_picker_screen.dart';
import 'splash_screen.dart';

abstract final class _LoginPalette {
  static const deep = Color(0xFF6B2848);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFFFF5FA);
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _storage = StorageService();
  final _userFocus = FocusNode();
  final _passFocus = FocusNode();

  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  bool _obscure = true;
  bool _saved = false;
  bool _checkingSession = true;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.85, end: 1.12).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _loadSaved();
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    final auth = context.read<AuthService>();
    await auth.bootstrap();
    if (!mounted) return;
    if (auth.isLoggedIn) {
      Navigator.of(context).pushReplacement(syncPageRoute(const SplashScreen()));
      return;
    }

    if (mounted) setState(() => _checkingSession = false);
  }

  Future<void> _loadSaved() async {
    final creds = await _storage.getSavedCreds();
    if (creds != null && mounted) {
      _userCtrl.text = creds.username;
      _passCtrl.text = creds.password;
      setState(() => _saved = true);
    }
  }

  Future<void> _toggleSave() async {
    if (_saved) {
      await _storage.clearSavedCreds();
      setState(() => _saved = false);
      if (mounted) showSyncSnack(context, 'Data login dihapus');
      return;
    }
    if (_userCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      showSyncSnack(context, 'Isi username dan password dulu', error: true);
      return;
    }
    await _storage.saveCreds(_userCtrl.text.trim(), _passCtrl.text);
    setState(() => _saved = true);
    if (mounted) showSyncSnack(context, 'Akun tersimpan', success: true);
  }

  Future<void> _loginTestAccount1() async {
    _userCtrl.text = TestLogin.account1Username;
    _passCtrl.text = TestLogin.account1Password;
    await _login();
  }

  bool _isDeviceLockError(ApiException e) {
    if (e.statusCode == 403) return true;
    final msg = e.message.toLowerCase();
    return msg.contains('terkunci') || msg.contains('perangkat lain');
  }

  Future<void> _showDeviceLockDialog(String message) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _LoginPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.35)),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.12),
              ),
              child: const Icon(Icons.phonelink_lock_rounded, color: AppColors.error, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Akun Terkunci',
                style: AppTypography.menuTitle().copyWith(color: _LoginPalette.deep),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: AppTypography.menuSubtitle().copyWith(
                color: AppColors.dashText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '1 akun hanya bisa login di 1 perangkat. Gunakan akun di HP yang sudah terdaftar, atau hubungi admin untuk reset device lock.',
              style: AppTypography.menuSubtitle().copyWith(
                color: AppColors.dashTextMuted,
                height: 1.45,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dashAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    final auth = context.read<AuthService>();
    try {
      await auth.login(_userCtrl.text, _passCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(syncPageRoute(const SplashScreen()));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (_isDeviceLockError(e)) {
        await _showDeviceLockDialog(e.message);
      } else {
        showSyncSnack(context, e.message, error: true);
      }
    } on TimeoutException {
      if (mounted) showSyncSnack(context, 'Server tidak merespons, coba lagi', error: true);
    } catch (_) {
      if (mounted) showSyncSnack(context, 'Tidak bisa terhubung ke server', error: true);
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        backgroundColor: AppColors.dashBg,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const SakuraMeshBackground(scanLine: true, child: SizedBox.expand()),
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (context, _) => Positioned(
                top: -100,
                right: -60,
                child: Transform.scale(
                  scale: _glowAnim.value,
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.dashAccent.withValues(alpha: 0.28),
                          AppColors.dashAccent2.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (context, _) => Positioned(
                bottom: 40,
                left: -80,
                child: Transform.scale(
                  scale: 2 - _glowAnim.value,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.dashAccentSoft.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: _checkingSession
                  ? const Center(child: _LoginBootLoader())
                  : Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            children: [
                              FadeSlideIn(
                                child: _LoginUnifiedCard(
                            saved: _saved,
                            onToggleSave: _toggleSave,
                            usernameController: _userCtrl,
                            passwordController: _passCtrl,
                            usernameFocus: _userFocus,
                            passwordFocus: _passFocus,
                            obscurePassword: _obscure,
                            onToggleObscure: () => setState(() => _obscure = !_obscure),
                            loading: auth.loading,
                            onLogin: _login,
                            onCreateAccount: () => Navigator.push(context, syncPageRoute(const StoranPickerScreen())),
                            onRecoverAccount: () => Navigator.push(context, syncPageRoute(const HelperScreen())),
                          ),
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 12),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 140),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: auth.loading ? null : _loginTestAccount1,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                    border: Border.all(color: AppColors.neoBlack, width: 3),
                                    color: AppColors.dashAccent.withValues(alpha: 0.06),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 16, color: AppColors.dashAccent.withValues(alpha: 0.9)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'TES MASUK · ${TestLogin.account1Username} / ${TestLogin.account1Password}',
                                        style: AppTypography.welcomeMeta().copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.dashAccent,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 180),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: const [
                              _FeaturePill(icon: Icons.phonelink_ring_rounded, label: 'Remote Device'),
                              _FeaturePill(icon: Icons.sms_outlined, label: 'SMS Panel'),
                              _FeaturePill(icon: Icons.shield_outlined, label: 'Secure Login'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 240),
                          child: Column(
                            children: [
                              Text(
                                'VOID SPY · 2026 · KAIRO',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.dashTextMuted,
                                      letterSpacing: 2.2,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              const DesignWatermarkInline(opacity: 0.5),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginUnifiedCard extends StatelessWidget {
  const _LoginUnifiedCard({
    required this.saved,
    required this.onToggleSave,
    required this.usernameController,
    required this.passwordController,
    required this.usernameFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.loading,
    required this.onLogin,
    required this.onCreateAccount,
    required this.onRecoverAccount,
  });

  final bool saved;
  final VoidCallback onToggleSave;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final FocusNode usernameFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool loading;
  final VoidCallback onLogin;
  final VoidCallback onCreateAccount;
  final VoidCallback onRecoverAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.neoBlack, width: 3),
        boxShadow: NeoShadow.hard(dx: 6, dy: 6),
        color: AppColors.dashSurface,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const _LoginHeroBanner(),
          Container(
            decoration: BoxDecoration(
              color: AppColors.dashSurface,
              border: const Border(top: BorderSide(color: AppColors.neoBlack, width: 3)),
            ),
            child: Stack(
              children: [
                Positioned(
                  bottom: -50,
                  left: -30,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [AppColors.dashAccent.withValues(alpha: 0.1), Colors.transparent]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Masuk ke Akun',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.4,
                                        color: _LoginPalette.deep,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'AKSES PANEL VOID',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 2.4,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.dashTextMuted,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  width: 28,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(99),
                                    gradient: LinearGradient(colors: [AppColors.dashAccent, AppColors.dashAccent.withValues(alpha: 0)]),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _SaveAccountBadge(saved: saved, onTap: onToggleSave),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _LoginField(
                        label: 'USERNAME',
                        controller: usernameController,
                        focusNode: usernameFocus,
                        icon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => passwordFocus.requestFocus(),
                      ),
                      const SizedBox(height: 14),
                      _LoginField(
                        label: 'PASSWORD',
                        controller: passwordController,
                        focusNode: passwordFocus,
                        icon: Icons.lock_outline_rounded,
                        obscureText: obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => onLogin(),
                        suffix: IconButton(
                          onPressed: onToggleObscure,
                          icon: Icon(
                            obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppColors.dashTextMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SyncPrimaryButton(
                        label: 'MASUK',
                        icon: Icons.login_rounded,
                        loading: loading,
                        variant: ButtonVariant.light,
                        onPressed: onLogin,
                      ),
                      const SizedBox(height: 18),
                      const _OrDivider(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _SecondaryActionButton(
                              label: 'Buat Akun',
                              icon: Icons.shopping_bag_outlined,
                              onTap: onCreateAccount,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SecondaryActionButton(
                              label: 'Pulihkan',
                              icon: Icons.build_outlined,
                              onTap: onRecoverAccount,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginHeroBanner extends StatelessWidget {
  const _LoginHeroBanner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Banner Welcome to VOID SPY (gambar sudah ada teksnya)
          Image.asset(
            'assets/images/welcome_skyline.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Image.asset('assets/images/sync.jpg', fit: BoxFit.cover),
          ),
          // Gradient tipis di bawah biar menyatu ke form, tanpa nutup teks di gambar
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  _LoginPalette.deep.withValues(alpha: 0.35),
                  _LoginPalette.deep.withValues(alpha: 0.55),
                ],
                stops: const [0.0, 0.55, 0.85, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.55),
                    AppColors.dashAccentSoft,
                    Colors.white.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 22,
            right: 22,
            bottom: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'THIS IS MY ERA',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 3.2,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9),
                          shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: Colors.white.withValues(alpha: 0.18),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success,
                          boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.7), blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'ONLINE',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.4, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.icon,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final dynamic icon;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: AppColors.dashText,
          ),
        ),
        const SizedBox(height: 7),
        ListenableBuilder(
          listenable: focusNode,
          builder: (context, _) {
            final focused = focusNode.hasFocus;
            return AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: focused ? AppColors.dashAccent : AppColors.neoBlack,
                  width: focused ? 3 : 2.5,
                ),
                color: AppColors.dashSurface,
                boxShadow: focused ? NeoShadow.hard(dx: 3, dy: 3) : NeoShadow.hard(dx: 2, dy: 2),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscureText,
                textInputAction: textInputAction,
                onSubmitted: onSubmitted,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: _LoginPalette.deep),
                decoration: InputDecoration(
                  hintText: label == 'USERNAME' ? 'Masukkan username' : 'Masukkan password',
                  hintStyle: TextStyle(color: AppColors.dashTextMuted.withValues(alpha: 0.65), fontSize: 13, fontWeight: FontWeight.w500),
                  prefixIcon: _DynamicIcon(icon, size: 18, color: focused ? AppColors.dashAccent : AppColors.dashTextMuted),
                  suffixIcon: suffix,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 15),
                  filled: false,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SaveAccountBadge extends StatelessWidget {
  const _SaveAccountBadge({required this.saved, required this.onTap});

  final bool saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: AppMotion.fast,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: saved ? AppColors.success.withValues(alpha: 0.12) : AppColors.dashAccent.withValues(alpha: 0.08),
              border: Border.all(color: saved ? AppColors.success.withValues(alpha: 0.45) : AppColors.dashAccent.withValues(alpha: 0.28)),
              boxShadow: saved
                  ? [BoxShadow(color: AppColors.success.withValues(alpha: 0.15), blurRadius: 12)]
                  : [BoxShadow(color: AppColors.dashAccent.withValues(alpha: 0.1), blurRadius: 10)],
            ),
            child: Icon(
              saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              size: 20,
              color: saved ? AppColors.success : AppColors.dashAccent,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            saved ? 'TERSIMPAN' : 'SIMPAN',
            style: TextStyle(fontSize: 7, letterSpacing: 1.4, fontWeight: FontWeight.w700, color: AppColors.dashTextMuted),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.dashAccent.withValues(alpha: 0.15))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'ATAU',
            style: TextStyle(fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w700, color: AppColors.dashTextMuted),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.dashAccent.withValues(alpha: 0.15))),
      ],
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final dynamic icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Ink(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            color: AppColors.dashSurface,
            border: Border.all(color: AppColors.neoBlack, width: 2.5),
            boxShadow: NeoShadow.hard(dx: 3, dy: 3),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DynamicIcon(icon, size: 16, color: AppColors.dashText),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.3, color: AppColors.dashText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginBootLoader extends StatelessWidget {
  const _LoginBootLoader();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.dashAccent),
        ),
        const SizedBox(height: 18),
        Text(
          'VOID SPY',
          style: TextStyle(
            fontFamily: 'Genetic',
            fontSize: 30,
            letterSpacing: 4,
            color: _LoginPalette.deep,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Memuat sesi...',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2, color: AppColors.dashTextMuted),
        ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final dynamic icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: Colors.white.withValues(alpha: 0.82),
        border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: AppColors.dashAccent.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DynamicIcon(icon, size: 13, color: AppColors.dashAccent),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.dashText)),
        ],
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
