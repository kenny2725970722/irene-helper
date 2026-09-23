import 'dart:math';

/// Angle the fixed pointer sits at: straight up (12 o'clock).
///
/// Canvas angles start at 3 o'clock and grow clockwise, so up is -pi/2.
const double kPointerAngle = -pi / 2;

/// Whole turns added to every spin so it feels like a spin, not a snap.
const int kSpinTurns = 5;

/// Angular width of one slice when there are [n] options.
double sliceAngle(int n) => 2 * pi / n;

/// Angle of the *centre* of slice [i] — not its leading edge.
///
/// The half-slice offset is what makes the pointer rest in the middle of a
/// slice instead of on a boundary, so the spoken result always matches what
/// the pointer is covering.
double sliceCenter(int i, int n) => (i + 0.5) * sliceAngle(n);

/// Rotation, in `[0, 2*pi)`, that brings slice [winner] under the pointer.
///
/// A canvas feature at angle `a` is drawn at `a + rotation` once the wheel is
/// rotated by `rotation`, so we need `sliceCenter + rotation == kPointerAngle`.
double targetRotationForWinner(int winner, int n) =>
    (kPointerAngle - sliceCenter(winner, n)) % (2 * pi);

/// Inverse of [targetRotationForWinner]: which slice the pointer covers when
/// the wheel is rotated by [rotation].
int optionUnderPointer(double rotation, int n) {
  if (n <= 0) return 0;
  final beta = (kPointerAngle - rotation) % (2 * pi);
  return (beta / sliceAngle(n)).floor().clamp(0, n - 1);
}

/// Full rotation to animate to, starting from [current].
///
/// Always rotates forwards: [current] first drops to its equivalent in
/// `[0, 2*pi)`, then [turns] whole turns and a non-negative remainder are
/// added. Using a raw `target - current` instead would sometimes spin the
/// wheel backwards into the wrong slice.
double rotationToLandOn(
  double current,
  int winner,
  int n, {
  int turns = kSpinTurns,
}) {
  final target = targetRotationForWinner(winner, n);
  final delta = (target - (current % (2 * pi))) % (2 * pi);
  return current + turns * 2 * pi + delta;
}
