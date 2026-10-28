import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/command_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../widgets/base64_image.dart';

enum StreamType { camera, screen }

class StreamViewerScreen extends StatefulWidget {
  const StreamViewerScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.type,
    this.facing = 'back',
  });

  final String deviceId;
  final String deviceName;
  final StreamType type;
  final String facing;

  @override
  State<StreamViewerScreen> createState() => _StreamViewerScreenState();
}

class _StreamViewerScreenState extends State<StreamViewerScreen> {
  final _cmd = CommandService();
  bool _started = false;
  bool _stopping = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    if (widget.type == StreamType.camera) {
      await _cmd.send(token: token, deviceId: widget.deviceId, command: 'camera', value: widget.facing);
    } else {
      await _cmd.send(token: token, deviceId: widget.deviceId, command: 'screen', value: 'start');
    }
    if (mounted) setState(() => _started = true);
  }

  Future<void> _stop() async {
    final token = context.read<AuthService>().token;
    if (token == null) return;
    if (widget.type == StreamType.camera) {
      await _cmd.send(token: token, deviceId: widget.deviceId, command: 'camera', value: 'off');
    } else {
      await _cmd.send(token: token, deviceId: widget.deviceId, command: 'screen', value: 'stop');
    }
  }

  Future<void> _stopAndExit() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    await _stop();
    if (mounted) Navigator.pop(context);
  }

  void _toggleControls() => setState(() => _showControls = !_showControls);

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (_started && !_stopping) _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final isCamera = widget.type == StreamType.camera;
    final frame = isCamera
        ? socket.cameraFrames[widget.deviceId]
        : socket.screenFrames[widget.deviceId];
    final frameSeq = isCamera
        ? socket.cameraFrameSeq[widget.deviceId] ?? 0
        : socket.screenFrameSeq[widget.deviceId] ?? 0;
    final title = isCamera ? 'Live Camera' : 'Live Screen';

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (frame != null)
              Positioned.fill(
                child: Base64Image(
                  key: ValueKey('live-$frameSeq'),
                  data: frame,
                  fit: BoxFit.contain,
                  live: true,
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_started) const CircularProgressIndicator(color: AppColors.dashAccent),
                    const SizedBox(height: 12),
                    Text(
                      _started ? 'Menunggu frame...' : 'Memulai stream...',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
              ),

            AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _stopAndExit,
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                              Row(
                                children: [
                                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                                  const SizedBox(width: 6),
                                  Text('${widget.deviceName} · LIVE', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    minimum: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _stopping ? null : _stopAndExit,
                        icon: _stopping
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.stop_rounded),
                        label: Text(_stopping ? 'MENGHENTIKAN...' : 'STOP LIVE'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}