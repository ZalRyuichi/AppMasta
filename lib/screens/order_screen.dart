import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/api_config.dart';
import '../core/role_config.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/sync_backgrounds.dart';
import '../widgets/sync_widgets.dart';

class _PersonalPayment {
  final String qrImageUrl;
  final String qrAccountName;
  final String danaNumber;
  final String danaAccountName;
  final String gopayNumber;
  final String gopayAccountName;
  final bool configured;

  const _PersonalPayment({
    this.qrImageUrl       = '',
    this.qrAccountName    = '',
    this.danaNumber       = '',
    this.danaAccountName  = '',
    this.gopayNumber      = '',
    this.gopayAccountName = '',
    this.configured       = false,
  });

  factory _PersonalPayment.fromJson(Map<String, dynamic> json) {
    final pp = json['personalPayment'] as Map<String, dynamic>? ?? {};
    return _PersonalPayment(
      qrImageUrl:       pp['qrImageUrl']       as String? ?? '',
      qrAccountName:    pp['qrAccountName']    as String? ?? '',
      danaNumber:       pp['danaNumber']       as String? ?? '',
      danaAccountName:  pp['danaAccountName']  as String? ?? '',
      gopayNumber:      pp['gopayNumber']      as String? ?? '',
      gopayAccountName: pp['gopayAccountName'] as String? ?? '',
      configured:       pp['configured']       as bool?   ?? false,
    );
  }
}

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, this.fixedRole});
  final String? fixedRole;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _api          = ApiClient();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  late String _selectedRole;
  bool   _obscurePass     = true;
  bool   _loading         = false;
  bool   _qrDownloading   = false;
  bool   _paymentLoading  = true;

  File?  _proofBuyerFile;

  File?  _proofFeeFile;

  int    _step            = 1;
  String _depositStatus   = 'idle';
  String? _storanId;
  String? _createdUid;
  Timer?  _pollTimer;

  _PersonalPayment _payment = const _PersonalPayment();

  bool get _roleLocked => widget.fixedRole != null;

  String get _screenTitle {
    final label = RoleConfig.roleLabels[_selectedRole] ?? _selectedRole;
    return 'Storan $label';
  }

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.fixedRole ?? 'member';
    _loadPaymentInfo();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPaymentInfo() async {
    setState(() => _paymentLoading = true);
    try {
      final data = await _api.getJson('/api/deposit/payment-info');
      if (mounted) setState(() { _payment = _PersonalPayment.fromJson(data); _paymentLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _paymentLoading = false);
    }
  }

  bool _validateStep1() {
    if (_usernameCtrl.text.trim().length < 3) {
      showSyncSnack(context, 'Username minimal 3 karakter', error: true); return false;
    }
    if (_passwordCtrl.text.length < 6) {
      showSyncSnack(context, 'Password minimal 6 karakter', error: true); return false;
    }
    if (_proofBuyerFile == null) {
      showSyncSnack(context, 'Upload foto bukti TF buyer dulu', error: true); return false;
    }
    return true;
  }

  void _goToStep2() {
    if (!_validateStep1()) return;
    setState(() => _step = 2);
  }

  void _backToStep1() => setState(() { _step = 1; _depositStatus = 'idle'; });

  Future<File?> _pickPhoto(String label) async {
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
              Text('Pilih Sumber — $label', style: AppTypography.menuTitle()),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.dashAccent),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.dashAccent),
                title: const Text('Galeri / Folder'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return null;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 2400);
    if (picked == null) return null;
    final file = File(picked.path);
    if (!await file.exists()) {
      if (mounted) showSyncSnack(context, 'File tidak ditemukan', error: true);
      return null;
    }
    return file;
  }

  Future<void> _downloadQr() async {
    if (_payment.qrImageUrl.isEmpty) return;
    setState(() => _qrDownloading = true);
    try {
      final response = await http.get(Uri.parse(_payment.qrImageUrl));
      if (response.statusCode != 200) throw Exception('Gagal unduh QR');
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/qr_storan.png');
      await file.writeAsBytes(response.bodyBytes);
      await Share.shareXFiles([XFile(file.path)], text: 'QR Code Storan Fee');
      if (mounted) showSyncSnack(context, 'QR siap dibagikan', success: true);
    } catch (e) {
      if (mounted) showSyncSnack(context, 'Gagal: $e', error: true);
    } finally {
      if (mounted) setState(() => _qrDownloading = false);
    }
  }

  Future<void> _submitAll() async {
    if (_proofFeeFile == null) {
      showSyncSnack(context, 'Upload foto bukti storan fee dulu', error: true);
      return;
    }
    if (!await _proofFeeFile!.exists()) {
      showSyncSnack(context, 'File foto tidak ditemukan. Pilih ulang.', error: true);
      return;
    }
    if (!ApiConfig.isReady || ApiConfig.baseUrl.isEmpty) {
      showSyncSnack(context, 'Server belum siap. Cek koneksi.', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final data = await _api.submitDepositDual(
        role:        _selectedRole,
        username:    _usernameCtrl.text.trim(),
        password:    _passwordCtrl.text,
        proofBuyer:  _proofBuyerFile!,
        proofFee:    _proofFeeFile!,
      );

      final storanId = data['storan_id']?.toString() ?? data['deposit_id']?.toString();
      if (storanId == null) throw ApiException('ID tidak diterima dari server');

      setState(() {
        _storanId      = storanId;
        _depositStatus = 'pending_review';
      });
      _pollStoran(storanId);
      if (mounted) showSyncSnack(context, '2 foto terkirim. Menunggu ACC admin.', success: true);
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
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) async {
      try {
        final data   = await _api.getJson('/api/deposit/status/$id');
        final status = data['status']?.toString() ?? '';
        if (status == 'approved') {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() { _depositStatus = 'approved'; _createdUid = data['uid']?.toString(); });
            _showSuccessDialog(
              data['username']?.toString() ?? _usernameCtrl.text,
              _passwordCtrl.text,
              _createdUid ?? '',
            );
          }
        } else if (status == 'rejected') {
          _pollTimer?.cancel();
          if (mounted) {
            setState(() { _depositStatus = 'rejected'; _storanId = null; });
            showSyncSnack(context, data['reject_reason']?.toString() ?? 'Ditolak admin', error: true);
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.dashAccent.withValues(alpha: 0.12)),
        ),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Akun Aktif!', style: AppTypography.menuTitle())),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Simpan info berikut dengan aman.', style: AppTypography.menuSubtitle()),
            const SizedBox(height: 14),
            _credRow('Username', user),
            _credRow('Password', pass),
            if (uid.isNotEmpty) _credRow('UID', uid),
          ],
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dashAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.dashAccent.withValues(alpha: 0.04),
          border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            SizedBox(width: 72, child: Text(label, style: AppTypography.statLabel())),
            Expanded(child: SelectableText(value, style: AppTypography.menuTitle().copyWith(fontSize: 13))),
            IconButton(
              icon: Icon(Icons.copy_rounded, size: 16, color: AppColors.dashAccent.withValues(alpha: 0.7)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                showSyncSnack(context, '$label disalin', success: true);
              },
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            ),
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
        appBar: AppBar(
          title: Text(_screenTitle.toUpperCase(), style: AppTypography.brand(size: 20)),
          leading: _step == 2
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  onPressed: _depositStatus == 'pending_review' ? null : _backToStep1,
                )
              : null,
        ),
        body: SakuraMeshBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              FadeSlideIn(
                child: _ElegantCard(
                  child: _StepIndicator(
                    currentStep: _step,
                    status: _depositStatus,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              if (_step == 1) ..._buildStep1(),
              if (_step == 2) ..._buildStep2(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep1() => [
    FadeSlideIn(
      delay: const Duration(milliseconds: 20),
      child: _ElegantCard(
        accent: true,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dashAccent.withValues(alpha: 0.08),
                border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.18)),
              ),
              child: const Icon(Icons.person_outline_rounded, color: AppColors.dashAccent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data Akun & Bukti TF', style: AppTypography.menuTitle()),
                  Text('Isi data lalu upload foto bukti transfer ke seller', style: AppTypography.menuSubtitle()),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 12),

    FadeSlideIn(
      delay: const Duration(milliseconds: 60),
      child: _ElegantCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.alternate_email_rounded),
              ),
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
                  icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (_roleLocked) ...[
              Text('Paket', style: AppTypography.statLabel()),
              const SizedBox(height: 10),
              _LockedRoleBadge(role: _selectedRole),
            ] else ...[
              Text('Barang', style: AppTypography.statLabel()),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: RoleConfig.productPrices.keys.map((role) {
                  final sel = _selectedRole == role;
                  return _BarangChip(
                    label: RoleConfig.roleLabels[role] ?? role,
                    selected: sel,
                    onTap: () => setState(() => _selectedRole = role),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    ),
    const SizedBox(height: 12),

    FadeSlideIn(
      delay: const Duration(milliseconds: 100),
      child: _ElegantCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(
              icon: Icons.receipt_long_outlined,
              title: 'Bukti TF Buyer → Seller',
              subtitle: 'Screenshot bukti pembayaran dari buyer ke kamu',
            ),
            const SizedBox(height: 14),
            _ProofUploadZone(
              file: _proofBuyerFile,
              onPick: () async {
                final f = await _pickPhoto('Bukti TF Buyer');
                if (f != null) setState(() => _proofBuyerFile = f);
              },
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 18),

    FadeSlideIn(
      delay: const Duration(milliseconds: 140),
      child: SyncPrimaryButton(
        label: 'LANJUT — BAYAR STORAN FEE',
        icon: Icons.arrow_forward_rounded,
        variant: ButtonVariant.light,
        onPressed: _goToStep2,
      ),
    ),
  ];

  List<Widget> _buildStep2() {
    final waiting = _depositStatus == 'pending_review';
    return [
      FadeSlideIn(
        delay: const Duration(milliseconds: 20),
        child: _ElegantCard(
          accent: true,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.dashAccent.withValues(alpha: 0.08),
                  border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.payments_outlined, color: AppColors.dashAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bayar Storan Fee', style: AppTypography.menuTitle()),
                    Text('Transfer fee lalu upload bukti pembayaran', style: AppTypography.menuSubtitle()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      if (!waiting) ...[
        FadeSlideIn(
          delay: const Duration(milliseconds: 40),
          child: _ElegantCard(
            child: _paymentLoading
                ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
                : _PaymentInfoSection(
                    payment: _payment,
                    downloading: _qrDownloading,
                    onDownloadQr: _downloadQr,
                  ),
          ),
        ),
        const SizedBox(height: 12),

        FadeSlideIn(
          delay: const Duration(milliseconds: 80),
          child: _ElegantCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(
                  icon: Icons.photo_camera_outlined,
                  title: 'Bukti Storan Fee',
                  subtitle: 'Screenshot bukti transfer storan fee ke admin',
                ),
                const SizedBox(height: 14),
                _ProofUploadZone(
                  file: _proofFeeFile,
                  onPick: () async {
                    final f = await _pickPhoto('Bukti Storan Fee');
                    if (f != null) setState(() => _proofFeeFile = f);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),

        FadeSlideIn(
          delay: const Duration(milliseconds: 120),
          child: SyncPrimaryButton(
            label: 'KIRIM SEMUA',
            loading: _loading,
            icon: Icons.send_rounded,
            variant: ButtonVariant.light,
            onPressed: _submitAll,
          ),
        ),
      ],

      if (waiting) ...[
        FadeSlideIn(
          delay: const Duration(milliseconds: 40),
          child: _ElegantCard(
            accent: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.dashAccent.withValues(alpha: 0.08),
                    border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.16)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dashAccent.withValues(alpha: 0.85)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Menunggu ACC Admin', style: AppTypography.menuTitle()),
                      const SizedBox(height: 4),
                      Text(
                        '2 foto sudah dikirim ke Telegram admin. Akun dibuat otomatis setelah disetujui.',
                        style: AppTypography.menuSubtitle(),
                      ),
                      if (_storanId != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.dashAccent.withValues(alpha: 0.04),
                            border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.1)),
                          ),
                          child: Text('ID: $_storanId', style: AppTypography.techId()),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],

      if (_depositStatus == 'rejected') ...[
        const SizedBox(height: 12),
        FadeSlideIn(
          child: _ElegantCard(
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: AppColors.error.withValues(alpha: 0.85), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ditolak admin. Kembali dan kirim ulang.',
                    style: AppTypography.menuSubtitle().copyWith(color: AppColors.error),
                  ),
                ),
                TextButton(
                  onPressed: _backToStep1,
                  child: const Text('Kembali'),
                ),
              ],
            ),
          ),
        ),
      ],
    ];
  }
}


class _PaymentInfoSection extends StatelessWidget {
  const _PaymentInfoSection({required this.payment, required this.downloading, required this.onDownloadQr});
  final _PersonalPayment payment;
  final bool downloading;
  final VoidCallback onDownloadQr;

  @override
  Widget build(BuildContext context) {
    final hasQr    = payment.qrImageUrl.isNotEmpty;
    final hasDana  = payment.danaNumber.isNotEmpty;
    final hasGopay = payment.gopayNumber.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(
          icon: Icons.qr_code_2_rounded,
          title: 'Tujuan Transfer Storan Fee',
          subtitle: 'Scan QR atau transfer ke nomor di bawah',
        ),
        const SizedBox(height: 16),

        if (hasQr) ...[
          Center(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.15)),
                color: Colors.white,
                boxShadow: [BoxShadow(color: AppColors.dashAccent.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  payment.qrImageUrl,
                  width: 200, height: 200, fit: BoxFit.contain,
                  loadingBuilder: (_, child, prog) {
                    if (prog == null) return child;
                    return SizedBox(width: 200, height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2, value: prog.expectedTotalBytes != null ? prog.cumulativeBytesLoaded / prog.expectedTotalBytes! : null)));
                  },
                  errorBuilder: (_, __, ___) => SizedBox(width: 200, height: 200, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.broken_image_outlined, size: 40, color: AppColors.dashAccent.withValues(alpha: 0.4)), const SizedBox(height: 8), Text('Gagal memuat QR', style: AppTypography.menuSubtitle())])),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          Center(
            child: OutlinedButton.icon(
              onPressed: downloading ? null : onDownloadQr,
              icon: downloading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(downloading ? 'Mengunduh...' : 'Simpan / Bagikan QR'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dashAccent,
                side: BorderSide(color: AppColors.dashAccent.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          if (payment.qrAccountName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Center(child: Text('a.n. ${payment.qrAccountName}', style: AppTypography.menuSubtitle())),
          ],
          const SizedBox(height: 14),
        ],

        if (hasDana) ...[
          _NumberTile(icon: Icons.account_balance_wallet_outlined, label: 'DANA', number: payment.danaNumber, name: payment.danaAccountName, color: const Color(0xFF118EEA)),
          const SizedBox(height: 10),
        ],

        if (hasGopay) ...[
          _NumberTile(icon: Icons.account_balance_wallet_outlined, label: 'GoPay', number: payment.gopayNumber, name: payment.gopayAccountName, color: const Color(0xFF00AA5B)),
          const SizedBox(height: 4),
        ],

        if (!hasQr && !hasDana && !hasGopay)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.dashAccent.withValues(alpha: 0.04), border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.1))),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppColors.dashAccent.withValues(alpha: 0.6)),
                const SizedBox(width: 10),
                Expanded(child: Text('Info pembayaran belum dikonfigurasi. Hubungi admin.', style: AppTypography.menuSubtitle())),
              ],
            ),
          ),
      ],
    );
  }
}

class _NumberTile extends StatelessWidget {
  const _NumberTile({required this.icon, required this.label, required this.number, required this.name, required this.color});
  final dynamic icon; final String label, number, name; final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: color.withValues(alpha: 0.05), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.1)), child: _DynamicIcon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.5)),
                Text(number, style: AppTypography.menuTitle().copyWith(fontSize: 15, letterSpacing: 0.3)),
                if (name.isNotEmpty) Text('a.n. $name', style: AppTypography.menuSubtitle()),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy_rounded, size: 16, color: color.withValues(alpha: 0.7)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: number));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nomor $label disalin'), duration: const Duration(seconds: 2)));
            },
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep, required this.status});
  final int currentStep;
  final String status;

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('Data + TF',  Icons.receipt_long_outlined),
      ('Storan Fee', Icons.payments_outlined),
      ('ACC',        Icons.verified_outlined),
    ];

    final phase = status == 'approved'
        ? 3
        : status == 'pending_review'
            ? 2
            : currentStep - 1;

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Builder(builder: (_) {
              final step   = steps[i];
              final done   = i < phase;
              final active = i == phase;
              return Column(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? AppColors.dashAccent
                          : active
                              ? AppColors.dashAccent.withValues(alpha: 0.08)
                              : const Color(0xFFFFFCFE),
                      border: Border.all(
                        color: (done || active)
                            ? AppColors.dashAccent.withValues(alpha: 0.4)
                            : AppColors.dashAccent.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Center(
                      child: done
                          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                          : _DynamicIcon(step.$2, size: 16, color: active ? AppColors.dashAccent : AppColors.dashTextMuted),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    step.$1,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: (done || active) ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.3,
                      color: (done || active) ? AppColors.dashAccent : AppColors.dashTextMuted,
                    ),
                  ),
                ],
              );
            }),
          ),
          if (i < steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 18, left: 4, right: 4),
              child: Container(
                width: 20, height: 1,
                color: AppColors.dashAccent.withValues(alpha: i < phase ? 0.32 : 0.1),
              ),
            ),
        ],
      ],
    );
  }
}

class _ElegantCard extends StatelessWidget {
  const _ElegantCard({required this.child, this.padding = const EdgeInsets.all(18), this.accent = false});
  final Widget child; final EdgeInsets padding; final bool accent;
  static const surface = Color(0xFFFFFCFE);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: surface,
        border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.11)),
        boxShadow: [BoxShadow(color: AppColors.dashAccent.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (accent)
              Positioned(
                left: 0, top: 14, bottom: 14,
                child: Container(width: 3, decoration: BoxDecoration(color: AppColors.dashAccent.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(99))),
              ),
            Padding(padding: padding.copyWith(left: accent ? padding.left + 6 : padding.left), child: child),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title, required this.subtitle});
  final dynamic icon; final String title, subtitle;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.dashAccent.withValues(alpha: 0.07), border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.14))),
          child: _DynamicIcon(icon, color: AppColors.dashAccent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTypography.menuTitle()), Text(subtitle, style: AppTypography.menuSubtitle())])),
      ],
    );
  }
}

class _BarangChip extends StatelessWidget {
  const _BarangChip({required this.label, required this.selected, required this.onTap});
  final String label; final bool selected; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            color: selected ? AppColors.dashAccent.withValues(alpha: 0.92) : const Color(0xFFFFFCFE),
            border: Border.all(color: selected ? AppColors.dashAccent.withValues(alpha: 0.5) : AppColors.dashAccent.withValues(alpha: 0.16)),
          ),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.dashText)),
        ),
      ),
    );
  }
}

class _ProofUploadZone extends StatelessWidget {
  const _ProofUploadZone({required this.file, required this.onPick});
  final File? file; final VoidCallback onPick;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick, borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.dashAccent.withValues(alpha: 0.03),
            border: Border.all(color: AppColors.dashAccent.withValues(alpha: file != null ? 0.22 : 0.14)),
          ),
          child: Column(
            children: [
              if (file != null) ...[
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(file!, height: 180, width: double.infinity, fit: BoxFit.cover)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.success.withValues(alpha: 0.9)),
                  const SizedBox(width: 6),
                  Text('Foto siap dikirim', style: AppTypography.welcomeMeta().copyWith(color: AppColors.success)),
                ]),
                const SizedBox(height: 8),
                Text('Ketuk untuk ganti', style: AppTypography.welcomeMeta()),
              ] else ...[
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.dashAccent.withValues(alpha: 0.06), border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.12))),
                  child: Icon(Icons.add_photo_alternate_outlined, color: AppColors.dashAccent.withValues(alpha: 0.75), size: 24),
                ),
                const SizedBox(height: 12),
                Text('Ketuk untuk pilih foto', style: AppTypography.menuTitle().copyWith(fontSize: 14)),
                const SizedBox(height: 4),
                Text('Kamera atau galeri / folder', style: AppTypography.menuSubtitle()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedRoleBadge extends StatelessWidget {
  const _LockedRoleBadge({required this.role});
  final String role;
  @override
  Widget build(BuildContext context) {
    final label = RoleConfig.roleLabels[role] ?? role;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: AppColors.dashAccent.withValues(alpha: 0.06), border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.14))),
      child: Row(
        children: [
          Icon(Icons.verified_outlined, size: 18, color: AppColors.dashAccent.withValues(alpha: 0.85)),
          const SizedBox(width: 10),
          Text('Storan $label', style: AppTypography.menuTitle().copyWith(fontSize: 14)),
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
