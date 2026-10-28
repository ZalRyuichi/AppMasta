import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../config/gemini_config.dart';
import '../core/app_nav.dart';
import '../core/role_config.dart';
import '../screens/music/music_screen.dart';
import '../screens/seller_create_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/storan_picker_screen.dart';
import '../screens/tools/ai_chat_screen.dart';
import '../screens/tools/instagram_downloader_screen.dart';
import '../screens/tools/tiktok_downloader_screen.dart';
import '../widgets/sync_widgets.dart';

class BocchiMessage {
  const BocchiMessage({required this.isUser, required this.text});

  final bool isUser;
  final String text;

  Map<String, dynamic> toJson() => {'isUser': isUser, 'text': text};

  factory BocchiMessage.fromJson(Map<String, dynamic> json) => BocchiMessage(
        isUser: json['isUser'] == true,
        text: json['text']?.toString() ?? '',
      );
}

/// Definisi 1 command "buka fitur" — dipetakan ke key yang dikenal Gemini
/// function calling (`screen`), label buat balasan default, dan aksinya.
class _ScreenDef {
  const _ScreenDef(this.key, this.label);
  final String key;
  final String label;
}

const _allScreens = <_ScreenDef>[
  _ScreenDef('home', 'Dashboard'),
  _ScreenDef('devices', 'daftar Device'),
  _ScreenDef('era', 'This Is My Era (kontrol remote)'),
  _ScreenDef('sms', 'Pesan SMS'),
  _ScreenDef('music', 'Musik'),
  _ScreenDef('settings', 'Pengaturan'),
  _ScreenDef('tiktok', 'TikTok Downloader'),
  _ScreenDef('instagram', 'Instagram Downloader'),
  _ScreenDef('aichat', 'Void AI Chat'),
  _ScreenDef('storan', 'Storan Akun'),
  _ScreenDef('buatakun', 'Buat Akun'),
];

/// "Otak" si Bocchi — asisten aplikasi penuh yang tinggal di Dashboard:
/// nyimpan riwayat chat, ngobrol lewat Gemini (function calling asli buat
/// buka fitur), ngomong pakai TTS, dan sesekali nyapa sendiri (idle chatter).
class BocchiCompanionService extends ChangeNotifier {
  BocchiCompanionService() {
    _initTts();
    _loadHistory();
    _scheduleIdleChatter();
  }

  static const _prefsKey = 'bocchi_chat_history';
  static const _maxHistory = 60;

  static const _idleLines = [
    // Yapping sendiri ala Bocchi (ngomong ke diri sendiri, canggung, pegang gitar)
    'Eh... gitarnya kok berdebu lagi ya... harusnya aku latihan...',
    'Sheila on 7... lagunya enak banget... *nyanyi pelan* "dan biarkan..." hehe...',
    'Aku... aku lagi di sini aja... nggak ngapa-ngapain... *geleng kepala*',
    'Kalau aku nyanyi di depan orang... pasti malu banget deh... tapi... mau juga...',
    'Hmm... chord-nya yang mana ya tadi... ah lupa lagi...',
    'Bocchi... Bocchi... fokus kamu ngobrol sendiri terus... *menghela napas*',
    'Lagu baru Sheila on 7... pengen banget cover... tapi suara aku jelek...',
    'Aku di sini lho... kalau mau ngobrol... atau... dengerin aku nyanyi pelan...',
    'Hehe... lagi mikirin setlist... atau cuma ngelamun aja...',
    'Gitar elektrik... atau akustik ya hari ini... *menggigit bibir*',
    'Semangat... semangat... aku bisa... *bisik sendiri*',
    'Kalau kamu denger... aku lagi yapping sendiri lagi... maaf ya...',
  ];

  final _rand = Random();
  final _tts = FlutterTts();
  final _speech = stt.SpeechToText();
  Timer? _idleTimer;
  Timer? _bubbleTimer;

  final List<BocchiMessage> messages = [];
  String bubbleText = '';
  bool bubbleVisible = false;
  bool isThinking = false;
  bool isListening = false;
  String partialTranscript = '';
  bool voiceEnabled = true;
  bool chatOpen = false;
  bool _speechReady = false;

  String _username = 'kamu';
  String _role = 'member';
  bool _hasDevice = false;
  ValueChanged<int>? _onNavigateTab;

  /// Dipanggil dari widget dashboard supaya Bocchi tahu identitas & konteks
  /// user (nama, role, apakah sudah pilih device) dan bisa memicu pindah tab.
  void bindContext({
    required String username,
    required String role,
    required bool hasDevice,
    required ValueChanged<int> onNavigateTab,
  }) {
    if (username.trim().isNotEmpty) _username = username.trim();
    _role = role;
    _hasDevice = hasDevice;
    _onNavigateTab = onNavigateTab;
  }

  List<_ScreenDef> get _allowedScreens => _allScreens.where((s) {
        if (s.key == 'sms') return _hasDevice;
        if (s.key == 'storan') return _role != 'developer';
        if (s.key == 'buatakun') return RoleConfig.canSellerCreate(_role);
        return true;
      }).toList();

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('id-ID');
      // Suara asisten netral
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.48);
    } catch (_) {
      // Perangkat tanpa engine TTS terpasang — abaikan, chat tetap jalan.
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      messages.addAll(list.map((e) => BocchiMessage.fromJson(Map<String, dynamic>.from(e as Map))));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = messages.length > _maxHistory ? messages.sublist(messages.length - _maxHistory) : messages;
      await prefs.setString(_prefsKey, jsonEncode(trimmed.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }

  void _scheduleIdleChatter() {
    // Asisten aplikasi: tidak yapping sendiri. Hanya bicara saat user minta.
    _idleTimer?.cancel();
  }

  void _sayIdleLine() {
    // no-op — tidak ada idle chatter
  }

  void _showBubble(String text, {bool speak = false}) {
    _bubbleTimer?.cancel();
    bubbleText = text;
    bubbleVisible = true;
    notifyListeners();
    if (speak && voiceEnabled) _speak(text);
    _bubbleTimer = Timer(const Duration(seconds: 6), () {
      bubbleVisible = false;
      notifyListeners();
    });
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    // Buang *aksi* biar TTS lebih natural
    final clean = text.replaceAll(RegExp(r'\*[^*]+\*'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(clean);
    } catch (_) {}
  }

  void toggleVoice() {
    voiceEnabled = !voiceEnabled;
    if (!voiceEnabled) _tts.stop();
    notifyListeners();
  }

  Future<bool> _ensureSpeech() async {
    if (_speechReady) return true;
    try {
      _speechReady = await _speech.initialize(
        onError: (e) {
          isListening = false;
          partialTranscript = '';
          notifyListeners();
        },
        onStatus: (s) {
          if (s == 'done' || s == 'notListening') {
            if (isListening) {
              isListening = false;
              notifyListeners();
            }
          }
        },
      );
    } catch (_) {
      _speechReady = false;
    }
    return _speechReady;
  }

  /// Tekan Bocchi → mulai dengar (voice-only seperti di video SYAM).
  Future<void> startListening() async {
    if (isThinking || isListening) return;
    final ok = await _ensureSpeech();
    if (!ok) {
      _showBubble('Mic-nya belum bisa... izinkan akses mikrofon ya~', speak: true);
      return;
    }
    try {
      await _tts.stop();
    } catch (_) {}
    partialTranscript = '';
    isListening = true;
    notifyListeners();
    await _speech.listen(
      localeId: 'id_ID',
      listenFor: const Duration(seconds: 20),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      cancelOnError: true,
      listenMode: stt.ListenMode.confirmation,
      onResult: (result) {
        partialTranscript = result.recognizedWords;
        notifyListeners();
        if (result.finalResult) {
          final text = result.recognizedWords.trim();
          isListening = false;
          partialTranscript = '';
          notifyListeners();
          if (text.isNotEmpty) {
            unawaited(sendMessage(text));
          }
        }
      },
    );
  }

  Future<void> stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    isListening = false;
    final text = partialTranscript.trim();
    partialTranscript = '';
    notifyListeners();
    if (text.isNotEmpty && !isThinking) {
      unawaited(sendMessage(text));
    }
  }

  void openChat() {
    chatOpen = true;
    bubbleVisible = false;
    _bubbleTimer?.cancel();
    if (messages.isEmpty) {
      messages.add(BocchiMessage(
        isUser: false,
        text: 'Halo $_username. Saya LC Kairo, asisten aplikasi VOID SPY. Ada yang bisa dibantu?'
            'VTuber kecil yang suka gitar sama Sheila on 7 di VOID SPY ini... '
            'Kamu bisa langsung ngobrol aja sama aku... atau suruh aku buka menu apa aja... '
            'umm... aku di sini kok...',
      ));
      unawaited(_saveHistory());
    }
    notifyListeners();
  }

  void closeChat() {
    chatOpen = false;
    notifyListeners();
  }

  Future<void> clearHistory() async {
    messages.clear();
    await _saveHistory();
    notifyListeners();
  }

  String get _systemPrompt {
    final list = _allowedScreens.map((s) => '${s.key} (${s.label})').join(', ');
    return '''
Kamu adalah LC Kairo — asisten AI resmi aplikasi VOID SPY.
Kepribadian: profesional, ringkas, membantu, tenang. Bukan karakter anime/VTuber.
- Balas SELALU Bahasa Indonesia, jelas, maksimal 2-3 kalimat.
- Jangan yapping, jangan roleplay malu-malu, jangan *aksi* berlebihan.
- Fokus bantu navigasi aplikasi dan jawab pertanyaan user tentang fitur VOID SPY.
- Jika user hanya basa-basi singkat, balas singkat saja.

Nama pengguna: $_username, role: $_role.

Kalau pengguna minta buka/pindah ke suatu menu, panggil function "open_screen" dengan salah satu key berikut: $list.
Kalau cuma ngobrol biasa, JANGAN panggil function apa pun, cukup balas sebagai asisten aplikasi.
''';
  }

  Map<String, dynamic> get _openScreenTool => {
        'functionDeclarations': [
          {
            'name': 'open_screen',
            'description': 'Membuka menu/fitur/halaman tertentu di aplikasi VOID SPY untuk pengguna.',
            'parameters': {
              'type': 'OBJECT',
              'properties': {
                'screen': {
                  'type': 'STRING',
                  'enum': _allowedScreens.map((s) => s.key).toList(),
                  'description': 'Key menu yang mau dibuka.',
                },
              },
              'required': ['screen'],
            },
          },
        ],
      };

  Future<void> sendMessage(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || isThinking) return;

    messages.add(BocchiMessage(isUser: true, text: prompt));
    isThinking = true;
    notifyListeners();
    await _saveHistory();

    try {
      // Gemini mewajibkan 'contents' diawali role user — skip sapaan awal
      // Bocchi (model) kalau itu masih jadi entry paling depan.
      var seenUser = false;
      final history = messages.where((m) {
        if (!seenUser && m.isUser) seenUser = true;
        return seenUser;
      });

      final payload = {
        'system_instruction': {
          'parts': [
            {'text': _systemPrompt},
          ],
        },
        'contents': history
            .map((m) => {
                  'role': m.isUser ? 'user' : 'model',
                  'parts': [
                    {'text': m.text},
                  ],
                })
            .toList(),
        'tools': [_openScreenTool],
      };

      final res = await http
          .post(
            GeminiConfig.endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      final decoded = jsonDecode(res.body);

      if (res.statusCode != 200 || decoded is! Map<String, dynamic>) {
        String? apiMsg;
        if (decoded is Map) {
          final err = decoded['error'];
          if (err is Map) {
            apiMsg = err['message']?.toString();
          }
        }
        messages.add(BocchiMessage(
          isUser: false,
          text: 'Aduh, aku lagi susah connect nih${apiMsg != null ? ' ($apiMsg)' : ' (kode ${res.statusCode})'}. '
              'Coba lagi sebentar ya~',
        ));
        return;
      }

      final candidates = decoded['candidates'] as List<dynamic>?;
      final parts = candidates != null && candidates.isNotEmpty
          ? (candidates.first['content']?['parts'] as List<dynamic>? ?? const [])
          : const <dynamic>[];

      String textReply = '';
      Map<String, dynamic>? functionCall;
      for (final p in parts) {
        if (p is! Map) continue;
        if (p['text'] is String) textReply += p['text'] as String;
        if (p['functionCall'] is Map) functionCall = Map<String, dynamic>.from(p['functionCall'] as Map);
      }

      String? command;
      if (functionCall != null && functionCall['name'] == 'open_screen') {
        final args = functionCall['args'];
        if (args is Map) {
          command = args['screen']?.toString();
        }
      }
      final screenDef = command == null ? null : _allowedScreens.where((s) => s.key == command).firstOrNull;

      final finalReply = textReply.trim().isNotEmpty
          ? textReply.trim()
          : (screenDef != null ? 'Oke, aku bukain ${screenDef.label} ya~' : 'Hmm, boleh diulang lagi?');

      messages.add(BocchiMessage(isUser: false, text: finalReply));
      if (voiceEnabled) unawaited(_speak(finalReply));
      // Bubble di samping avatar (mode voice, tanpa buka sheet)
      if (!chatOpen) {
        _showBubble(finalReply, speak: false);
      }

      if (screenDef != null) {
        Future.delayed(const Duration(milliseconds: 400), () => _openScreen(screenDef.key));
      }
    } catch (_) {
      messages.add(const BocchiMessage(isUser: false, text: 'Waduh, koneksinya putus. Coba lagi sebentar ya~'));
      if (!chatOpen) {
        _showBubble('Waduh, koneksinya putus. Coba lagi sebentar ya~', speak: true);
      }
    } finally {
      isThinking = false;
      notifyListeners();
      await _saveHistory();
    }
  }

  void _openScreen(String key) {
    final nav = appNavigatorKey.currentState;
    // Tutup dulu sheet chat-nya biar transisi ke menu/tab tujuan rapi.
    if (nav != null && nav.canPop()) nav.pop();
    closeChat();

    switch (key) {
      case 'home':
        _onNavigateTab?.call(0);
        return;
      case 'devices':
        _onNavigateTab?.call(1);
        return;
      case 'era':
        _onNavigateTab?.call(2);
        return;
      case 'sms':
        _onNavigateTab?.call(3);
        return;
    }

    if (nav == null) return;
    switch (key) {
      case 'music':
        nav.push(syncPageRoute(const MusicScreen()));
      case 'settings':
        nav.push(syncPageRoute(const SettingsScreen()));
      case 'tiktok':
        nav.push(syncPageRoute(const TiktokDownloaderScreen()));
      case 'instagram':
        nav.push(syncPageRoute(const InstagramDownloaderScreen()));
      case 'aichat':
        nav.push(syncPageRoute(AiChatScreen(username: _username, role: _role)));
      case 'storan':
        nav.push(syncPageRoute(const StoranPickerScreen()));
      case 'buatakun':
        nav.push(syncPageRoute(const SellerCreateScreen()));
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _bubbleTimer?.cancel();
    try {
      _speech.stop();
    } catch (_) {}
    _tts.stop();
    super.dispose();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
