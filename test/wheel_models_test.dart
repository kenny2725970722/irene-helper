import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/models/wheel.dart';

void main() {
  group('Wheel', () {
    test('serializes and deserializes, options included', () {
      final wheel = Wheel(
        id: '1',
        name: '今天吃什麼',
        options: ['火鍋', '壽司', '拉麵'],
      );

      final restored = Wheel.fromJson(wheel.toJson());

      expect(restored.id, '1');
      expect(restored.name, '今天吃什麼');
      expect(restored.options, ['火鍋', '壽司', '拉麵']);
    });

    test('survives a real encode/decode round trip through storage', () {
      final wheel = Wheel(id: '2', name: '週末去哪', options: ['看電影', '爬山']);

      final restored = Wheel.fromJson(
        jsonDecode(jsonEncode(wheel.toJson())) as Map<String, dynamic>,
      );

      expect(restored.options, ['看電影', '爬山']);
    });

    test('defaults to no options', () {
      final wheel = Wheel(id: '3', name: '空');
      expect(wheel.options, isEmpty);
    });

    test('survives a wheel with no options list at all', () {
      final restored = Wheel.fromJson({'id': '4', 'name': '壞資料'});
      expect(restored.name, '壞資料');
      expect(restored.options, isEmpty);
    });

    test('coerces non-string options instead of throwing', () {
      final restored = Wheel.fromJson({
        'id': '5',
        'name': '混合',
        'options': [1, 'two', null],
      });
      expect(restored.options, ['1', 'two', 'null']);
    });

    test('survives missing id and name', () {
      final restored = Wheel.fromJson({});
      expect(restored.id, '');
      expect(restored.name, '');
    });
  });
}
