import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional RPG sound: short effects (on by default) and a relaxing ambient
/// loop (off by default, so nothing plays unexpectedly in a quiet place).
///
/// Sound is never essential: every failure is ignored, players are created
/// only when something actually plays, and the loop pauses when the app goes
/// to the background. All audio is original and synthesised for Balance.
class SoundService extends ChangeNotifier with WidgetsBindingObserver {
  // ignore: prefer_initializing_formals
  SoundService({SharedPreferencesAsync? prefs}) : _prefs = prefs {
    WidgetsBinding.instance.addObserver(this);
  }

  static const _effectsKey = 'balance.sound.effects.v1';
  static const _musicKey = 'balance.sound.music.v1';

  final SharedPreferencesAsync? _prefs;
  AudioPlayer? _effects;
  AudioPlayer? _music;
  bool _disposed = false;

  bool effectsOn = true;
  bool musicOn = false;

  Future<void> load() async {
    try {
      final prefs = _prefs ?? SharedPreferencesAsync();
      effectsOn = await prefs.getBool(_effectsKey) ?? true;
      musicOn = await prefs.getBool(_musicKey) ?? false;
      if (_disposed) return;
      notifyListeners();
      if (musicOn) await _startMusic();
    } catch (_) {}
  }

  Future<void> setEffects(bool on) async {
    effectsOn = on;
    notifyListeners();
    await _save(_effectsKey, on);
  }

  Future<void> setMusic(bool on) async {
    musicOn = on;
    notifyListeners();
    await _save(_musicKey, on);
    on ? await _startMusic() : await _stopMusic();
  }

  Future<void> playAchievement() => _effect('audio/achievement_unlock.wav');
  Future<void> playConfirm() => _effect('audio/plan_confirmed.wav');

  Future<void> _effect(String asset) async {
    if (!effectsOn || _disposed) return;
    try {
      final player = _effects ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource(asset), volume: 0.7);
    } catch (_) {}
  }

  Future<void> _startMusic() async {
    if (_disposed) return;
    try {
      final player = _music ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('audio/sanctuary_ambient.wav'), volume: 0.35);
    } catch (_) {}
  }

  Future<void> _stopMusic() async {
    try {
      await _music?.stop();
    } catch (_) {}
  }

  Future<void> _save(String key, bool value) async {
    try {
      await (_prefs ?? SharedPreferencesAsync()).setBool(key, value);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!musicOn) return;
    try {
      if (state == AppLifecycleState.resumed) {
        _music?.resume();
      } else if (state == AppLifecycleState.paused) {
        _music?.pause();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _effects?.dispose();
    _music?.dispose();
    super.dispose();
  }
}
