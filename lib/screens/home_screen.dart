import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../gold_chart.dart';
import '../models/gold_price_point.dart';
import '../services/gold_price_service.dart';
import '../services/storage_service.dart';
import '../services/weather_service.dart';

/// The home screen — current Luk Fook gold price and the Hong Kong weather.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoldPrice? _goldPrice;
  String? _goldError;
  List<GoldPricePoint> _goldHistory = [];
  Weather? _weather;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _loadGoldHistory();
    _loadGoldPrice();
    _loadWeather();
  }

  Future<void> _loadGoldHistory() async {
    // A value written by an older build, or edited by hand, must not break the
    // screen on launch — an empty history is the right degradation.
    try {
      final data = await StorageService.loadList('gold_price_history');
      if (!mounted) return;
      setState(() => _goldHistory = data.map(GoldPricePoint.fromJson).toList());
    } catch (_) {
      if (!mounted) return;
      setState(() => _goldHistory = []);
    }
  }

  Future<void> _loadGoldPrice() async {
    try {
      final price = await fetchGoldPrice();
      if (!mounted) return;
      setState(() {
        _goldPrice = price;
        _goldError = null;
      });
      await _recordGoldPoint(price);
    } catch (_) {
      if (!mounted) return;
      setState(() => _goldError = 'failed');
    }
  }

  /// Add today's reading to the local price history — the Luk Fook endpoint
  /// only ever returns the current price, so a trend has to be accumulated
  /// here over days. A malformed price or a storage failure must not blank out
  /// the price card, so failures are swallowed.
  Future<void> _recordGoldPoint(GoldPrice price) async {
    try {
      final point = GoldPricePoint(
        date: DateTime.now(),
        sell: goldPriceValue(price.sellPrice),
        buy: goldPriceValue(price.buyPrice),
      );
      // Re-read rather than appending to the in-memory list: the fetch can
      // resolve before the history has loaded, and writing from a still-empty
      // list would wipe every day accumulated so far.
      final stored = await StorageService.loadList('gold_price_history');
      final history = recordPoint(
        stored.map(GoldPricePoint.fromJson).toList(),
        point,
      );
      await StorageService.saveList('gold_price_history', history);
      if (!mounted) return;
      setState(() => _goldHistory = history);
    } catch (_) {
      // The price itself still displays.
    }
  }

  Future<void> _loadWeather() async {
    try {
      final weather = await fetchWeather();
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _weatherError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _weatherError = 'failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = _weather;
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏠 Home'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact();
          await Future.wait([_loadGoldPrice(), _loadWeather()]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '💰 金價 9999/999金(克)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildGoldPriceCard(),
            const SizedBox(height: 12),
            _buildGoldTrendCard(),

            const SizedBox(height: 24),

            const Text(
              '🌤️ 香港天氣',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildWeatherCard(),
            if (weather != null) ...[
              const SizedBox(height: 12),
              _buildForecastCard(weather),
            ],
          ],
        ),
      ),
    );
  }

  // ── Gold price ──

  Widget _buildGoldPriceCard() {
    // Loading (no price and no error yet)
    if (_goldPrice == null && _goldError == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Error
    if (_goldError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Expanded(child: Text('金價載入失敗', style: TextStyle(color: Colors.grey.shade600))),
              TextButton(
                onPressed: () {
                  setState(() => _goldError = null);
                  _loadGoldPrice();
                },
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    // Success
    final price = _goldPrice!;
    // The background is pinned light in both themes, so the text has to be
    // pinned dark too — the theme's onSurface is near-white in dark mode.
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _goldInfo('賣出 (HKD)', 'HK\$${price.sellPrice}'),
            _goldInfo('買入 (HKD)', 'HK\$${price.buyPrice}'),
          ],
        ),
      ),
    );
  }

  Widget _goldInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ],
    );
  }

  // ── Gold trend ──

  Widget _buildGoldTrendCard() {
    if (_goldHistory.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              '還沒有紀錄，明天回來看趨勢',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
        ),
      );
    }

    // The footer describes the chart's own vertical extent, so it spans both
    // series — labelling only the sell range would disagree with the axis.
    final sells = _goldHistory.map((p) => p.sell);
    final buys = _goldHistory.map((p) => p.buy);
    final low = min(sells.reduce(min), buys.reduce(min));
    final high = max(sells.reduce(max), buys.reduce(max));
    final money = NumberFormat('#,##0.00');
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📈 近 30 天走勢（克）',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                Text(
                  '${_goldHistory.length} 天',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              width: double.infinity,
              child: CustomPaint(
                painter: GoldChartPainter(
                  points: _goldHistory,
                  days: 30,
                  today: DateTime.now(),
                  sellColor: goldSellLineColor,
                  buyColor: goldBuyLineColor,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _goldLegendItem(goldSellLineColor, '賣出'),
                const SizedBox(width: 16),
                _goldLegendItem(goldBuyLineColor, '買入'),
              ],
            ),
            const SizedBox(height: 6),
            if (_goldHistory.length < 2)
              Text(
                '從今天開始累積，明天就有第一段線',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '低 ${money.format(low)}　高 ${money.format(high)}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${DateFormat('M/d').format(_goldHistory.first.date)}'
                    ' – ${DateFormat('M/d').format(_goldHistory.last.date)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _goldLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  // ── Weather ──

  Widget _buildWeatherCard() {
    // Loading (no weather and no error yet)
    if (_weather == null && _weatherError == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Error
    if (_weatherError != null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Expanded(child: Text('天氣載入失敗', style: TextStyle(color: Colors.grey.shade600))),
              TextButton(
                onPressed: () {
                  setState(() => _weatherError = null);
                  _loadWeather();
                },
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    // Success — the gradient card: temperature, decorative art, and a
    // bottom row of grey high/low plus the location and condition.
    final weather = _weather!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 184,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.teal.shade500, Colors.teal.shade900],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: -12,
              child: SizedBox(
                width: 130,
                height: 120,
                child: CustomPaint(painter: _WeatherArtPainter(weather.weatherCode)),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weather.temperature.round()}°',
                  style: const TextStyle(fontSize: 48, color: Colors.white, height: 1.1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'H:${weather.todayMax.round()}°  L:${weather.todayMin.round()}°',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text('香港', style: TextStyle(fontSize: 15, color: Colors.white)),
                      ],
                    ),
                    Text(
                      weatherLabel(weather.weatherCode),
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastCard(Weather weather) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            for (final day in weather.forecast)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      DateFormat('EEE').format(day.date),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Icon(weatherIcon(day.weatherCode), size: 20, color: Colors.teal.shade600),
                    const SizedBox(height: 6),
                    Text(
                      '${day.maxTemp.round()}°',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${day.minTemp.round()}°',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Decorative weather art for the card — a cloud, with a sun behind it when
/// clear, raindrops when wet, and a lightning bolt in a thunderstorm.
class _WeatherArtPainter extends CustomPainter {
  final int weatherCode;

  const _WeatherArtPainter(this.weatherCode);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w * 0.5;
    final cy = h * 0.5;

    if (weatherCode <= 2) {
      canvas.drawCircle(
        Offset(w * 0.74, h * 0.20),
        h * 0.15,
        Paint()..color = const Color(0xFFFFC107),
      );
    }

    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.92);
    canvas.drawCircle(Offset(cx - w * 0.17, cy + h * 0.02), h * 0.16, cloud);
    canvas.drawCircle(Offset(cx + w * 0.01, cy - h * 0.08), h * 0.21, cloud);
    canvas.drawCircle(Offset(cx + w * 0.19, cy + h * 0.02), h * 0.15, cloud);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - w * 0.33, cy + h * 0.01, w * 0.66, h * 0.17),
        Radius.circular(h * 0.085),
      ),
      cloud,
    );

    if (weatherIsWet(weatherCode)) {
      final drop = Paint()..color = const Color(0xFF75D6FF);
      for (final dx in [-0.20, 0.0, 0.20]) {
        canvas.drawCircle(Offset(cx + w * dx, cy + h * 0.28), h * 0.032, drop);
      }
    }

    if (weatherCode >= 95) {
      final bolt = Path()
        ..moveTo(cx - w * 0.02, cy + h * 0.20)
        ..lineTo(cx - w * 0.13, cy + h * 0.42)
        ..lineTo(cx - w * 0.02, cy + h * 0.42)
        ..lineTo(cx - w * 0.10, cy + h * 0.58)
        ..lineTo(cx + w * 0.12, cy + h * 0.36)
        ..lineTo(cx + w * 0.01, cy + h * 0.36)
        ..close();
      canvas.drawPath(bolt, Paint()..color = const Color(0xFFFFCE31));
    }
  }

  @override
  bool shouldRepaint(covariant _WeatherArtPainter oldDelegate) =>
      oldDelegate.weatherCode != weatherCode;
}
