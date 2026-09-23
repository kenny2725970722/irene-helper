import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/wheel_math.dart';

void main() {
  group('wheel geometry', () {
    test('the pointer sits at 12 o\'clock', () {
      expect(kPointerAngle, -pi / 2);
    });

    test('slice centres are the middle of each slice, not its edge', () {
      expect(sliceCenter(0, 4), closeTo(pi / 4, 1e-12));
      expect(sliceCenter(0, 2), closeTo(pi / 2, 1e-12));
      expect(sliceCenter(2, 3), closeTo(2.5 * 2 * pi / 3, 1e-12));
      // Half a slice in: the edge would be 2 * 2*pi/3.
      expect(sliceCenter(2, 3), isNot(closeTo(2 * 2 * pi / 3, 1e-6)));
    });
  });

  group('spin math', () {
    // The single most important property: whatever the dialog says, the
    // pointer must be covering that slice when the wheel comes to rest.
    test('landing rotation puts the chosen slice under the pointer', () {
      for (var n = 1; n <= 12; n++) {
        for (var i = 0; i < n; i++) {
          expect(
            optionUnderPointer(targetRotationForWinner(i, n), n),
            i,
            reason: 'n=$n winner=$i',
          );
        }
      }
    });

    test('rotationToLandOn lands on the winner from a standstill', () {
      for (var n = 1; n <= 12; n++) {
        for (var i = 0; i < n; i++) {
          expect(
            optionUnderPointer(rotationToLandOn(0, i, n), n),
            i,
            reason: 'n=$n winner=$i',
          );
        }
      }
    });

    test('rotationToLandOn lands on the winner from any resting angle', () {
      const angles = [0.0, 0.3, 1.9, pi, 5.5, 2 * pi, 12.75, -1.4];
      for (final current in angles) {
        for (var n = 1; n <= 8; n++) {
          for (var i = 0; i < n; i++) {
            expect(
              optionUnderPointer(rotationToLandOn(current, i, n), n),
              i,
              reason: 'current=$current n=$n winner=$i',
            );
          }
        }
      }
    });

    test('every spin turns forwards by the full number of turns', () {
      // Tolerance covers the float error of summing ~31 radians onto `current`.
      const eps = 1e-9;
      const angles = [0.0, 1.2, 4.0, 6.5, 20.0];
      for (final current in angles) {
        for (var n = 2; n <= 8; n++) {
          for (var i = 0; i < n; i++) {
            final advanced = rotationToLandOn(current, i, n) - current;
            expect(advanced, greaterThanOrEqualTo(kSpinTurns * 2 * pi - eps));
            expect(advanced, lessThan((kSpinTurns + 1) * 2 * pi + eps));
          }
        }
      }
    });

    test('honours a custom turn count', () {
      final landed = rotationToLandOn(0, 0, 5, turns: 2);
      expect(landed, greaterThanOrEqualTo(2 * 2 * pi));
      expect(landed, lessThan(3 * 2 * pi));
    });

    test('targetRotationForWinner is always in [0, 2*pi)', () {
      for (var n = 1; n <= 12; n++) {
        for (var i = 0; i < n; i++) {
          final r = targetRotationForWinner(i, n);
          expect(r, greaterThanOrEqualTo(0));
          expect(r, lessThan(2 * pi));
        }
      }
    });

    test('an empty wheel does not blow up', () {
      expect(optionUnderPointer(1.234, 0), 0);
    });
  });
}
