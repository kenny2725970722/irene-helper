import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple wrapper around SharedPreferences for saving/loading JSON lists.
class StorageService {
  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  // ── Save a list of JSON-serializable objects or plain maps ──
  static Future<void> saveList(String key, List<dynamic> items) async {
    final prefs = await _prefs;
    final jsonList = items.map((i) {
      if (i is Map) return i;           // plain map — use directly
      return (i as dynamic).toJson();   // model object — call toJson()
    }).toList();
    await prefs.setString(key, jsonEncode(jsonList));
  }

  // ── Load a list (returns raw JSON maps) ──
  static Future<List<Map<String, dynamic>>> loadList(String key) async {
    final prefs = await _prefs;
    final jsonString = prefs.getString(key);
    if (jsonString == null) return [];
    final list = jsonDecode(jsonString) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  // ── Simple key-value storage ──
  static Future<void> saveInt(String key, int value) async {
    final prefs = await _prefs;
    await prefs.setInt(key, value);
  }

  static Future<int> loadInt(String key, {int defaultValue = 0}) async {
    final prefs = await _prefs;
    return prefs.getInt(key) ?? defaultValue;
  }

  static Future<void> saveString(String key, String value) async {
    final prefs = await _prefs;
    await prefs.setString(key, value);
  }

  static Future<String> loadString(String key, {String defaultValue = ''}) async {
    final prefs = await _prefs;
    return prefs.getString(key) ?? defaultValue;
  }
}
