import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/command_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/sync_widgets.dart';

class ChatMessage {
  final String text;
  final bool isFromAdmin;
  final DateTime time;
  ChatMessage({required this.text, required this.isFromAdmin, required this.time});
}

class LiveChatScreen extends StatefulWidget {
  const LiveChatScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  final String deviceId;
  final String deviceName;

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final _cmd = CommandService();
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];
  final _seenIncoming = <String>{};
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _inputController.clear();

    // Optimistic UI
    setState(() {
      _messages.add(ChatMessage(text: text, isFromAdmin: true, time: DateTime.now()));
    });
    _scrollToBottom();

    try {
      final token = context.read<AuthService>().token;
      if (token == null) return;

      await _cmd.send(
        token: token,
        deviceId: widget.deviceId,
        command: 'chatSend',
        value: text,
      );
    } catch (e) {
      if (mounted) showSyncSnack(context, 'Gagal mengirim: $e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _ingestIncoming(List<Map<String, dynamic>> incoming) {
    var added = false;
    for (final msg in incoming) {
      final txt = msg['text']?.toString() ?? '';
      if (txt.isEmpty) continue;
      if (msg['fromAdmin'] == true) continue;
      final key = '${msg['time'] ?? ''}|$txt';
      if (_seenIncoming.contains(key)) continue;
      if (_messages.any((m) => !m.isFromAdmin && m.text == txt)) {
        _seenIncoming.add(key);
        continue;
      }
      _seenIncoming.add(key);
      _messages.add(ChatMessage(
        text: txt,
        isFromAdmin: false,
        time: DateTime.tryParse(msg['time']?.toString() ?? '') ?? DateTime.now(),
      ));
      added = true;
    }
    if (added) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final incomingMsg = socket.chatMessages[widget.deviceId];
    if (incomingMsg != null && incomingMsg.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ingestIncoming(List<Map<String, dynamic>>.from(incomingMsg));
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFE0E0E0),
      body: Column(
        children: [
          // HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.neoBlack,
              border: Border(
                bottom: BorderSide(color: AppColors.neoBlack, width: 4),
              ),
              boxShadow: [
                BoxShadow(color: Color(0xFF00C853), offset: Offset(0, 4), blurRadius: 0, spreadRadius: 0),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFFFE600)),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '☠ LIVE CHAT SUPPORT',
                          style: TextStyle(
                            color: Color(0xFFFFE600),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF66),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.neoBlack, width: 2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${widget.deviceName} · CONNECTED',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
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
          ),

          // CHAT AREA
          Expanded(
            child: Container(
              color: const Color(0xFFE0E0E0),
              child: _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: AppColors.dashAccent.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Menunggu pesan dari target...',
                            style: AppTypography.menuSubtitle().copyWith(color: Colors.black54),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _buildBubble(_messages[i]),
                    ),
            ),
          ),

          // INPUT AREA
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.neoBlack, width: 4)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.neoBlack, width: 3),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: AppColors.neoBlack, offset: Offset(4, 4), blurRadius: 0, spreadRadius: 0),
                        ],
                      ),
                      child: TextField(
                        controller: _inputController,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.neoBlack,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ketik pesan...',
                          hintStyle: TextStyle(
                            color: Colors.black.withValues(alpha: 0.4),
                            fontWeight: FontWeight.w600,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.neoBlack,
                        border: Border.all(color: AppColors.neoBlack, width: 3),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Color(0xFF00C853), offset: Offset(4, 4), blurRadius: 0, spreadRadius: 0),
                        ],
                      ),
                      child: _sending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Color(0xFFFFE600), strokeWidth: 2),
                            )
                          : const Text(
                              'KIRIM',
                              style: TextStyle(
                                color: Color(0xFFFFE600),
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isAdmin = msg.isFromAdmin;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isAdmin ? AppColors.neoBlack : const Color(0xFF00C853),
                  border: Border.all(color: AppColors.neoBlack, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isAdmin ? 'ADMIN' : 'TARGET',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isAdmin ? const Color(0xFF00F0FF) : Colors.white,
                  border: Border.all(color: AppColors.neoBlack, width: 3),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isAdmin ? 12 : 4),
                    bottomRight: Radius.circular(isAdmin ? 4 : 12),
                  ),
                  boxShadow: const [
                    BoxShadow(color: AppColors.neoBlack, offset: Offset(4, 4), blurRadius: 0, spreadRadius: 0),
                  ],
                ),
                child: Text(
                  msg.text,
                  style: const TextStyle(
                    color: AppColors.neoBlack,
                    fontSize: 15,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 4),
                child: Text(
                  _formatTime(msg.time),
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.5),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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
