import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/sync_backgrounds.dart';
import '../widgets/sync_widgets.dart';

class HelperScreen extends StatefulWidget {
  const HelperScreen({super.key});

  @override
  State<HelperScreen> createState() => _HelperScreenState();
}

class _HelperScreenState extends State<HelperScreen> {
  final _api = ApiClient();
  final _usernameCtrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _qrisData;
  Timer? _pollTimer;
  int _timeLeft = 300;

  @override
  void dispose() {
    _pollTimer?.cancel();
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (_usernameCtrl.text.trim().length < 3) {
      showSyncSnack(context, 'Username minimal 3 karakter', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await _api.postJson('/api/helper/create', body: {
        'username': _usernameCtrl.text.trim(),
      });
      if (data['success'] != true) throw ApiException(data['error']?.toString() ?? 'Gagal');
      setState(() {
        _qrisData = data;
        _timeLeft = (data['expires_in'] as num?)?.toInt() ?? 300;
      });
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
      if (mounted) _showSheet();
    } on ApiException catch (e) {
      if (mounted) showSyncSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _check() async {
    final id = _qrisData?['invoice_id']?.toString();
    if (id == null) return;
    final data = await _api.getJson('/api/helper/status/$id');
    if (data['status'] == 'paid') {
      await _api.postJson('/api/helper/complete', body: {
        'invoice_id': id,
        'username': _usernameCtrl.text.trim(),
      });
      _pollTimer?.cancel();
      if (mounted) {
        Navigator.pop(context);
        showSyncSnack(context, 'Cache berhasil di-reset. Silakan login ulang.', success: true);
      }
    }
  }

  void _showSheet() {
    final amount = (_qrisData?['amount'] as num?)?.toInt() ?? 5000;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bayar Reset', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Rp ${NumberFormat.decimalPattern('id').format(amount)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.accent2)),
            const SizedBox(height: 12),
            Text('Timer: $_timeLeft detik', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 16),
            SyncPrimaryButton(label: 'CEK PEMBAYARAN', onPressed: _check),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        appBar: AppBar(title: Text('PULIHKAN', style: AppTypography.brand(size: 20))),
        body: SakuraMeshBackground(
          child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FadeSlideIn(
              child: SyncCard(
                child: const SectionTitle('Reset Cache Device', subtitle: 'Untuk akun yang terdaftar di perangkat lain'),
              ),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              delay: const Duration(milliseconds: 80),
              child: TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline_rounded)),
              ),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              delay: const Duration(milliseconds: 140),
              child: SyncPrimaryButton(label: 'MULAI RESET', loading: _loading, icon: Icons.build_circle_outlined, onPressed: _start),
            ),
          ],
        ),
        ),
      ),
    );
  }
}