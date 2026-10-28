import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';
import '../../widgets/sync_backgrounds.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, required this.username, required this.role});

  final String username;
  final String role;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _messages = <Map<String, dynamic>>[];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;

  static const _prefsKey = 'skyline_ai_chat_history';

  String get _systemPrompt =>
      'Kamu adalah Void AI, asisten digital untuk panel VOID SPY — This Is My Era. '
      'Kamu berbicara dalam Bahasa Indonesia dengan gaya ramah dan profesional. '
      'Pengguna saat ini: ${widget.username} (role: ${widget.role}). '
      'Kamu membantu tentang fitur VOID SPY: remote device, SMS panel, kontrol perangkat, '
      'buat akun, pengaturan profil, dan tools downloader (TikTok & Instagram). '
      'Jawab ringkas dan informatif. Jangan mengaku sebagai ChatGPT atau AI lain — kamu adalah VOID SPY AI.';

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  Future<void> _loadChat() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || !mounted) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      setState(() {
        _messages.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      });
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _saveChat() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_messages));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String prompt) async {
    if (prompt.trim().isEmpty || _isLoading) return;

    final userMessage = prompt.trim();
    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();
    await _saveChat();

    try {
      final chatHistory = <Map<String, String>>[
        {'role': 'system', 'content': _systemPrompt},
        ..._messages.map((m) => {'role': m['role'].toString(), 'content': m['content'].toString()}),
      ];

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.deepai.org/hacking_is_a_serious_crime'),
      );
      request.fields['chat_style'] = 'chat';
      request.fields['chatHistory'] = jsonEncode(chatHistory);
      request.fields['model'] = 'standard';
      request.fields['hacker_is_stinky'] = 'very_stinky';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        setState(() => _messages.add({'role': 'assistant', 'content': response.body}));
      } else {
        setState(() => _messages.add({
              'role': 'assistant',
              'content': 'Sistem mengalami gangguan (Code: ${response.statusCode}).',
            }));
      }
    } catch (_) {
      setState(() => _messages.add({'role': 'assistant', 'content': 'Koneksi ke VOID SPY AI terputus.'}));
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _scrollToBottom();
      await _saveChat();
    }
  }

  Future<void> _clearChat() async {
    if (_messages.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFFFFCFE),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.dashAccent.withValues(alpha: 0.12)),
        ),
        title: Text('Hapus Riwayat', style: AppTypography.menuTitle()),
        content: Text('Semua percakapan akan dihapus.', style: AppTypography.menuSubtitle()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dashAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _messages.clear());
    await _saveChat();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppMotion.normal,
        curve: AppMotion.curve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text('VOID SPY AI', style: AppTypography.brand(size: 18)),
          actions: [
            if (_messages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: AppColors.dashAccent.withValues(alpha: 0.1),
                    ),
                    child: Text('${_messages.length}', style: AppTypography.tagline(color: AppColors.dashAccent)),
                  ),
                ),
              ),
            IconButton(onPressed: _clearChat, icon: const Icon(Icons.delete_sweep_outlined)),
          ],
        ),
        body: SakuraMeshBackground(
          child: Column(
            children: [
              Expanded(
                child: _messages.isEmpty && !_isLoading
                    ? _EmptyState(username: widget.username)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: _messages.length + (_isLoading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length && _isLoading) {
                            return const _LoadingBubble();
                          }
                          final msg = _messages[index];
                          return _MessageBubble(
                            text: msg['content']?.toString() ?? '',
                            isUser: msg['role'] == 'user',
                          );
                        },
                      ),
              ),
              // Input stays at bottom; Scaffold resizeToAvoidBottomInset handles keyboard
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.dashSurface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.neoBlack, width: 3),
                      boxShadow: NeoShadow.hardSm(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              minLines: 1,
                              maxLines: 4,
                              textInputAction: TextInputAction.send,
                              onSubmitted: _sendMessage,
                              style: AppTypography.menuSubtitle().copyWith(color: AppColors.dashText, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Ketik pesan...',
                                hintStyle: AppTypography.menuSubtitle().copyWith(color: AppColors.dashTextMuted),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Material(
                            color: AppColors.dashAccent,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: InkWell(
                              onTap: () => _sendMessage(_textController.text),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  border: Border.all(color: AppColors.neoBlack, width: 2.5),
                                  color: AppColors.dashAccent,
                                  boxShadow: NeoShadow.hard(dx: 2, dy: 2),
                                ),
                                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              ),
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
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.dashAccent.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppColors.dashAccent, size: 34),
            ),
            const SizedBox(height: 18),
            Text('Halo, $username!', style: AppTypography.welcomeName()),
            const SizedBox(height: 6),
            Text('VOID SPY AI siap membantu.', style: AppTypography.menuSubtitle()),
            const SizedBox(height: 4),
            Text('Ketik apapun untuk memulai.', style: AppTypography.welcomeMeta()),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        decoration: BoxDecoration(
          color: isUser ? AppColors.dashAccent : AppColors.dashSurface,
          borderRadius: BorderRadius.circular(AppRadius.md).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
          border: Border.all(color: AppColors.neoBlack, width: 2.5),
          boxShadow: NeoShadow.hard(dx: 3, dy: 3),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
                  size: 13,
                  color: isUser ? Colors.white : AppColors.dashAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  isUser ? 'KAMU' : 'VOID SPY AI',
                  style: AppTypography.statLabel().copyWith(
                    fontSize: 9,
                    color: isUser ? Colors.white : AppColors.dashAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: AppTypography.menuSubtitle().copyWith(
                fontSize: 14,
                height: 1.45,
                color: isUser ? Colors.white : AppColors.dashText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBubble extends StatelessWidget {
  const _LoadingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dashAccent)),
            const SizedBox(width: 10),
            Text('Memproses...', style: AppTypography.menuSubtitle().copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}