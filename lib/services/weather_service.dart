import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// One forecast day (tomorrow onward).
class WeatherDay {
  final DateTime date;
  final int weatherCode;
  final double maxTemp;
  final double minTemp;

  const WeatherDay({
    required this.date,
    required this.weatherCode,
    required this.maxTemp,
    required this.minTemp,
  });
}

/// Current conditions in Hong Kong, plus the next few days.
class Weather {
  final double temperature; // current °C
  final double apparent; // feels-like °C
  final double humidity; // %
  final double windSpeed; // km/h
  final int weatherCode; // WMO code
  final double todayMax;
  final double todayMin;
  final List<WeatherDay> forecast;

  const Weather({
    required this.temperature,
    required this.apparent,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.todayMax,
    required this.todayMin,
    required this.forecast,
  });
}

// Central Hong Kong. `forecast_days=6` gives today plus 5 forecast days.
const _weatherUrl = 'https://api.open-meteo.com/v1/forecast'
    '?latitude=22.3193&longitude=114.1694'
    '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m'
    '&daily=weather_code,temperature_2m_max,temperature_2m_min'
    '&timezone=auto&forecast_days=6';

/// Parse an Open-Meteo forecast response into a [Weather].
Weather parseWeather(String jsonBody) {
  final json = jsonDecode(jsonBody) as Map<String, dynamic>;
  final current = json['current'] as Map<String, dynamic>;
  final daily = json['daily'] as Map<String, dynamic>;

  final times = (daily['time'] as List).cast<String>();
  final codes = (daily['weather_code'] as List).cast<num>();
  final maxes = (daily['temperature_2m_max'] as List).cast<num>();
  final mins = (daily['temperature_2m_min'] as List).cast<num>();

  // Element 0 is today — it supplies today's high/low and is not repeated
  // in the forecast strip.
  final forecast = <WeatherDay>[
    for (var i = 1; i < times.length; i++)
      WeatherDay(
        date: DateTime.parse(times[i]),
        weatherCode: codes[i].toInt(),
        maxTemp: maxes[i].toDouble(),
        minTemp: mins[i].toDouble(),
      ),
  ];

  return Weather(
    temperature: (current['temperature_2m'] as num).toDouble(),
    apparent: (current['apparent_temperature'] as num).toDouble(),
    humidity: (current['relative_humidity_2m'] as num).toDouble(),
    windSpeed: (current['wind_speed_10m'] as num).toDouble(),
    weatherCode: (current['weather_code'] as num).toInt(),
    todayMax: maxes.first.toDouble(),
    todayMin: mins.first.toDouble(),
    forecast: forecast,
  );
}

/// Fetch the current Hong Kong weather and forecast.
Future<Weather> fetchWeather() async {
  final resp = await http.get(Uri.parse(_weatherUrl));
  if (resp.statusCode != 200) {
    throw Exception('Open-Meteo request failed: HTTP ${resp.statusCode}');
  }
  return parseWeather(resp.body);
}

/// Short Chinese description for a WMO weather code.
String weatherLabel(int code) {
  if (code == 0) return '晴';
  if (code <= 2) return '多雲';
  if (code == 3) return '陰';
  if (code <= 48) return '有霧';
  if (code <= 57) return '毛毛雨';
  if (code <= 67) return '雨';
  if (code <= 77) return '雪';
  if (code <= 82) return '陣雨';
  if (code <= 86) return '陣雪';
  return '雷暴';
}

/// Icon for a WMO weather code.
IconData weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny;
  if (code <= 2) return Icons.wb_cloudy;
  if (code == 3) return Icons.cloud;
  if (code <= 48) return Icons.foggy;
  if (code <= 57) return Icons.grain;
  if (code <= 67) return Icons.water_drop;
  if (code <= 77) return Icons.ac_unit;
  if (code <= 82) return Icons.grain;
  if (code <= 86) return Icons.ac_unit;
  return Icons.thunderstorm;
}

/// Whether a WMO code means precipitation is falling.
bool weatherIsWet(int code) => code >= 51;
