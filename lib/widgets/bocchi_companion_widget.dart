import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/bocchi_chat_sheet.dart';
import '../services/auth_service.dart';
import '../services/bocchi_companion_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// SKY floating assistant — robot 3D (CustomPainter).
/// Tap = bicara (voice), long-press = buka history chat.
class BocchiCompanionWidget extends StatefulWidget {
  const BocchiCompanionWidget({super.key});

  @override
  State<BocchiCompanionWidget> createState() => _BocchiCompanionWidgetState();
}

class _BocchiCompanionWidgetState extends State<BocchiCompanionWidget> with TickerProviderStateMixin {
  static const double _charH = 118;
  static const double _charW = 72;

  late final AnimationController _idleCtrl;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _idleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idleCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _onTap(BocchiCompanionService bocchi) async {
    if (bocchi.isListening) {
      await bocchi.stopListening();
      return;
    }
    if (bocchi.isThinking) return;
    await bocchi.startListening();
  }

  Future<void> _onLongPress(BocchiCompanionService bocchi) async {
    if (bocchi.isListening) await bocchi.stopListening();
    bocchi.openChat();
    if (!mounted) return;
    await showBocchiChatSheet(context);
    bocchi.closeChat();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.isLoggedIn) return const SizedBox.shrink();

    return Consumer<BocchiCompanionService>(
      builder: (context, bocchi, _) {
        final bottomPad = MediaQuery.paddingOf(context).bottom;
        return Positioned(
          right: 6,
          bottom: bottomPad + 88,
          child: AnimatedBuilder(
            animation: Listenable.merge([_idleCtrl, _pulseCtrl]),
            builder: (context, child) {
              final wobble = sin(_idleCtrl.value * 2 * pi);
              final breathe = 1 + (wobble * 0.035);
              final tilt = wobble * 0.05;
              final lift = -wobble.abs() * 6;
              final listenPulse = bocchi.isListening ? (0.92 + _pulseCtrl.value * 0.12) : 1.0;
              final s = breathe * listenPulse;
              final matrix = Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(tilt * 0.4)
                ..rotateZ(tilt * 0.35)
                ..translate(0.0, lift)
                ..scale(s, s, 1.0);
              return Transform(
                alignment: Alignment.bottomCenter,
                transform: matrix,
                child: child,
              );
            },
            child: GestureDetector(
              onTap: () => _onTap(bocchi),
              onLongPress: () => _onLongPress(bocchi),
              child: SizedBox(
                width: 200,
                height: _charH + 56,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomRight,
                  children: [
                    if (bocchi.bubbleVisible || bocchi.isListening || bocchi.isThinking)
                      Positioned(
                        right: _charW * 0.35,
                        bottom: _charH + 10,
                        child: _SpeechBubble(
                          text: bocchi.isListening
                              ? (bocchi.partialTranscript.isEmpty
                                  ? 'Dengerin... bilang aja~'
                                  : bocchi.partialTranscript)
                              : bocchi.isThinking
                                  ? 'lagi mikir... *gugup*'
                                  : bocchi.bubbleText,
                          listening: bocchi.isListening,
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _BocchiCharacter3D(
                        width: _charW,
                        height: _charH,
                        listening: bocchi.isListening,
                        thinking: bocchi.isThinking,
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          bocchi.isListening ? 'tap: stop' : 'tap: bicara · tahan: chat',
                          style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BocchiCharacter3D extends StatelessWidget {
  const _BocchiCharacter3D({
    required this.width,
    required this.height,
    required this.listening,
    required this.thinking,
  });

  final double width;
  final double height;
  final bool listening;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width + 16,
      height: height + 14,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Soft ground shadow (3D depth)
          Positioned(
            bottom: 2,
            child: Container(
              width: width * 0.7,
              height: 12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          // Glow ring when listening / thinking
          Positioned(
            bottom: 8,
            child: Container(
              width: width * 0.95,
              height: height * 0.85,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: (listening ? const Color(0xFF00E676) : AppColors.dashAccent)
                        .withValues(alpha: listening ? 0.45 : 0.22),
                    blurRadius: listening ? 28 : 18,
                    spreadRadius: listening ? 2 : 0,
                  ),
                ],
              ),
            ),
          ),
          // Drawn 3D Bocchi (CustomPainter — no photo)
          Positioned(
            bottom: 8,
            child: SizedBox(
              width: width,
              height: height,
              child: CustomPaint(
                painter: _Bocchi3DPainter(
                  listening: listening,
                  thinking: thinking,
                ),
              ),
            ),
          ),
          if (listening || thinking)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: listening ? const Color(0xFFE53935) : AppColors.dashAccent,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: (listening ? const Color(0xFFE53935) : AppColors.dashAccent)
                          .withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: thinking
                    ? const Padding(
                        padding: EdgeInsets.all(2),
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// CustomPainter: robot asisten 3D (volumetric shaded).
class _Bocchi3DPainter extends CustomPainter {
  _Bocchi3DPainter({required this.listening, required this.thinking});

  final bool listening;
  final bool thinking;

  static const _body = Color(0xFFE8EEF5);
  static const _bodyDark = Color(0xFFB8C4D4);
  static const _accent = Color(0xFF00E5FF);
  static const _accentPink = Color(0xFF00C853);
  static const _visor = Color(0xFF0A1628);
  static const _metal = Color(0xFF7A8FA6);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;

    // Soft ground shadow
    final shadow = Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, h * 0.96), width: w * 0.55, height: h * 0.06),
      shadow,
    );

    // --- LEGS ---
    final legPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_body, _bodyDark],
      ).createShader(Rect.fromLTWH(0, h * 0.62, w, h * 0.35));
    // left leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - w * 0.14, h * 0.82), width: w * 0.16, height: h * 0.28),
        Radius.circular(w * 0.06),
      ),
      legPaint,
    );
    // right leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + w * 0.14, h * 0.82), width: w * 0.16, height: h * 0.28),
        Radius.circular(w * 0.06),
      ),
      legPaint,
    );
    // feet
    final foot = Paint()..color = _metal;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - w * 0.14, h * 0.94), width: w * 0.2, height: h * 0.06),
        Radius.circular(w * 0.03),
      ),
      foot,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + w * 0.14, h * 0.94), width: w * 0.2, height: h * 0.06),
        Radius.circular(w * 0.03),
      ),
      foot,
    );

    // --- BODY / TORSO ---
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, h * 0.55), width: w * 0.58, height: h * 0.32),
      Radius.circular(w * 0.12),
    );
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, _body, _bodyDark],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(bodyRect.outerRect);
    canvas.drawRRect(bodyRect, bodyPaint);

    // chest panel / core
    final coreColor = listening
        ? _accentPink
        : (thinking ? const Color(0xFFFFE600) : _accent);
    final core = Paint()
      ..color = coreColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, listening ? 6 : 3);
    canvas.drawCircle(Offset(cx, h * 0.54), w * 0.08, core);
    canvas.drawCircle(Offset(cx, h * 0.54), w * 0.055, Paint()..color = coreColor);
    canvas.drawCircle(Offset(cx, h * 0.54), w * 0.025, Paint()..color = Colors.white.withValues(alpha: 0.85));

    // side vents
    final vent = Paint()
      ..color = _metal.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final dx in [-0.22, 0.22]) {
      for (var i = 0; i < 3; i++) {
        final yy = h * (0.48 + i * 0.045);
        canvas.drawLine(Offset(cx + w * dx - w * 0.04, yy), Offset(cx + w * dx + w * 0.04, yy), vent);
      }
    }

    // --- ARMS ---
    final armPaint = Paint()
      ..shader = LinearGradient(
        colors: [_body, _bodyDark],
      ).createShader(Rect.fromLTWH(0, h * 0.42, w, h * 0.3));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - w * 0.36, h * 0.58), width: w * 0.14, height: h * 0.28),
        Radius.circular(w * 0.07),
      ),
      armPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + w * 0.36, h * 0.58), width: w * 0.14, height: h * 0.28),
        Radius.circular(w * 0.07),
      ),
      armPaint,
    );
    // hands
    canvas.drawCircle(Offset(cx - w * 0.36, h * 0.72), w * 0.07, Paint()..color = _metal);
    canvas.drawCircle(Offset(cx + w * 0.36, h * 0.72), w * 0.07, Paint()..color = _metal);

    // --- HEAD ---
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, h * 0.26), width: w * 0.62, height: h * 0.28),
      Radius.circular(w * 0.14),
    );
    final headPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white, _body, _bodyDark],
      ).createShader(headRect.outerRect);
    canvas.drawRRect(headRect, headPaint);

    // antenna
    final ant = Paint()
      ..color = _metal
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, h * 0.12), Offset(cx, h * 0.04), ant);
    canvas.drawCircle(
      Offset(cx, h * 0.035),
      w * 0.035,
      Paint()..color = listening ? _accentPink : _accent,
    );

    // visor
    final visorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, h * 0.27), width: w * 0.48, height: h * 0.12),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(visorRect, Paint()..color = _visor);

    // eyes in visor
    final eyeColor = listening ? _accentPink : (thinking ? const Color(0xFFFFE600) : _accent);
    final eyePaint = Paint()..color = eyeColor;
    final eyeGlow = Paint()
      ..color = eyeColor.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    if (thinking) {
      // scanning line
      canvas.drawRRect(visorRect, Paint()..color = _visor);
      canvas.drawLine(
        Offset(cx - w * 0.18, h * 0.27),
        Offset(cx + w * 0.18, h * 0.27),
        Paint()
          ..color = eyeColor
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    } else {
      canvas.drawCircle(Offset(cx - w * 0.12, h * 0.27), w * 0.045, eyeGlow);
      canvas.drawCircle(Offset(cx + w * 0.12, h * 0.27), w * 0.045, eyeGlow);
      canvas.drawCircle(Offset(cx - w * 0.12, h * 0.27), w * 0.032, eyePaint);
      canvas.drawCircle(Offset(cx + w * 0.12, h * 0.27), w * 0.032, eyePaint);
      // pupils
      canvas.drawCircle(Offset(cx - w * 0.12, h * 0.27), w * 0.012, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(cx + w * 0.12, h * 0.27), w * 0.012, Paint()..color = Colors.white);
    }

    // ear pieces
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - w * 0.34, h * 0.26), width: w * 0.08, height: h * 0.1),
        Radius.circular(w * 0.03),
      ),
      Paint()..color = _metal,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + w * 0.34, h * 0.26), width: w * 0.08, height: h * 0.1),
        Radius.circular(w * 0.03),
      ),
      Paint()..color = _metal,
    );

    // rim highlight
    canvas.drawRRect(
      headRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _Bocchi3DPainter oldDelegate) {
    return oldDelegate.listening != listening || oldDelegate.thinking != thinking;
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, this.listening = false});

  final String text;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: listening ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(4)),
          border: Border.all(
            color: listening ? AppColors.dashAccent : AppColors.neoBlack,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: AppTypography.menuSubtitle().copyWith(
            fontSize: 12,
            height: 1.3,
            color: listening ? Colors.white : AppColors.dashText,
          ),
        ),
      ),
    );
  }
}
