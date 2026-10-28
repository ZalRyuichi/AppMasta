import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/track_model.dart';
import 'jamendo_service.dart';

/// Player global (Provider) — tetap hidup saat pindah halaman / app background
/// sampai durasi lagu selesai (wakelock + audio session music).
class MusicPlayerService extends ChangeNotifier {
  MusicPlayerService() {
    _init();
  }

  final _jamendo = JamendoService();
  final _player = AudioPlayer();

  List<TrackModel> tracks = [];
  List<TrackModel> queue = [];
  TrackModel? current;
  bool loading = false;
  bool searching = false;
  String? error;
  String lastQuery = '';
  bool _ready = false;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<ProcessingState>? _procSub;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  bool get isPlaying => _player.playing;
  bool get hasTrack => current != null;

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          if (event.type == AudioInterruptionType.duck) {
            _player.setVolume(0.35);
          } else {
            _player.pause();
            _syncWakelock(false);
          }
        } else {
          _player.setVolume(1);
        }
        notifyListeners();
      });
      session.becomingNoisyEventStream.listen((_) {
        _player.pause();
        _syncWakelock(false);
        notifyListeners();
      });
    } catch (_) {}

    _stateSub = _player.playerStateStream.listen((state) {
      _syncWakelock(state.playing);
      notifyListeners();
    });
    _durSub = _player.durationStream.listen((d) {
      duration = d ?? Duration.zero;
      notifyListeners();
    });
    _posSub = _player.positionStream.listen((p) {
      position = p;
      notifyListeners();
    });
    _procSub = _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // Lanjut next, atau stop di akhir queue (durasi habis)
        playNext();
      }
    });

    _ready = true;
    await loadPopular();
  }

  Future<void> _syncWakelock(bool on) async {
    try {
      if (on) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (_) {}
  }

  Future<void> loadPopular() async {
    searching = true;
    error = null;
    notifyListeners();
    try {
      tracks = await _jamendo.popularTracks();
      lastQuery = '';
    } catch (e) {
      error = e.toString();
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  Future<void> search(String query) async {
    searching = true;
    error = null;
    lastQuery = query;
    notifyListeners();
    try {
      tracks = await _jamendo.searchTracks(query);
    } catch (e) {
      error = e.toString();
      tracks = [];
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  Future<void> playTrack(TrackModel track, {List<TrackModel>? fromList}) async {
    if (!_ready) await _init();
    if (track.audioUrl.isEmpty) {
      error = 'URL audio kosong';
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    current = track;
    queue = List.of(fromList ?? tracks);
    notifyListeners();
    try {
      await _player.setUrl(track.audioUrl);
      await _player.play();
      await _syncWakelock(true);
    } catch (e) {
      error = 'Gagal putar: $e';
      await _syncWakelock(false);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> togglePlay() async {
    if (current == null) return;
    if (_player.playing) {
      await _player.pause();
      await _syncWakelock(false);
    } else {
      await _player.play();
      await _syncWakelock(true);
    }
    notifyListeners();
  }

  Future<void> pause() async {
    await _player.pause();
    await _syncWakelock(false);
    notifyListeners();
  }

  Future<void> resume() async {
    await _player.play();
    await _syncWakelock(true);
    notifyListeners();
  }

  Future<void> seek(Duration pos) async {
    await _player.seek(pos);
  }

  Future<void> playNext() async {
    if (current == null || queue.isEmpty) {
      await _player.seek(Duration.zero);
      await _player.pause();
      await _syncWakelock(false);
      notifyListeners();
      return;
    }
    final idx = queue.indexWhere((t) => t.id == current!.id);
    final next = (idx >= 0 && idx < queue.length - 1) ? queue[idx + 1] : null;
    if (next != null) {
      await playTrack(next, fromList: queue);
    } else {
      // Habis antrian — stop (durasi lagu terakhir selesai)
      await _player.seek(Duration.zero);
      await _player.pause();
      await _syncWakelock(false);
      notifyListeners();
    }
  }

  Future<void> playPrevious() async {
    if (current == null || queue.isEmpty) return;
    if (position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    final idx = queue.indexWhere((t) => t.id == current!.id);
    if (idx > 0) {
      await playTrack(queue[idx - 1], fromList: queue);
    } else {
      await seek(Duration.zero);
    }
  }

  Future<void> stop() async {
    await _player.stop();
    current = null;
    position = Duration.zero;
    duration = Duration.zero;
    await _syncWakelock(false);
    notifyListeners();
  }

  String formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _durSub?.cancel();
    _posSub?.cancel();
    _procSub?.cancel();
    _syncWakelock(false);
    _player.dispose();
    super.dispose();
  }
}
