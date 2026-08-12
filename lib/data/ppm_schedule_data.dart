class PpmScheduleRow {
  final String sys;
  final String sub; // sub-system header, e.g. "9.3 Grey Water Harvesting System"
  final String item;
  final String desc;
  final String freq;
  final Map<String, Set<String>> cells; // ISO date -> markers (D/W/M/3M/6M/Y)

  PpmScheduleRow({
    required this.sys,
    this.sub = '',
    required this.item,
    required this.desc,
    required this.freq,
    this.cells = const {},
  });

  factory PpmScheduleRow.fromJson(Map<String, dynamic> json) {
    final cells = <String, Set<String>>{};
    final raw = json['cells'] as Map? ?? {};
    raw.forEach((k, v) {
      cells[k as String] = ((v as List).map((e) => e.toString())).toSet();
    });
    return PpmScheduleRow(
      sys: json['sys'] as String? ?? '',
      sub: json['sub'] as String? ?? '',
      item: json['item'] as String? ?? '',
      desc: json['desc'] as String? ?? '',
      freq: json['freq'] as String? ?? '',
      cells: cells,
    );
  }
}

class PpmScheduleMonth {
  final String month; // '2026-07'
  final String title;
  final List<String> days; // ISO dates of the month
  final List<PpmScheduleRow> rows;

  PpmScheduleMonth({
    required this.month,
    required this.title,
    required this.days,
    required this.rows,
  });

  factory PpmScheduleMonth.fromJson(Map<String, dynamic> json) => PpmScheduleMonth(
    month: json['month'] as String? ?? '',
    title: json['title'] as String? ?? '',
    days: ((json['days'] as List? ?? []).map((e) => e as String)).toList(),
    rows: ((json['rows'] as List? ?? []).map((e) => PpmScheduleRow.fromJson(e as Map<String, dynamic>))).toList(),
  );
}