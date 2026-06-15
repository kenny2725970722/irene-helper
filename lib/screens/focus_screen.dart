import 'dart:async';
import 'package:flutter/material.dart';
import '../sound_manager.dart';
import '../plant_painter.dart';

/// The main timer screen — where the user spends all their time.
///
/// A StatefulWidget because the timer CHANGES every second.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with WidgetsBindingObserver {
  // WidgetsBindingObserver is a MIXIN — it adds the ability to
  // detect when the app goes to background or comes back.
  // ── CUSTOMIZABLE DURATIONS (changeable by user) ──
  int _focusSeconds = 25 * 60; // 25 minutes default
  int _breakSeconds = 5 * 60; // 5 minutes default

  // ── STATE (changes while the app runs) ──
  int _secondsRemaining = 25 * 60; // matches _focusSeconds
  bool _isRunning = false;
  bool _isFocusMode = true;
  Timer? _timer;
  final SoundManager _soundManager = SoundManager();
  SoundType _selectedSound = SoundType.none; // which sound is highlighted
  bool _isWithered = false; // plant withers when user abandons focus
  DateTime? _backgroundedAt; // when the user left the app

  /// How much the plant has grown (0.0 = seed, 1.0 = full bloom).
  ///
  /// During focus mode: grows as time passes.
  /// During break mode: stays fully grown (your reward!).
  double get _growth {
    if (_isWithered) return 0.0; // withered = back to nothing
    if (!_isFocusMode) return 1.0; // fully grown during break
    final totalFocus = _focusSeconds;
    final elapsed = totalFocus - _secondsRemaining;
    return (elapsed / totalFocus).clamp(0.0, 1.0);
  }

  // ── LIFECYCLE ──

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // start listening
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // stop listening
    _timer?.cancel();
    _soundManager.dispose();
    super.dispose();
  }

  /// Called automatically when the app goes to background or comes back.
  ///
  /// If the user left during a running focus session, and enough real time
  /// has passed, the plant withers.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // User left the app — record when
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // User came back — check if they abandoned focus
      if (_isRunning && _isFocusMode && _backgroundedAt != null) {
        final awaySeconds =
            DateTime.now().difference(_backgroundedAt!).inSeconds;
        // If they were gone longer than what was left, they abandoned
        if (awaySeconds >= _secondsRemaining + 10) {
          // +10 sec grace period
          _timer?.cancel();
          setState(() {
            _isWithered = true;
            _isRunning = false;
          });
        }
      }
      _backgroundedAt = null;
    }
  }

  // ── TIMER FUNCTIONS ──

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_secondsRemaining > 0) {
          setState(() {
            _secondsRemaining--;
          });
        } else {
          // Timer finished — auto-switch modes
          timer.cancel();
          setState(() {
            _isRunning = false;
            _isFocusMode = !_isFocusMode;
            _secondsRemaining =
                _isFocusMode ? _focusSeconds : _breakSeconds;
          });
        }
      },
    );
    setState(() {
      _isRunning = true;
      _isWithered = false; // fresh start = revive the plant
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isWithered = false; // revive the plant!
      _secondsRemaining = _isFocusMode ? _focusSeconds : _breakSeconds;
    });
  }

  void _toggleMode() {
    _timer?.cancel();
    setState(() {
      _isFocusMode = !_isFocusMode;
      _isRunning = false;
      _secondsRemaining = _isFocusMode ? _focusSeconds : _breakSeconds;
    });
  }

  // ── SETTINGS ──

  /// Shows a bottom sheet where the user can adjust focus & break durations.
  void _showSettings() {
    // Local copies so the sliders work before "Apply" is pressed
    int tempFocus = _focusSeconds ~/ 60;
    int tempBreak = _breakSeconds ~/ 60;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '⚙️ Timer Settings',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // ── FOCUS DURATION ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🎯 Focus', style: TextStyle(fontSize: 16)),
                      Text(
                        '$tempFocus min',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: tempFocus.toDouble(),
                    min: 1,
                    max: 60,
                    divisions: 59,
                    activeColor: Colors.green,
                    label: '$tempFocus min',
                    onChanged: (val) {
                      setModalState(() {
                        tempFocus = val.round();
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── BREAK DURATION ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('☕ Break', style: TextStyle(fontSize: 16)),
                      Text(
                        '$tempBreak min',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: tempBreak.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    activeColor: Colors.blue,
                    label: '$tempBreak min',
                    onChanged: (val) {
                      setModalState(() {
                        tempBreak = val.round();
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // ── APPLY BUTTON ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        setState(() {
                          _focusSeconds = tempFocus * 60;
                          _breakSeconds = tempBreak * 60;
                          // Reset the timer to the new durations
                          _secondsRemaining = _isFocusMode
                              ? _focusSeconds
                              : _breakSeconds;
                          _isRunning = false;
                          _timer?.cancel();
                          _isWithered = false;
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Apply',
                          style: TextStyle(fontSize: 16)),
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

  // ── HELPERS ──

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ── BUILD (the screen) ──

  @override
  Widget build(BuildContext context) {
    final themeColor = _isFocusMode ? Colors.green : Colors.blue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🍅 Pomodoro Plant'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Set timer durations',
            onPressed: _showSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
            children: [
              const SizedBox(height: 16),

              // ── MODE LABEL ──
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                decoration: BoxDecoration(
                  color: themeColor.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: themeColor.shade200, width: 2),
                ),
                child: Text(
                  _isFocusMode ? '🎯 FOCUS TIME' : '☕ BREAK TIME',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: themeColor.shade700,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── COUNTDOWN DISPLAY ──
              Text(
                _formatTime(_secondsRemaining),
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 4),

              // ── STATUS ──
              Text(
                _isRunning ? '▶ Running' : '⏸ Paused',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 12),

              // ── THE PLANT ──
              SizedBox(
                height: 170,
                width: 160,
                child: CustomPaint(
                  painter: PlantPainter(
                    growth: _growth,
                    isWithered: _isWithered,
                  ),
                  size: Size.infinite,
                ),
              ),

              const SizedBox(height: 12),

              // ── AMBIENT SOUND SELECTOR ──
              Text(
                'Ambient Sound',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: SoundManager.sounds.map((sound) {
                  final isSelected = _selectedSound == sound.type;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          // Toggle: tap same sound = deselect
                          if (_selectedSound == sound.type) {
                            _selectedSound = SoundType.none;
                          } else {
                            _selectedSound = sound.type;
                          }
                        });
                        _soundManager.toggleSound(sound.type);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.green.shade100
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.green.shade400
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(sound.emoji, style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(
                              sound.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── CONTROL BUTTONS ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // START / PAUSE
                  _ControlButton(
                    onTap: _isRunning ? _pauseTimer : _startTimer,
                    icon: _isRunning ? Icons.pause : Icons.play_arrow,
                    label: _isRunning ? 'Pause' : 'Start',
                    color: themeColor,
                    isPrimary: true,
                  ),
                  const SizedBox(width: 12),
                  // RESET
                  _ControlButton(
                    onTap: _resetTimer,
                    icon: Icons.refresh,
                    label: 'Reset',
                    color: Colors.grey,
                    isPrimary: false,
                  ),
                  const SizedBox(width: 12),
                  // SWITCH MODE
                  _ControlButton(
                    onTap: _toggleMode,
                    icon: Icons.swap_horiz,
                    label: _isFocusMode ? 'Break' : 'Focus',
                    color: Colors.grey,
                    isPrimary: false,
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

/// A reusable button widget — created once, used 3 times.
/// This is how you avoid repeating code!
class _ControlButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final MaterialColor color; // MaterialColor has .shade50, .shade700, etc.
  final bool isPrimary;

  const _ControlButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.color,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? color.shade700 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isPrimary ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
