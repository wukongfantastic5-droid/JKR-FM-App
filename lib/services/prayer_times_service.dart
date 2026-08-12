import 'dart:convert';
import 'package:http/http.dart' as http;

class PrayerTimes {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;

  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  String getTime(String key) {
    switch (key.toLowerCase()) {
      case 'fajr': return fajr;
      case 'sunrise': return sunrise;
      case 'dhuhr': return dhuhr;
      case 'asr': return asr;
      case 'maghrib': return maghrib;
      case 'isha': return isha;
      default: return '00:00';
    }
  }

  factory PrayerTimes.fromJson(Map<String, dynamic> timings) {
    return PrayerTimes(
      fajr: timings['Fajr'] ?? '05:30',
      sunrise: timings['Sunrise'] ?? '06:45',
      dhuhr: timings['Dhuhr'] ?? '13:00',
      asr: timings['Asr'] ?? '16:15',
      maghrib: timings['Maghrib'] ?? '19:15',
      isha: timings['Isha'] ?? '20:30',
    );
  }

  factory PrayerTimes.kualaLumpur() {
    return const PrayerTimes(
      fajr: '05:30',
      sunrise: '06:45',
      dhuhr: '13:00',
      asr: '16:15',
      maghrib: '19:15',
      isha: '20:30',
    );
  }
}

class PrayerTimesService {
  static PrayerTimes? _cached;
  static DateTime _cachedDate = DateTime(2000);

  static Future<PrayerTimes> getToday() async {
    final now = _malaysiaNow();
    final today = DateTime(now.year, now.month, now.day);

    if (_cached != null && _cachedDate == today) return _cached!;

    try {
      final uri = Uri.parse(
        'https://api.aladhan.com/v1/timingsByCity?city=Kuala+Lumpur&country=Malaysia&method=11',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final timings = data['data']['timings'] as Map<String, dynamic>;
        _cached = PrayerTimes.fromJson(timings);
        _cachedDate = today;
        return _cached!;
      }
    } catch (_) {
    }

    _cached = PrayerTimes.kualaLumpur();
    _cachedDate = today;
    return _cached!;
  }

  static DateTime _malaysiaNow() {
    final utc = DateTime.now().toUtc();
    return utc.add(const Duration(hours: 8));
  }

  static int _toMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String? nextPrayer(PrayerTimes pt) {
    final nowMin = _malaysiaNow().hour * 60 + _malaysiaNow().minute;
    const labels = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];
    final times = [pt.fajr, pt.sunrise, pt.dhuhr, pt.asr, pt.maghrib, pt.isha];

    for (int i = 0; i < times.length; i++) {
      if (_toMinutes(times[i]) > nowMin + 2) return labels[i];
    }
    return labels[0];
  }

  static String? prayerSoonIn15Mins(PrayerTimes pt) {
    final nowMin = _malaysiaNow().hour * 60 + _malaysiaNow().minute;
    const labels = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    final times = [pt.fajr, pt.dhuhr, pt.asr, pt.maghrib, pt.isha];

    for (int i = 0; i < times.length; i++) {
      final prayMin = _toMinutes(times[i]);
      final diff = prayMin - nowMin;
      if (diff >= 14 && diff <= 16) return labels[i];
    }
    return null;
  }
}
