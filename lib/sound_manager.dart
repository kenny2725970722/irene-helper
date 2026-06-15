import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The 3 ambient sounds (plus "none" for silent mode).
///
/// An ENUM is a fixed set of options. It prevents typos —
/// you can't accidentally type SoundType.ran instead of SoundType.rain.
enum SoundType { rain, firewood, cafe, none }

/// Holds all the info about one sound option.
///
/// A CLASS is a blueprint for creating objects. Each SoundOption
/// has a label, an emoji icon, a type, and the file path to play.
class SoundOption {
  final String label;
  final String emoji;
  final SoundType type;
  final String assetPath;

  const SoundOption({
    required this.label,
    required this.emoji,
    required this.type,
    required this.assetPath,
  });
}

/// Manages playing/stopping ambient sounds.
///
/// Wraps the audioplayers package in a simple API.
class SoundManager {
  final AudioPlayer _player = AudioPlayer();
  SoundType _currentSound = SoundType.none;

  /// The list of all available sounds.
  ///
  /// A LIST is an ordered collection. You can loop through it,
  /// search it, and map over it to build UI.
  static const List<SoundOption> sounds = [
    SoundOption(
      label: 'Rain',
      emoji: '🌧️',
      type: SoundType.rain,
      assetPath: 'sounds/rain.wav',
    ),
    SoundOption(
      label: 'Fire',
      emoji: '🔥',
      type: SoundType.firewood,
      assetPath: 'sounds/firewood.wav',
    ),
    SoundOption(
      label: 'Cafe',
      emoji: '☕',
      type: SoundType.cafe,
      assetPath: 'sounds/cafe.wav',
    ),
  ];

  /// Check which sound is currently playing
  SoundType get currentSound => _currentSound;
  bool get isPlaying => _currentSound != SoundType.none;

  /// Toggle a sound on/off. Tapping the same sound again stops it.
  Future<void> toggleSound(SoundType type) async {
    if (_currentSound == type) {
      // Already playing this sound — stop it
      await stop();
      return;
    }

    // Find the sound option from the list
    final option = sounds.firstWhere((s) => s.type == type);

    try {
      await _player.stop();
      await _player.play(AssetSource(option.assetPath));
      _player.setReleaseMode(ReleaseMode.loop); // loop forever
      _currentSound = type;
    } catch (e) {
      // If the audio file doesn't exist yet, don't crash
      debugPrint('Could not play ${option.label}: $e');
    }
  }

  /// Stop whatever is playing
  Future<void> stop() async {
    await _player.stop();
    _currentSound = SoundType.none;
  }

  /// Clean up when the app closes
  void dispose() {
    _player.dispose();
  }
}
