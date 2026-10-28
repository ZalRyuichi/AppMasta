import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';

/// Sender-node management UI integrated with VOID SPY's ApiClient and auth.
/// Backend endpoints: /mySender, /getPairing, /deleteSender.
class WhatsAppSenderScreen extends StatefulWidget {
  const WhatsAppSenderScreen({super.key});

  @override
  State<WhatsAppSenderScreen> createState() => _WhatsAppSenderScreenState();
}

class _WhatsAppSenderScreenState extends State<WhatsAppSenderScreen> {
  final ApiClient _api = ApiClient();
  final TextEditingController _phone = TextEditingController();

  List<dynamic> _senders = [];
  bool _busy = false;
  String? _error;
  String _pairingCode = '';

  // ══════════════════════════════════════════════════════════════
  // 🎨 TEMA HIJAU-PUTIH (konsisten dengan WhatsAppHomeScreen)
  // ══════════════════════════════════════════════════════════════
  static const Color bgMain = Color(0xFFF0FDF4);      // hijau sangat muda
  static const Color bgSurface = Color(0xFFFFFFFF);   // putih
  static const Color bgCard = Color(0xFFFFFFFF);      // putih

  static const Color textMain = Color(0xFF0F172A);    // hitam netral
  static const Color textSub = Color(0xFF64748B);     // slate

  static const Color accentColor = Color(0xFF16A34A); // hijau
  static const Color accentDark = Color(0xFF15803D);  // hijau gelap
  static const Color accentSoft = Color(0xFFDCFCE7);  // hijau muda (bg accent)
  static const Color borderColor = Color(0xFF0F172A); // border tebal

  String? get _token => context.read<AuthService>().token;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSenders());
  }

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: textMain,
            fontFamily: 'ShareTechMono',
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderColor, width: 1.2),
        ),
      ),
    );
  }

  // ============================================================
  // ====================  DATA FETCHING  =======================
  // ============================================================

  Future<void> _loadSenders() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Sesi login tidak ditemukan. Login ulang.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final data = await _api.getJson(
        '/mySender?key=${Uri.encodeQueryComponent(token)}',
        token: token,
      );
      if (!mounted) return;
      if (data['valid'] == true) {
        setState(() => _senders = (data['connections'] as List?) ?? []);
      } else {
        setState(() =>
            _error = (data['message'] ?? 'Gagal memuat sender').toString());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Gagal terhubung ke API: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ============================================================
  // ====================  PAIRING  =============================
  // ============================================================

  Future<void> _addSender(BuildContext dialogContext) async {
    final token = _token;
    final phone = _phone.text.trim().replaceAll(RegExp(r'[^0-9+]'), '');

    if (token == null || token.isEmpty) return _toast('Sesi login tidak ditemukan.');
    if (phone.length < 8) {
      return _toast('Masukkan nomor dengan kode negara, contoh 628xxx.');
    }

    Navigator.pop(dialogContext);
    setState(() {
      _busy = true;
      _pairingCode = '';
    });

    try {
      final data = await _api.getJson(
        '/getPairing?key=${Uri.encodeQueryComponent(token)}'
        '&number=${Uri.encodeQueryComponent(phone)}',
        token: token,
      );

      if (!mounted) return;

      if (data['valid'] == true) {
        setState(() => _pairingCode = (data['pairingCode'] ?? '').toString());

        if (_pairingCode.isNotEmpty) {
          await _showPairingDialog(phone, _pairingCode);
        } else {
          _toast('Server tidak mengirim pairingCode. Periksa format respons API.');
        }
      } else {
        _toast((data['message'] ?? 'Pairing gagal').toString());
      }
    } catch (e) {
      if (mounted) _toast('Pairing gagal: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        _loadSenders();
      }
    }
  }

  Future<void> _showPairingDialog(String phone, String code) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor, width: 1.2),
        ),
        title: Row(
          children: [
            Icon(Icons.link, color: accentColor),
            const SizedBox(width: 8),
            Text(
              'KODE PAIRING',
              style: TextStyle(
                color: textMain,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withOpacity(0.4), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NOMOR',
                    style: TextStyle(
                      color: accentDark,
                      fontSize: 9,
                      fontFamily: 'Orbitron',
                      letterSpacing: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    phone,
                    style: TextStyle(
                      color: textMain,
                      fontFamily: 'ShareTechMono',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                color: bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: const [
                  BoxShadow(color: borderColor, blurRadius: 0, offset: Offset(3, 3)),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'PAIRING CODE',
                    style: TextStyle(
                      color: textSub,
                      fontSize: 10,
                      fontFamily: 'Orbitron',
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    code,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'ShareTechMono',
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Masukkan kode ini di WhatsApp → Perangkat Tertaut → Tautkan dengan nomor telepon.',
              style: TextStyle(
                color: textSub,
                fontSize: 11,
                fontFamily: 'ShareTechMono',
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (ctx.mounted) Navigator.pop(ctx);
              _toast('Kode pairing disalin.');
            },
            child: Text(
              'SALIN',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w800,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'TUTUP',
              style: TextStyle(
                color: textSub,
                fontWeight: FontWeight.w800,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    _phone.clear();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor, width: 1.2),
        ),
        title: Row(
          children: [
            Icon(Icons.add_link, color: accentColor),
            const SizedBox(width: 8),
            Text(
              'TAMBAH SENDER',
              style: TextStyle(
                color: textMain,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Masukkan nomor WhatsApp dengan kode negara (contoh: 628xxxxxxxxxx).',
              style: TextStyle(
                color: textSub,
                fontSize: 11,
                fontFamily: 'ShareTechMono',
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: const TextStyle(color: textMain, fontSize: 15),
              cursorColor: accentColor,
              decoration: InputDecoration(
                hintText: '628xxxxxxxxxx',
                hintStyle: TextStyle(color: textSub.withOpacity(0.5)),
                filled: true,
                fillColor: bgMain,
                prefixIcon: Icon(Icons.phone_android_rounded, color: accentColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: borderColor, width: 1.2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: borderColor, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accentColor, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'BATAL',
              style: TextStyle(
                color: textSub,
                fontWeight: FontWeight.w800,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _busy ? null : () => _addSender(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'GENERATE',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'Orbitron',
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ====================  DELETE  ==============================
  // ============================================================

  Future<void> _deleteSender(String id) async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor, width: 1.2),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: accentColor),
            const SizedBox(width: 8),
            Text(
              'HAPUS SENDER?',
              style: TextStyle(
                color: textMain,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
        content: Text(
          'Sender node "$id" akan dihapus dari server.',
          style: TextStyle(
            color: textSub,
            fontSize: 12,
            fontFamily: 'ShareTechMono',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'BATAL',
              style: TextStyle(
                color: textSub,
                fontWeight: FontWeight.w800,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: Text(
              'HAPUS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
        ],
      ),
    );

    if (yes != true) return;

    setState(() => _busy = true);
    try {
      final data = await _api.deleteJson(
        '/deleteSender?key=${Uri.encodeQueryComponent(token)}'
        '&id=${Uri.encodeQueryComponent(id)}',
        token: token,
      );
      _toast(
        (data['message'] ??
                (data['valid'] == true ? 'Sender dihapus.' : 'Gagal menghapus sender.'))
            .toString(),
      );
      await _loadSenders();
    } catch (e) {
      if (mounted) _toast('Gagal menghapus sender: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ============================================================
  // ====================  BUILD  ===============================
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgMain,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadSenders,
          color: accentColor,
          backgroundColor: bgCard,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
            children: [
              _buildHeader(),
              const SizedBox(height: 14),

              if (_busy)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(
                    color: accentColor,
                    backgroundColor: accentSoft,
                  ),
                ),

              if (_error != null) _buildErrorBox(_error!),

              if (!_busy && _error == null && _senders.isEmpty)
                _buildEmptyState(),

              for (final raw in _senders)
                if (raw is Map) _senderCard(Map<String, dynamic>.from(raw)),
            ],
          ),
        ),
      ),
      floatingActionButton: _busy
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddDialog,
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_link),
              label: Text(
                'NEW NODE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Orbitron',
                  letterSpacing: 1,
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          const BoxShadow(color: borderColor, blurRadius: 0, offset: Offset(3, 3)),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withOpacity(0.4), width: 1),
            ),
            child: Icon(Icons.hub_rounded, color: accentDark, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SENDER MANAGEMENT',
                  style: TextStyle(
                    color: textMain,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    fontFamily: 'Orbitron',
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_senders.length} sender node terdaftar',
                  style: TextStyle(
                    color: textSub,
                    fontSize: 11,
                    fontFamily: 'ShareTechMono',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _busy ? null : _loadSenders,
            icon: Icon(Icons.refresh_rounded, color: accentColor),
            tooltip: 'Refresh',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(color: borderColor, blurRadius: 0, offset: Offset(2, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: accentColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textMain,
                fontSize: 12,
                fontFamily: 'ShareTechMono',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: const [
                BoxShadow(color: borderColor, blurRadius: 0, offset: Offset(2, 2)),
              ],
            ),
            child: Icon(Icons.devices_other, size: 48, color: accentColor),
          ),
          const SizedBox(height: 16),
          Text(
            'BELUM ADA SENDER NODE',
            style: TextStyle(
              color: textMain,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'NEW NODE',
            style: TextStyle(
              color: textSub,
              fontFamily: 'ShareTechMono',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _senderCard(Map<String, dynamic> sender) {
    final id = (sender['id'] ?? sender['sessionName'] ?? '').toString();
    final name = (sender['sessionName'] ?? 'WhatsApp Sender').toString();
    final source = (sender['source'] ?? 'personal').toString();

    // Ambil nomor saja kalau sessionName format "628xxx"
    final displayPhone = name.contains('@') ? name.split('@').first : name;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          const BoxShadow(color: borderColor, blurRadius: 0, offset: Offset(2, 2)),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: accentColor.withOpacity(0.4), width: 1),
            ),
            child: Icon(Icons.phone_android, color: accentDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayPhone,
                  style: TextStyle(
                    color: textMain,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'ShareTechMono',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accentDark, width: 0.8),
                      ),
                      child: Text(
                        source.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Orbitron',
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        id.length > 12 ? '...${id.substring(id.length - 8)}' : id,
                        style: TextStyle(
                          color: textSub,
                          fontSize: 10,
                          fontFamily: 'ShareTechMono',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus sender',
            onPressed: _busy || id.isEmpty ? null : () => _deleteSender(id),
            icon: Icon(Icons.delete_outline, color: accentColor),
          ),
        ],
      ),
    );
  }
}