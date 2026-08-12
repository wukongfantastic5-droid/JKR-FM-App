import 'dart:async';
import 'package:flutter/material.dart';
import '../localization.dart';
import '../services/prayer_times_service.dart';

class PrayerBar extends StatefulWidget {
  const PrayerBar({super.key});

  @override
  State<PrayerBar> createState() => PrayerBarState();
}

class PrayerBarState extends State<PrayerBar> {
  DateTime _now = _malaysiaNow();
  PrayerTimes? _pt;
  Timer? _timer;
  Timer? _fetchTimer;

  static DateTime _malaysiaNow() {
    return DateTime.now().toUtc().add(const Duration(hours: 8));
  }

  @override
  void initState() {
    super.initState();
    _fetchTimes();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = _malaysiaNow());
    });
    _fetchTimer = Timer.periodic(const Duration(hours: 6), (_) => _fetchTimes());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fetchTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTimes() async {
    final pt = await PrayerTimesService.getToday();
    if (mounted) setState(() => _pt = pt);
  }

  String _timeStr() {
    final h = _now.hour;
    final m = _now.minute.toString().padLeft(2, '0');
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m';
  }

  String _periodStr() {
    final h = _now.hour;
    return h >= 12 ? 'PM' : 'AM';
  }

  String _dateStr(bool eng) {
    final dow = AppLocalizations.weekday(_now.weekday, eng);
    final mon = AppLocalizations.month(_now.month, eng);
    return '$dow, ${_now.day} $mon ${_now.year}';
  }

  String _prayerLabel(String key, bool eng) {
    return AppLocalizations.t('prayer${key[0].toUpperCase()}${key.substring(1)}', eng);
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final pt = _pt;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final nextKey = pt != null ? PrayerTimesService.nextPrayer(pt) : null;

    List<_PrayerItem> prayers = [];
    if (pt != null) {
      final keys = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
      prayers = keys.map((k) => _PrayerItem(
        key: k,
        label: _prayerLabel(k, eng),
        time: pt.getTime(k),
        isNext: k.toLowerCase() == nextKey,
      )).toList();
    }

    return RepaintBoundary(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.08),
            primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.schedule_rounded, size: 22, color: primary),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _timeStr(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: primary,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          _periodStr(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primary.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 11, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        _dateStr(eng),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              if (nextKey != null && pt != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_active_rounded, size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text(
                        _prayerLabel(nextKey, eng),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          if (prayers.isNotEmpty)
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: prayers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) => _PrayerChipWidget(
                  item: prayers[i],
                  primary: primary,
                ),
              ),
            )
          else
            SizedBox(
              height: 34,
              child: Center(
                child: Text(
                  eng ? 'Loading prayer times...' : 'Memuat waktu solat...',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ),
            ),
        ],
      ),
    ));
  }
}

class _PrayerItem {
  final String key;
  final String label;
  final String time;
  final bool isNext;
  const _PrayerItem({
    required this.key,
    required this.label,
    required this.time,
    required this.isNext,
  });
}

class _PrayerChipWidget extends StatelessWidget {
  final _PrayerItem item;
  final Color primary;

  const _PrayerChipWidget({required this.item, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: item.isNext
            ? primary.withValues(alpha: 0.12)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: item.isNext
            ? Border.all(color: primary, width: 1.2)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.isNext)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.navigate_next_rounded, size: 14, color: primary),
            ),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: item.isNext ? primary : Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            item.time,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: item.isNext ? primary.withValues(alpha: 0.8) : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
