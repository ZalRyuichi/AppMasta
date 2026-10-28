import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/api_config.dart';
import '../core/role_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/sync_backgrounds.dart';
import '../widgets/sync_widgets.dart';

class SellerCreateScreen extends StatefulWidget {
  const SellerCreateScreen({super.key});

  @override
  State<SellerCreateScreen> createState() => _SellerCreateScreenState();
}

class _SellerCreateScreenState extends State<SellerCreateScreen> {
  final _api = ApiClient();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  int _step = 0;
  bool _loading = false;
  bool _booting = true;
  bool _obscurePass = true;

  String _myRole = 'member';
  List<String> _creatableRoles = [];
  String _selectedRole = 'member';
  String _duration = 'permanent';

  Map<String, dynamic>? _paymentInfo;
  bool _qrDownloading = false;
  File? _proofBuyer;
  File? _proofFee;

  String? _storanId;
  String _status = 'idle';
  String? _createdUid;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final token = context.read<AuthService>().token;
    _myRole = context.read<AuthService>().user?.role ?? 'member';
    final roles = RoleConfig.sellerCanCreate[_myRole] ?? [];
    if (roles.isNotEmpty) {
      _creatableRoles = roles;
      _selectedRole = roles.first;
      final trials = RoleConfig.trialOptions(_myRole, _selectedRole);
      _duration = trials.first;
    }
    try {
      _paymentInfo = await _api.getSellerStoranPaymentInfo();
      if (token != null) {
        final data = await _api.getSellerCreatableRoles(token: token);
        final fromApi = (data['roles'] as List?)?.map((e) => (e as Map)['role']?.toString() ?? '').where((e) => e.isNotEmpty).toList();
        if (fromApi != null && fromApi.isNotEmpty) {
          _creatableRoles = fromApi;
          if (!_creatableRoles.contains(_selectedRole)) _selectedRole = _creatableRoles.first;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _booting = false);
  }

  bool _validateForm() {
    if (_usernameCtrl.text.trim().length < 3) {
      showSyncSnack(context, 'Username minimal 3 karakter', error: true);
      return false;
    }
    if (_passwordCtrl.text.length < 6) {
      showSyncSnack(context, 'Password minimal 6 karakter', error: true);
      return false;
    }
    return true;
  }

  Future<File?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: ElegantCard.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pilih Sumber Foto', style: AppTypography.menuTitle()),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.dashAccent),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.dashAccent),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return null;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 2400);
    if (picked == null) return null;
    final file = File(picked.path);
    if (!await file.exists()) return null;
    return file;
  }

  bool get _paymentConfigured => _paymentInfo?['configured'] == true;

  Future<void> _downloadQr(String url) async {
    if (url.isEmpty) return;
    setState(() => _qrDownloading = true);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Gagal unduh QR');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/qr_storan_fee.png');
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'QR Code Storan Fee');
      if (mounted) showSyncSnack(context, 'QR siap disimpan / dibagikan', success: true);
    } catch (e) {
      if (mounted) showSyncSnack(context, 'Gagal unduh QR: $e', error: true);
    } finally {
      if (mounted) setState(() => _qrDownloading = false);
    }
  }

  void _copyNumber(String label, String number) {
    Clipboard.setData(ClipboardData(text: number));
    showSyncSnack(context, 'Nomor $label disalin', success: true);
  }

  void _nextFromForm() {
    if (!_validateForm()) return;
    if (!_paymentConfigured) {
      showSyncSnack(context, 'Rekening pembayaran belum diatur di server', error: true);
      return;
    }
    setState(() => _step = 1);
  }

  Future<void> _submit() async {
    if (_proofBuyer == null || _proofFee == null) {
      showSyncSnack(context, 'Upload 2 bukti: trx buyer & storan fee', error: true);
      return;
    }
    if (!ApiConfig.isReady || ApiConfig.baseUrl.isEmpty) {
      showSyncSnack(context, 'Server belum siap', error: true);
      return;
    }

    final token = context.read<AuthService>().token;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      final data = await _api.submitSellerStoran(
        token: token,
        role: _selectedRole,
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        trialDuration: _duration,
        proofBuyer: _proofBuyer!,
        proofFee: _proofFee!,
      );
      final id = data['storan_id']?.toString();
      if (id == null) throw ApiException('ID storan tidak diterima');

      setState(() {
        _storanId = id;
        _step = 3;
        _status = 'pending_review';
      });
      _pollStoran(id);
      if (mounted) showSyncSnack(context, '2 bukti terkirim. Menunggu ACC Owner.', success: true);
    } on ApiException catch (e) {
      if (mounted) showSyncSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSyncSnack(context, 'Gagal kirim: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pollStoran(String id) {
    _pollTimer?.cancel();
    final token = context.read<AuthService>().token;
    if (token == null) return;

    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      try {
        final data = await _api.getJson('/api/seller-storan/status/$id', token: token);
        final status = data['status']?.toString() ?? '';
        if (status == 'approved') {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() {
              _status = 'approved';
              _createdUid = data['uid']?.toString();
            });
            _showSuccessDialog(
              data['username']?.toString() ?? _usernameCtrl.text,
              _passwordCtrl.text,
              _createdUid ?? '',
            );
          }
        } else if (status == 'rejected') {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() {
              _status = 'rejected';
              _step = 2;
            });
            showSyncSnack(context, data['reject_reason']?.toString() ?? 'Ditolak Owner', error: true);
          }
        }
      } catch (_) {}
    });
  }

  void _showSuccessDialog(String user, String pass, String uid) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFFCFE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Akun Aktif', style: AppTypography.menuTitle()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _credRow('Username', user),
            _credRow('Password', pass),
            _credRow('UID', uid),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  Widget _credRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: AppTypography.statLabel())),
          Expanded(child: SelectableText(value, style: AppTypography.menuTitle().copyWith(fontSize: 13))),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              showSyncSnack(context, '$label disalin', success: true);
            },
          ),
        ],
      ),
    );
  }

  int get _feeAmount => (_paymentInfo?['fee'] as num?)?.toInt() ?? 5000;

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return Theme(
        data: AppTheme.light(),
        child: const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.dashAccent))),
      );
    }

    if (_creatableRoles.isEmpty) {
      return Theme(
        data: AppTheme.light(),
        child: Scaffold(
          appBar: AppBar(title: Text('BUAT AKUN', style: AppTypography.brand(size: 20))),
          body: SakuraMeshBackground(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Role kamu tidak bisa membuat akun buyer.', style: AppTypography.menuSubtitle(), textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      );
    }

    final methods = (_paymentInfo?['methods'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final waiting = _status == 'pending_review';

    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('BUAT AKUN', style: AppTypography.brand(size: 20)),
          leading: _step > 0 && !waiting
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => setState(() => _step -= 1),
                )
              : null,
        ),
        body: SakuraMeshBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _StepBar(step: _step, waiting: waiting),
              const SizedBox(height: 16),
              if (_step == 0 && !waiting) _buildFormStep(),
              if (_step == 1 && !waiting) _buildPaymentStep(methods),
              if (_step == 2 && !waiting) _buildProofStep(),
              if (waiting || _step == 3) _buildWaitingStep(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormStep() {
    final trials = RoleConfig.trialOptions(_myRole, _selectedRole);
    return Column(
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Data Akun Buyer', style: AppTypography.menuTitle()),
              const SizedBox(height: 4),
              Text('Role kamu: ${RoleConfig.roleLabels[_myRole] ?? _myRole}', style: AppTypography.menuSubtitle()),
              const SizedBox(height: 16),
              TextField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePass,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Barang (Role)', style: AppTypography.statLabel()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _creatableRoles.map((r) {
                  final selected = _selectedRole == r;
                  return ChoiceChip(
                    label: Text(RoleConfig.roleLabels[r] ?? r),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        _selectedRole = r;
                        final t = RoleConfig.trialOptions(_myRole, r);
                        _duration = t.first;
                      });
                    },
                  );
                }).toList(),
              ),
              if (trials.length > 1) ...[
                const SizedBox(height: 16),
                Text('Durasi', style: AppTypography.statLabel()),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: trials.map((d) {
                    return ChoiceChip(
                      label: Text(RoleConfig.trialLabel(d)),
                      selected: _duration == d,
                      onSelected: (_) => setState(() => _duration = d),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        if (!_paymentConfigured) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.orange.withValues(alpha: 0.08),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
            ),
            child: Text(
              'Rekening storan fee belum diatur di server. Hubungi developer dulu.',
              style: AppTypography.menuSubtitle().copyWith(color: Colors.orange.shade800),
            ),
          ),
        ],
        const SizedBox(height: 18),
        SyncPrimaryButton(
          label: 'LANJUT BAYAR FEE',
          icon: Icons.arrow_forward_rounded,
          variant: ButtonVariant.light,
          onPressed: _paymentConfigured ? _nextFromForm : null,
        ),
      ],
    );
  }

  Widget _buildPaymentStep(List<Map<String, dynamic>> methods) {
    if (!_paymentConfigured || methods.isEmpty) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rekening Belum Diatur', style: AppTypography.menuTitle()),
            const SizedBox(height: 8),
            Text(
              'Nomor DANA/GoPay/QRIS storan fee belum dikonfigurasi di server. Hubungi developer/owner.',
              style: AppTypography.menuSubtitle(),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _card(
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Storan Fee Seller', style: AppTypography.brand(size: 22)),
              const SizedBox(height: 6),
              Text('Bayar Rp ${_feeAmount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')} sebelum kirim bukti', style: AppTypography.menuSubtitle()),
              const SizedBox(height: 14),
              ...methods.map((m) {
                final label = m['label']?.toString() ?? '-';
                final number = m['number']?.toString() ?? '-';
                final name = m['name']?.toString() ?? '';
                final note = m['note']?.toString();
                final isQr = label.toUpperCase() == 'QR' || number.startsWith('http');
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: AppColors.dashAccent.withValues(alpha: 0.05),
                    border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTypography.menuTitle()),
                      const SizedBox(height: 8),
                      if (isQr) ...[
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              number,
                              width: 180,
                              height: 180,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Text('Gagal memuat QR', style: AppTypography.menuSubtitle()),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: _qrDownloading ? null : () => _downloadQr(number),
                            icon: _qrDownloading
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.download_rounded, size: 18),
                            label: Text(_qrDownloading ? 'Mengunduh...' : 'Simpan / Bagikan QR'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.dashAccent,
                              side: BorderSide(color: AppColors.dashAccent.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ),
                        if (name.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Center(child: Text('A/N $name', style: AppTypography.menuSubtitle())),
                        ],
                      ] else
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SelectableText(
                                    number,
                                    style: AppTypography.menuTitle().copyWith(fontSize: 16, color: AppColors.dashAccent),
                                  ),
                                  if (name.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text('A/N $name', style: AppTypography.menuSubtitle()),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.copy_rounded, size: 18, color: AppColors.dashAccent.withValues(alpha: 0.75)),
                              tooltip: 'Salin nomor',
                              onPressed: () => _copyNumber(label, number),
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            ),
                          ],
                        ),
                      if (note != null) ...[
                        const SizedBox(height: 4),
                        Text(note, style: AppTypography.welcomeMeta()),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SyncPrimaryButton(label: 'SUDAH TF — UPLOAD BUKTI', icon: Icons.upload_rounded, variant: ButtonVariant.light, onPressed: () => setState(() => _step = 2)),
      ],
    );
  }

  Widget _buildProofStep() {
    return Column(
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upload 2 Bukti', style: AppTypography.menuTitle()),
              const SizedBox(height: 6),
              Text('1) Bukti trx seller dapet buyer\n2) Bukti storan fee Rp 5.000', style: AppTypography.menuSubtitle()),
              const SizedBox(height: 16),
              _proofZone(
                title: 'Bukti TRX Buyer',
                file: _proofBuyer,
                onPick: () async {
                  final f = await _pickImage();
                  if (f != null) setState(() => _proofBuyer = f);
                },
              ),
              const SizedBox(height: 12),
              _proofZone(
                title: 'Bukti Storan Fee',
                file: _proofFee,
                onPick: () async {
                  final f = await _pickImage();
                  if (f != null) setState(() => _proofFee = f);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        SyncPrimaryButton(
          label: 'KIRIM 2 BUKTI',
          loading: _loading,
          icon: Icons.send_rounded,
          variant: ButtonVariant.light,
          onPressed: _submit,
        ),
      ],
    );
  }

  Widget _buildWaitingStep() {
    return _card(
      accent: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Menunggu ACC Owner', style: AppTypography.menuTitle()),
          const SizedBox(height: 8),
          Text('2 bukti sudah dikirim ke Telegram. Akun dibuat otomatis setelah Owner ACC.', style: AppTypography.menuSubtitle()),
          if (_storanId != null) ...[
            const SizedBox(height: 12),
            Text('ID: $_storanId', style: AppTypography.techId()),
          ],
        ],
      ),
    );
  }

  Widget _proofZone({required String title, required File? file, required VoidCallback onPick}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.dashAccent.withValues(alpha: file != null ? 0.22 : 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.menuTitle().copyWith(fontSize: 14)),
              const SizedBox(height: 8),
              if (file != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(file, height: 140, width: double.infinity, fit: BoxFit.cover),
                )
              else
                Row(
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: AppColors.dashAccent.withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Text('Ketuk untuk pilih foto', style: AppTypography.menuSubtitle()),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child, bool accent = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFFFFCFE),
        border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.11)),
      ),
      padding: EdgeInsets.fromLTRB(accent ? 22 : 18, 18, 18, 18),
      child: child,
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.waiting});

  final int step;
  final bool waiting;

  @override
  Widget build(BuildContext context) {
    const labels = ['Data', 'Bayar', 'Bukti', 'ACC'];
    final active = waiting ? 3 : step;

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= active ? AppColors.dashAccent : AppColors.dashAccent.withValues(alpha: 0.08),
                  ),
                  child: Center(
                    child: i < active
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: i == active ? Colors.white : AppColors.dashAccent)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(labels[i], style: AppTypography.welcomeMeta().copyWith(fontWeight: i == active ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
          ),
          if (i < labels.length - 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(width: 12, height: 1, color: AppColors.dashAccent.withValues(alpha: i < active ? 0.3 : 0.1)),
            ),
        ],
      ],
    );
  }
}