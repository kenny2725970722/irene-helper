import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/wheel.dart';
import '../wheel_math.dart';
import '../wheel_painter.dart';
import 'wheel_edit_screen.dart';

class WheelSpinScreen extends StatefulWidget {
  final Wheel wheel;

  /// Fires after the wheel is edited from here, so the owner can persist it.
  final ValueChanged<Wheel>? onChanged;

  const WheelSpinScreen({super.key, required this.wheel, this.onChanged});

  @override
  State<WheelSpinScreen> createState() => _WheelSpinScreenState();
}

class _WheelSpinScreenState extends State<WheelSpinScreen>
    with SingleTickerProviderStateMixin {
  late Wheel _wheel;
  late final AnimationController _controller;
  late final CurvedAnimation _curved;
  final Random _random = Random();

  /// Where the wheel currently rests, and the endpoints of the live spin.
  double _rotation = 0;
  double _startRotation = 0;
  double _endRotation = 0;

  int _pendingWinner = 0;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _wheel = widget.wheel;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..addStatusListener(_onStatus);
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    setState(() {
      _rotation = _endRotation;
      _spinning = false;
    });
    _showResult();
  }

  void _spin() {
    final n = _wheel.options.length;
    if (n == 0 || _spinning) return;
    HapticFeedback.mediumImpact();
    final winner = _random.nextInt(n);
    setState(() {
      _spinning = true;
      _pendingWinner = winner;
      _startRotation = _rotation % (2 * pi);
      _endRotation = rotationToLandOn(_startRotation, winner, n);
    });
    _controller.forward(from: 0);
  }

  void _showResult() {
    if (_pendingWinner < 0 || _pendingWinner >= _wheel.options.length) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 結果'),
        content: Text(
          _wheel.options[_pendingWinner],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit() async {
    final edited = await Navigator.of(context).push<Wheel>(
      MaterialPageRoute(builder: (_) => WheelEditScreen(wheel: _wheel)),
    );
    if (edited == null || !mounted) return;
    setState(() => _wheel = edited);
    widget.onChanged?.call(edited);
  }

  @override
  Widget build(BuildContext context) {
    final hasOptions = _wheel.options.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('🎡 ${_wheel.name}'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: '編輯轉盤',
            onPressed: _spinning ? null : _edit,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, c) {
                  const pointerHeight = 46.0;
                  final size = min(c.maxWidth, c.maxHeight - pointerHeight) - 16;
                  if (size <= 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: pointerHeight),
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedBuilder(
                          animation: _curved,
                          builder: (context, child) => Transform.rotate(
                            angle: _startRotation +
                                (_endRotation - _startRotation) * _curved.value,
                            child: child,
                          ),
                          child: CustomPaint(
                            size: Size.square(size),
                            painter: WheelPainter(options: _wheel.options),
                          ),
                        ),
                        // Sibling of the rotating subtree, never a child of it.
                        Positioned(
                          top: -pointerHeight,
                          child: Icon(
                            Icons.arrow_drop_down,
                            size: 48,
                            // Deliberately not a palette colour, so the
                            // pointer stays tellable from every slice.
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              children: [
                if (!hasOptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '尚無選項，請先編輯',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (hasOptions && !_spinning) ? _spin : null,
                    icon: const Icon(Icons.casino),
                    label: Text(_spinning ? '轉動中…' : '轉！'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
