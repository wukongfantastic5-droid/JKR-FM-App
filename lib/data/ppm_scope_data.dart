/// Contract scope of work extracted from PPM Bangunan JKR.xlsx.
///
/// Mirrors the heading hierarchy of the contract sheets: a system (1.0..9.0)
/// holds entries identified by a numeric chain (root code dropped), an
/// optional roman code ('i.', 'ii.', ...) and a title. Checklist rows carry
/// their own frequency marks (D/W/M/3M/6M/Y/2Y/5Y).
class PpmScopeItem {
  final String code; // 'a.', 'b.', ...
  final String text;
  final List<String> freq;

  const PpmScopeItem({required this.code, required this.text, this.freq = const []});

  factory PpmScopeItem.fromJson(Map<String, dynamic> json) => PpmScopeItem(
        code: json['code'] as String? ?? '',
        text: json['text'] as String? ?? '',
        freq: ((json['freq'] as List? ?? []).map((e) => e.toString())).toList(),
      );

  bool hasFreq(String f) => freq.contains(f);
}

class PpmScopeEntry {
  final List<String> nums; // numeric chain, e.g. ['1.1', '1.1.1']
  final String code;       // 'i.', '2.1', 'a.', '' 
  final String title;
  final List<String> freq;
  final List<PpmScopeItem> items;
  final List<String> prose;

  const PpmScopeEntry({
    required this.nums,
    required this.code,
    required this.title,
    this.freq = const [],
    this.items = const [],
    this.prose = const [],
  });

  factory PpmScopeEntry.fromJson(Map<String, dynamic> json) => PpmScopeEntry(
        nums: ((json['nums'] as List? ?? []).map((e) => e.toString())).toList(),
        code: json['code'] as String? ?? '',
        title: json['title'] as String? ?? '',
        freq: ((json['freq'] as List? ?? []).map((e) => e.toString())).toList(),
        items: ((json['items'] as List? ?? [])
            .map((e) => PpmScopeItem.fromJson(e as Map<String, dynamic>))
            .toList()),
        prose: ((json['prose'] as List? ?? []).map((e) => e.toString())).toList(),
      );

  /// Sub-system code used for matching, i.e. the last numeric segment or ''
  /// for root-level entries.
  String get lastNum => nums.isNotEmpty ? nums.last : '';
}

class PpmScope {
  final String sys; // '1.0'
  final String sheet;
  final List<PpmScopeEntry> entries;

  const PpmScope({required this.sys, required this.sheet, this.entries = const []});

  factory PpmScope.fromJson(Map<String, dynamic> json) => PpmScope(
        sys: json['sys'] as String? ?? '',
        sheet: json['sheet'] as String? ?? '',
        entries: ((json['entries'] as List? ?? [])
            .map((e) => PpmScopeEntry.fromJson(e as Map<String, dynamic>))
            .toList()),
      );
}