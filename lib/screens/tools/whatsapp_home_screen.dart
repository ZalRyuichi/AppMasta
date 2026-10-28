import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import 'whatsapp_sender_screen.dart';

/// ASC-inspired WhatsApp HomePage adapted to VOID SPY.
class WhatsAppHomeScreen extends StatefulWidget {
  /// Optional: kirim list bug dari login response agar tidak fetch ulang.
  final List<Map<String, dynamic>>? initialBugs;

  const WhatsAppHomeScreen({super.key, this.initialBugs});

  @override
  State<WhatsAppHomeScreen> createState() => _WhatsAppHomeScreenState();
}

class _WhatsAppHomeScreenState extends State<WhatsAppHomeScreen>
    with TickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  final TextEditingController _target = TextEditingController();

  // --- State Bug ---
  List<Map<String, dynamic>> _listBug = [];
  String _selectedBugId = "";
  String _targetMode = 'number'; // 'number' | 'group'
  String _senderMode = 'private'; // 'private' | 'global'

  // --- State Sender Stats ---
  int _privateCount = 0;
  int _globalCount = 0;

  // --- State UI ---
  bool _loading = false;
  bool _isSending = false;
  String? _error;

  late AnimationController _pulseController;
  FixedExtentScrollController? _wheelController;

  // ══════════════════════════════════════════════════════════════
  // 🎨 TEMA HIJAU-PUTIH (sinkron dengan APK)
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

  // --- Auth ---
  String? get _token => context.read<AuthService>().token;
  String get _role =>
      (context.read<AuthService>().user?.role ?? 'member').toLowerCase();
  bool get _canChooseGlobal => _role == 'owner' || _role == 'developer';

  @override
  void initState() {
    super.initState();

    // Sinkronkan device id ke ApiClient lokal
    StorageService().getOrCreateDeviceId().then((id) {
      _api.setDeviceId(id);
    }).catchError((e) => debugPrint("device id error: $e"));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _listBug = widget.initialBugs ?? [];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_listBug.isEmpty) await _loadBugs();
      await _loadStats();
      _initWheelController();
    });
  }

  @override
  void dispose() {
    _target.dispose();
    _pulseController.dispose();
    _wheelController?.dispose();
    super.dispose();
  }

  // ============================================================
  // ====================  WHEEL INIT  ==========================
  // ============================================================

  void _initWheelController() {
    final bugs = _getFilteredBugs();
    if (bugs.isEmpty) {
      _wheelController?.dispose();
      _wheelController = null;
      _selectedBugId = "";
      if (mounted) setState(() {});
      return;
    }

    _wheelController?.dispose();
    _wheelController = FixedExtentScrollController(initialItem: 0);
    _selectedBugId = bugs[0]['bug_id'];
    if (mounted) setState(() {});
  }

  // ============================================================
  // ====================  DATA FETCHING  =======================
  // ============================================================

  Future<void> _loadBugs() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() => _error = 'Sesi login tidak ditemukan. Login ulang.');
      }
      return;
    }

    final candidates = <String>[
      '/getBugs?key=${Uri.encodeQueryComponent(token)}',
      '/listBug?key=${Uri.encodeQueryComponent(token)}',
      '/api/getBugs?key=${Uri.encodeQueryComponent(token)}',
    ];

    for (final path in candidates) {
      try {
        final data = await _api.getJson(path, token: token);
        if (!mounted) return;

        final rawList = data['bugs'] ?? data['listBug'] ?? data['list'];

        if (data['valid'] == true && rawList is List) {
          setState(() {
            _listBug = List<Map<String, dynamic>>.from(
              rawList.map((e) => Map<String, dynamic>.from(e as Map)),
            );
          });
          _initWheelController();
          return;
        }
        if (data['valid'] == false) {
          setState(() => _error =
              (data['message'] ?? 'Gagal memuat payload.').toString());
          return;
        }
      } on ApiException catch (e) {
        if (e.statusCode == 404) continue;
        debugPrint("Error fetching bugs ($path): ${e.message}");
      } catch (e) {
        debugPrint("Error fetching bugs ($path): $e");
      }
    }
  }

  Future<void> _loadStats() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() => _error = 'Sesi login tidak ditemukan. Login ulang.');
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final candidates = <String>[
      '/getSenderStats?key=${Uri.encodeQueryComponent(token)}',
      '/senderStats?key=${Uri.encodeQueryComponent(token)}',
      '/api/getSenderStats?key=${Uri.encodeQueryComponent(token)}',
    ];

    try {
      Map<String, dynamic>? ok;
      for (final path in candidates) {
        try {
          final data = await _api.getJson(path, token: token);
          if (data['valid'] == true) {
            ok = data;
            break;
          }
        } on ApiException catch (e) {
          if (e.statusCode == 404) continue;
          rethrow;
        }
      }

      if (!mounted) return;

      if (ok != null) {
        setState(() {
          _privateCount = int.tryParse('${ok!['private'] ?? 0}') ?? 0;
          _globalCount = int.tryParse('${ok!['global'] ?? 0}') ?? 0;
        });
      } else {
        setState(() => _error = 'Statistik sender tidak tersedia.');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat statistik: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ============================================================
  // ====================  FILTER & VALIDASI  ===================
  // ============================================================

  List<Map<String, dynamic>> _getFilteredBugs() {
    if (_targetMode == "group") {
      return _listBug
          .where((b) => (b['bug_id'] ?? '').toString().contains('_group'))
          .toList();
    }
    return _listBug
        .where((b) => !(b['bug_id'] ?? '').toString().contains('_group'))
        .toList();
  }

  String? _formatPhoneNumber(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');
    if (!cleaned.startsWith('+') || cleaned.length < 8) return null;
    return cleaned;
  }

  bool _isValidGroupLink(String input) {
    return input.contains('chat.whatsapp.com') && input.contains('https://');
  }

  String _cleanBugName(String bugName) {
    return bugName
        .replaceAll(RegExp(r'^bug_|_group$'), '')
        .replaceAll('_', ' ')
        .toUpperCase();
  }

  // ============================================================
  // ====================  KIRIM BUG  ===========================
  // ============================================================

  Future<void> _sendBug() async {
    final rawInput = _target.text.trim();
    final key = _token ?? '';

    if (key.isEmpty) {
      _showAlert("❌ Key Invalid", "Sesi tidak ditemukan. Silakan login ulang.");
      return;
    }

    if (_targetMode == "number") {
      final target = _formatPhoneNumber(rawInput);
      if (target == null) {
        _showAlert("Invalid Number",
            "Gunakan nomor internasional (misal: +62, 1, 44), bukan 08xxx.");
        return;
      }
    } else {
      if (!_isValidGroupLink(rawInput)) {
        _showAlert("Invalid Link",
            "Masukkan link group WA yang valid (contoh: https://chat.whatsapp.com/...).");
        return;
      }
    }

    final currentBugs = _getFilteredBugs();
    if (currentBugs.isEmpty) {
      _showAlert("Error", "Tidak ada bug tersedia untuk mode ini.");
      return;
    }
    if (!currentBugs.any((b) => b['bug_id'] == _selectedBugId)) {
      setState(() => _selectedBugId = currentBugs[0]['bug_id']);
    }

    setState(() => _isSending = true);

    final effectiveSenderMode = _canChooseGlobal ? _senderMode : 'private';

    try {
      final path =
          '/sendBug'
          '?key=${Uri.encodeQueryComponent(key)}'
          '&target=${Uri.encodeQueryComponent(rawInput)}'
          '&bug=${Uri.encodeQueryComponent(_selectedBugId)}'
          '&senderMode=$effectiveSenderMode';

      final data = await _api.getJson(path, token: key);

      if (data["cooldown"] == true) {
        _showAlert("⏳ Cooldown", "Tunggu beberapa saat sebelum mengirim lagi.");
      } else if (data["valid"] == false) {
        _showAlert("❌ Key Invalid",
            "Sesi Anda tidak valid. Silakan login ulang.");
      } else if (data["sended"] == false) {
        _showAlert("⚠️ Gagal",
            (data['message'] ?? data['error'] ?? 'Server gagal memproses permintaan.')
                .toString());
      } else if (data['success'] == false) {
        _showAlert(
            "⚠️ Gagal", (data['error'] ?? 'Server menolak permintaan.').toString());
      } else {
        _showAlert("✅ Berhasil", "Bug sukses dikirim ke target!");
        _target.clear();
        _loadStats();
      }
    } on ApiException catch (e) {
      _showAlert("❌ Error", e.message);
    } catch (e) {
      _showAlert("❌ Error", "Terjadi kesalahan pada sistem: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showAlert(String title, String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor, width: 1.2),
        ),
        title: Row(
          children: [
            Icon(
              title.contains("✅")
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: accentColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textMain,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          msg,
          style: TextStyle(color: textSub, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "CLOSE",
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w800,
                fontFamily: 'Orbitron',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ====================  UI BUILDERS  =========================
  // ============================================================

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          const BoxShadow(
              color: borderColor, blurRadius: 0, offset: Offset(3, 3)),
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
            child: Icon(Icons.bug_report_outlined, color: accentDark, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "LAUNCH PAD",
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
                  "Ready to send payload",
                  style: TextStyle(
                    color: textSub,
                    fontSize: 11,
                    fontFamily: 'ShareTechMono',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          const BoxShadow(
              color: borderColor, blurRadius: 0, offset: Offset(2, 2)),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(8),
              border:
                  Border.all(color: accentColor.withOpacity(0.4), width: 1),
            ),
            child: Icon(icon, color: accentDark, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: TextStyle(
              color: textMain,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontFamily: 'ShareTechMono',
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: textSub,
              fontSize: 10,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionButton({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return _PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            const BoxShadow(
                color: borderColor, blurRadius: 0, offset: Offset(2, 2)),
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentSoft,
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: accentColor.withOpacity(0.4), width: 1),
              ),
              child: Icon(icon, color: accentDark, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textSub,
                      fontSize: 10,
                      fontFamily: 'Orbitron',
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: textMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'ShareTechMono',
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPopupOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accentColor : borderColor.withOpacity(0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? accentDark : textMain,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            if (isSelected)
              Icon(Icons.check_circle, color: accentColor, size: 18),
          ],
        ),
      ),
    );
  }

  void _switchTargetMode(String mode) {
    if (_targetMode == mode) return;
    setState(() {
      _targetMode = mode;
      _target.clear();
    });
    _initWheelController();
  }

  void _showTargetTypePopup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          "PILIH MODE TARGET",
          style: TextStyle(
            color: textMain,
            fontFamily: 'Orbitron',
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor, width: 1.2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPopupOption(
              label: "BUG NOMOR",
              isSelected: _targetMode == "number",
              onTap: () {
                Navigator.pop(ctx);
                _switchTargetMode("number");
              },
            ),
            const SizedBox(height: 10),
            _buildPopupOption(
              label: "BUG GROUP",
              isSelected: _targetMode == "group",
              onTap: () {
                Navigator.pop(ctx);
                _switchTargetMode("group");
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSenderModeButton({
    required String label,
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return _PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? accentSoft : bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : borderColor.withOpacity(0.3),
            width: isSelected ? 1.3 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  const BoxShadow(
                      color: borderColor,
                      blurRadius: 0,
                      offset: Offset(2, 2)),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: Icon(
                icon,
                key: ValueKey(isSelected),
                color: isSelected ? accentDark : textSub,
                size: 18,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                color: isSelected ? accentDark : textSub,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontFamily: 'Orbitron',
                letterSpacing: 0.6,
              ),
              child: Text(label),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                color: isSelected ? accentDark : textSub,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'ShareTechMono',
              ),
              child: Text(count.toString()),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // =============  WHEEL PICKER (PAYLOAD SELECT)  ==============
  // ============================================================

  Widget _buildModernWheelPicker(List<Map<String, dynamic>> availableBugs) {
    if (availableBugs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: Text(
          "Tidak ada payload tersedia untuk mode ini.",
          style: TextStyle(
            color: textSub,
            fontFamily: 'ShareTechMono',
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            "SELECT PAYLOAD",
            style: TextStyle(
              color: textMain,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              fontFamily: 'Orbitron',
              letterSpacing: 1.5,
            ),
          ),
        ),
        Container(
          height: 112,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              const BoxShadow(
                  color: borderColor, blurRadius: 0, offset: Offset(2, 2)),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              ListWheelScrollView.useDelegate(
                controller: _wheelController,
                itemExtent: 32,
                diameterRatio: 6.0,
                perspective: 0.001,
                offAxisFraction: 0,
                physics: const BouncingScrollPhysics(),
                useMagnifier: false,
                magnification: 1.0,
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedBugId = availableBugs[index]['bug_id'];
                  });
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: availableBugs.length,
                  builder: (context, index) {
                    final bug = availableBugs[index];
                    final isSelected = bug['bug_id'] == _selectedBugId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _cleanBugName(bug['bug_name'] ?? 'Unknown'),
                          textAlign: TextAlign.left,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? accentDark
                                : textSub.withOpacity(0.5),
                            fontSize: isSelected ? 14 : 11,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w400,
                            fontFamily: 'ShareTechMono',
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 26,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          bgCard.withOpacity(0.0),
                          bgCard.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ====================  INPUT PANEL  =========================
  // ============================================================

  Widget _buildInputPanel() {
    final availableBugs = _getFilteredBugs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSelectionButton(
          title: "TARGET TYPE",
          value: _targetMode == "number" ? "BUG NOMOR" : "BUG GROUP",
          icon: _targetMode == "number"
              ? Icons.phone_android_rounded
              : Icons.group_add,
          onTap: _showTargetTypePopup,
        ),
        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            _targetMode == "number"
                ? "TARGET NUMBER"
                : "WHATSAPP GROUP LINK",
            style: TextStyle(
              color: textMain,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'Orbitron',
              letterSpacing: 1.5,
            ),
          ),
        ),

        TextField(
          controller: _target,
          style: const TextStyle(color: textMain, fontSize: 16),
          cursorColor: accentColor,
          keyboardType: _targetMode == "number"
              ? TextInputType.phone
              : TextInputType.url,
          decoration: InputDecoration(
            hintText: _targetMode == "number"
                ? "e.g. +628xxxxxxxx"
                : "e.g. https://chat.whatsapp.com/...",
            hintStyle: TextStyle(color: textSub.withOpacity(0.5)),
            filled: true,
            fillColor: bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: borderColor, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: borderColor, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: accentColor, width: 1.5),
            ),
            prefixIcon: Icon(
              _targetMode == "number"
                  ? Icons.phone_android_rounded
                  : Icons.link,
              color: accentColor,
            ),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          ),
        ),

        const SizedBox(height: 20),

        _buildModernWheelPicker(availableBugs),

        const SizedBox(height: 16),

        if (_canChooseGlobal) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              "SENDER MODE",
              style: TextStyle(
                color: textMain,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                fontFamily: 'Orbitron',
                letterSpacing: 1.5,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildSenderModeButton(
                  label: "PRIVATE",
                  icon: Icons.person_outline,
                  count: _privateCount,
                  isSelected: _senderMode == 'private',
                  onTap: () => setState(() => _senderMode = 'private'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSenderModeButton(
                  label: "GLOBAL",
                  icon: Icons.public,
                  count: _globalCount,
                  isSelected: _senderMode == 'global',
                  onTap: () => setState(() => _senderMode = 'global'),
                ),
              ),
            ],
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: _buildSenderModeButton(
                  label: "PRIVATE",
                  icon: Icons.person_outline,
                  count: _privateCount,
                  isSelected: true,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSenderModeButton(
                  label: "GLOBAL",
                  icon: Icons.public,
                  count: _globalCount,
                  isSelected: false,
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Mode global hanya dapat dipilih oleh Owner/Developer.',
              style: TextStyle(
                fontSize: 11,
                color: textSub,
                fontFamily: 'ShareTechMono',
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // ====================  SEND BUTTON  =========================
  // ============================================================

  Widget _buildSendButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return _PressableScale(
          onTap: _isSending ? null : _sendBug,
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.2),
              color: accentColor,
              boxShadow: [
                const BoxShadow(
                  color: borderColor,
                  blurRadius: 0,
                  offset: Offset(3, 3),
                ),
                BoxShadow(
                  color: accentColor.withOpacity(0.3 * _pulseController.value),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isSending ? null : _sendBug,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.rocket_launch_outlined,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          "LAUNCH ATTACK",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.8,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  void _openSenders() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const WhatsAppSenderScreen()));
  }

  // ============================================================
  // ======================  BUILD  =============================
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgMain,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _loadBugs();
            await _loadStats();
          },
          color: accentColor,
          backgroundColor: bgCard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopHeader(),
                const SizedBox(height: 14),

                if (_loading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(
                      color: accentColor,
                      backgroundColor: accentSoft,
                    ),
                  ),

                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.2),
                      boxShadow: const [
                        BoxShadow(
                            color: borderColor,
                            blurRadius: 0,
                            offset: Offset(2, 2)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline,
                            color: accentColor, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: textMain,
                              fontSize: 12,
                              fontFamily: 'ShareTechMono',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Row(
                  children: [
                    Expanded(
                      child: _statCard('PRIVATE SENDER', _privateCount,
                          Icons.person_outline_rounded),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard('GLOBAL SENDER', _globalCount,
                          Icons.public_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                _buildInputPanel(),
                const SizedBox(height: 22),

                _buildSendButton(),
                const SizedBox(height: 14),

                _PressableScale(
                  onTap: _openSenders,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: bgCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor, width: 1.2),
                      boxShadow: [
                        const BoxShadow(
                            color: borderColor,
                            blurRadius: 0,
                            offset: Offset(2, 2)),
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentSoft,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: accentColor.withOpacity(0.4),
                                width: 1),
                          ),
                          child: Icon(Icons.hub_rounded,
                              color: accentDark, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "SENDER NODES",
                                style: TextStyle(
                                  color: textMain,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Orbitron',
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Tambah nomor, pairing, dan kelola koneksi sender",
                                style: TextStyle(
                                  color: textSub,
                                  fontSize: 11,
                                  fontFamily: 'ShareTechMono',
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: accentColor, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Aksen animasi: efek scale halus saat tombol ditekan ---
class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressableScale({required this.child, this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  double _scale = 1.0;

  void _setPressed(bool pressed) {
    if (!mounted) return;
    setState(() => _scale = pressed ? 0.96 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}