import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_app/services/weather_service.dart';

void main() {
  group('parseWeather', () {
    const jsonBody = '''
    {
      "latitude": 22.32,
      "longitude": 114.17,
      "timezone": "Asia/Hong_Kong",
      "current": {
        "time": "2026-09-23T14:45",
        "interval": 900,
        "temperature_2m": 29.3,
        "relative_humidity_2m": 67,
        "apparent_temperature": 33.1,
        "weather_code": 1,
        "wind_speed_10m": 12.6
      },
      "daily": {
        "time": ["2026-09-23", "2026-09-24", "2026-09-25", "2026-09-26", "2026-09-27", "2026-09-28"],
        "weather_code": [53, 61, 2, 51, 95, 0],
        "temperature_2m_max": [29.7, 29.4, 30.1, 31.4, 32.6, 31.0],
        "temperature_2m_min": [25.4, 25.2, 24.6, 24.2, 25.4, 26.1]
      }
    }
    ''';

    test('parses current conditions', () {
      final w = parseWeather(jsonBody);

      expect(w.temperature, 29.3);
      expect(w.apparent, 33.1);
      expect(w.humidity, 67);
      expect(w.windSpeed, 12.6);
      expect(w.weatherCode, 1);
    });

    test('takes today high/low from the first daily entry', () {
      final w = parseWeather(jsonBody);

      expect(w.todayMax, 29.7);
      expect(w.todayMin, 25.4);
    });

    test('forecast starts tomorrow and drops today', () {
      final w = parseWeather(jsonBody);

      expect(w.forecast, hasLength(5));
      expect(w.forecast.first.date, DateTime.parse('2026-09-24'));
      expect(w.forecast.last.date, DateTime.parse('2026-09-28'));
      expect(w.forecast.first.weatherCode, 61);
      expect(w.forecast.first.maxTemp, 29.4);
      expect(w.forecast.first.minTemp, 25.2);
    });
  });

  group('weatherLabel', () {
    test('maps WMO codes to Chinese descriptions', () {
      expect(weatherLabel(0), '晴');
      expect(weatherLabel(1), '多雲');
      expect(weatherLabel(3), '陰');
      expect(weatherLabel(45), '有霧');
      expect(weatherLabel(53), '毛毛雨');
      expect(weatherLabel(63), '雨');
      expect(weatherLabel(75), '雪');
      expect(weatherLabel(81), '陣雨');
      expect(weatherLabel(95), '雷暴');
    });
  });

  group('weatherIcon', () {
    test('maps WMO codes to icons', () {
      expect(weatherIcon(0), Icons.wb_sunny);
      expect(weatherIcon(2), Icons.wb_cloudy);
      expect(weatherIcon(3), Icons.cloud);
      expect(weatherIcon(45), Icons.foggy);
      expect(weatherIcon(61), Icons.water_drop);
      expect(weatherIcon(75), Icons.ac_unit);
      expect(weatherIcon(95), Icons.thunderstorm);
    });
  });

  group('weatherIsWet', () {
    test('is false for dry codes and true from drizzle upward', () {
      expect(weatherIsWet(0), isFalse);
      expect(weatherIsWet(3), isFalse);
      expect(weatherIsWet(48), isFalse);
      expect(weatherIsWet(51), isTrue);
      expect(weatherIsWet(95), isTrue);
    });
  });
}
