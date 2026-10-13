import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional RPG sound: short effects and a relaxing ambient loop, both on by
/// default. The gold music button in every page header turns the loop off
/// in one tap, and the choice is remembered.
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
  AudioPlayer? _campfire;
  bool _atCamp = false;
  bool _loaded = false;
  bool _disposed = false;

  bool effectsOn = true;
  bool musicOn = true;

  Future<void> load() async {
    try {
      final prefs = _prefs ?? SharedPreferencesAsync();
      effectsOn = await prefs.getBool(_effectsKey) ?? true;
      musicOn = await prefs.getBool(_musicKey) ?? true;
      if (_disposed) return;
      _loaded = true;
      notifyListeners();
      if (musicOn) await _startMusic();
      if (musicOn && _atCamp) await _startCampfire();
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
    if (_atCamp) on ? await _startCampfire() : await _stopCampfire();
  }

  /// Sanctuary calls this while it is on screen: a soft crackling fire plays
  /// over the music, only while background music is on.
  Future<void> setAtCamp(bool atCamp) async {
    if (_atCamp == atCamp || _disposed) return;
    _atCamp = atCamp;
    // Before the saved settings load, load() starts the fire if needed.
    if (!_loaded) return;
    atCamp && musicOn ? await _startCampfire() : await _stopCampfire();
  }

  Future<void> _startCampfire() async {
    if (_disposed) return;
    try {
      var player = _campfire;
      if (player == null) {
        player = _campfire = AudioPlayer();
        await player.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build(),
        );
        await player.setReleaseMode(ReleaseMode.loop);
      }
      await player.play(AssetSource('audio/campfire_crackle.wav'), volume: 0.3);
    } catch (_) {}
  }

  Future<void> _stopCampfire() async {
    try {
      await _campfire?.stop();
    } catch (_) {}
  }

  Future<void> playAchievement() => _effect('audio/achievement_unlock.wav');
  Future<void> playConfirm() => _effect('audio/plan_confirmed.wav');

  Future<void> _effect(String asset) async {
    if (!effectsOn || _disposed) return;
    try {
      var player = _effects;
      if (player == null) {
        player = _effects = AudioPlayer();
        // Chimes mix over the music instead of taking audio focus, which
        // would make Android pause the background loop after every chime.
        await player.setAudioContext(
          AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
              .build(),
        );
      }
      await player.stop();
      await player.play(AssetSource(asset), volume: 0.7);
    } catch (_) {}
  }

  Future<void> _startMusic() async {
    if (_disposed) return;
    try {
      final player = _music ??= AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(
        AssetSource('audio/sanctuary_ambient.wav'),
        volume: 0.35,
      );
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
        if (_atCamp) _campfire?.resume();
      } else if (state == AppLifecycleState.paused) {
        _music?.pause();
        _campfire?.pause();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _effects?.dispose();
    _music?.dispose();
    _campfire?.dispose();
    super.dispose();
  }
}
