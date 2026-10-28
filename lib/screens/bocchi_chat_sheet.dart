import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/bocchi_companion_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/sync_widgets.dart';

Future<void> showBocchiChatSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _BocchiChatSheet(),
  );
}

class _BocchiChatSheet extends StatefulWidget {
  const _BocchiChatSheet();

  @override
  State<_BocchiChatSheet> createState() => _BocchiChatSheetState();
}

class _BocchiChatSheetState extends State<_BocchiChatSheet> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  int _lastCount = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(BocchiCompanionService bocchi) async {
    final text = _ctrl.text;
    if (text.trim().isEmpty) return;
    _ctrl.clear();
    await bocchi.sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BocchiCompanionService>(
      builder: (context, bocchi, _) {
        final count = bocchi.messages.length + (bocchi.isThinking ? 1 : 0);
        if (count != _lastCount) {
          _lastCount = count;
          _scrollToBottom();
        }

        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: ElegantCard.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AppColors.neoBlack, width: 3),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.neoBlack.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _Header(bocchi: bocchi),
                  const Divider(height: 1, color: Color(0x14000000)),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: count,
                      itemBuilder: (context, i) {
                        if (i == bocchi.messages.length && bocchi.isThinking) {
                          return const _ThinkingBubble();
                        }
                        final m = bocchi.messages[i];
                        return _ChatBubble(text: m.text, isUser: m.isUser);
                      },
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.dashSurface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.neoBlack, width: 3),
                          boxShadow: NeoShadow.hardSm(),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _ctrl,
                                  minLines: 1,
                                  maxLines: 4,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _send(bocchi),
                                  style: AppTypography.menuSubtitle().copyWith(color: AppColors.dashText, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Ngobrol sama Bocchi aja...',
                                    hintStyle: AppTypography.menuSubtitle().copyWith(color: AppColors.dashTextMuted),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Material(
                                color: bocchi.isListening ? const Color(0xFFE53935) : AppColors.dashSurface,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                child: InkWell(
                                  onTap: () async {
                                    if (bocchi.isListening) {
                                      await bocchi.stopListening();
                                    } else {
                                      await bocchi.startListening();
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                      border: Border.all(color: AppColors.neoBlack, width: 2.5),
                                      boxShadow: NeoShadow.hard(dx: 2, dy: 2),
                                    ),
                                    child: Icon(
                                      bocchi.isListening ? Icons.stop_rounded : Icons.mic_rounded,
                                      color: bocchi.isListening ? Colors.white : AppColors.dashAccent,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Material(
                                color: AppColors.dashAccent,
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                child: InkWell(
                                  onTap: () => _send(bocchi),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppRadius.sm),
                                      border: Border.all(color: AppColors.neoBlack, width: 2.5),
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
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.bocchi});

  final BocchiCompanionService bocchi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  const Color(0xFF39E75F),
                  AppColors.dashAccent,
                  const Color(0xFF8BFFA0),
                  const Color(0xFF00C853),
                  const Color(0xFF39E75F),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.dashAccent.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(2.5),
            child: ClipOval(
              child: ColoredBox(
                color: const Color(0xFFFFE0D0),
                child: CustomPaint(
                  size: const Size(48, 48),
                  painter: _BocchiAvatarPainter(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SKY Assistant', style: AppTypography.brand(size: 17)),
                Text(
                  bocchi.isThinking ? 'Memproses...' : 'Asisten aplikasi · siap membantu',
                  style: AppTypography.welcomeMeta(),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: bocchi.voiceEnabled ? 'Matikan suara' : 'Nyalakan suara',
            onPressed: bocchi.toggleVoice,
            icon: Icon(
              bocchi.voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: AppColors.dashAccent,
            ),
          ),
          IconButton(
            tooltip: 'Hapus obrolan',
            onPressed: bocchi.clearHistory,
            icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.dashTextMuted),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isUser});

  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.dashAccent : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
          border: Border.all(color: AppColors.neoBlack, width: 2.5),
          boxShadow: NeoShadow.hard(dx: 2, dy: 2),
        ),
        child: Text(
          text,
          style: AppTypography.menuSubtitle().copyWith(
            fontSize: 13.5,
            height: 1.4,
            color: isUser ? Colors.white : AppColors.dashText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neoBlack.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dashAccent),
            ),
            const SizedBox(width: 10),
            Text('SKY mengetik...', style: AppTypography.menuSubtitle().copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}



/// Mini avatar robot SKY.
class _BocchiAvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.52;

    final body = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFE8EEF5), Color(0xFFB8C4D4)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: w * 0.78, height: h * 0.78),
        Radius.circular(w * 0.22),
      ),
      body,
    );

    // visor
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: w * 0.55, height: h * 0.28),
        Radius.circular(w * 0.1),
      ),
      Paint()..color = const Color(0xFF0A1628),
    );
    final eye = Paint()..color = const Color(0xFF00E5FF);
    canvas.drawCircle(Offset(cx - w * 0.12, cy), w * 0.07, eye);
    canvas.drawCircle(Offset(cx + w * 0.12, cy), w * 0.07, eye);
    canvas.drawCircle(Offset(cx - w * 0.12, cy), w * 0.03, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + w * 0.12, cy), w * 0.03, Paint()..color = Colors.white);

    // antenna
    canvas.drawLine(
      Offset(cx, cy - h * 0.35),
      Offset(cx, cy - h * 0.48),
      Paint()
        ..color = const Color(0xFF7A8FA6)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(cx, cy - h * 0.5), w * 0.06, Paint()..color = const Color(0xFF00E5FF));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
