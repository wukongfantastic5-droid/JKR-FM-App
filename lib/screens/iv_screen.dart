import 'package:flutter/material.dart';
import '../data/interview_data.dart';
import '../localization.dart';
import '../widgets/collapsible_card.dart';
import '../widgets/fade_route.dart';

class IVScreen extends StatefulWidget {
  const IVScreen({super.key});

  @override
  State<IVScreen> createState() => _IVScreenState();
}

class _IVScreenState extends State<IVScreen> {
  String _query = '';

  List<FilteredSection> get _filtered {
    if (_query.isEmpty) {
      return interviewData.map((s) => FilteredSection(section: s, items: s.items)).toList();
    }
    final q = _query.toLowerCase();
    return interviewData.map((s) {
      final matching = s.items.where((item) =>
        item.question.toLowerCase().contains(q) || item.answer.toLowerCase().contains(q)
      ).toList();
      final titleMatch = AppLocalizations.translateSectionTitle(s.title, false).toLowerCase().contains(q) ||
                         AppLocalizations.translateSectionTitle(s.title, true).toLowerCase().contains(q);
      return FilteredSection(
        section: s,
        items: titleMatch ? s.items : matching,
      );
    }).where((fs) => fs.items.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isEnglish = LanguageProvider.isEnglish(context);
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('ivTitle', isEnglish)),
        actions: [_langToggle(context, isEnglish)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${interviewData.length} ${AppLocalizations.t('ivSubtitle', isEnglish)} â€¢ ${AppLocalizations.t('ivMethod', isEnglish)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: AppLocalizations.t('searchHintIV', isEnglish),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  style: const TextStyle(fontSize: 14),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ],
            ),
          ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(AppLocalizations.t('noResults', isEnglish), style: TextStyle(color: Colors.grey.shade500)),
              ),
            )
          else
            ...filtered.asMap().entries.map((entry) {
              final i = entry.key;
              final fs = entry.value;
              final section = fs.section;
              final localizedTitle =
                  AppLocalizations.translateSectionTitle(section.title, isEnglish);
              return CollapsibleCard(
                title: localizedTitle,
                icon: section.icon,
                accentColor: _color(section.title),
                badgeCount: fs.items.length,
                onTap: () => Navigator.of(context).push(
                  FadeRoute(page: IVSectionScreen(
                    sections: filtered,
                    initialIndex: i,
                    isEnglish: isEnglish,
                  )),
                ),
                children: fs.items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _color(section.title).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border(
                              left: BorderSide(color: _color(section.title).withValues(alpha: 0.4), width: 3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.help_outline_rounded, size: 14, color: _color(section.title)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.question,
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: _color(section.title), height: 1.35),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade200, width: 1),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_outline_rounded, size: 14, color: Colors.amber.shade600),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.answer,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            }),
        ],
      ),
    );
  }

  Color _color(String title) {
    switch (title) {
      case 'Ceritakan Diri Anda': return const Color(0xFF0288D1);
      case 'Kenapa JKR / Facility Management?': return const Color(0xFF0D7377);
      case 'Soalan HVAC (Aircond & Ventilasi)': return const Color(0xFF00ACC1);
      case 'Fire Fighting System': return const Color(0xFFD32F2F);
      case 'Plumbing & Water Supply': return const Color(0xFF1565C0);
      case 'Lift & Generator': return const Color(0xFFF9A825);
      case 'PM vs CM vs PdM': return const Color(0xFF7B1FA2);
      case 'Root Cause Analysis': return const Color(0xFFE64A19);
      case 'Troubleshooting Situations': return const Color(0xFFC62828);
      case 'Contractor Management': return const Color(0xFF283593);
      case 'KPI & Performance': return const Color(0xFF00897B);
      case 'Tips Temuduga': return const Color(0xFFF57C00);
      case 'Soalan Tambahan': return const Color(0xFF37474F);
      default: return const Color(0xFF0D7377);
    }
  }

  Widget _langToggle(BuildContext context, bool eng) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: () => LanguageProvider.langNotifier(context).value = !eng,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            eng ? 'BM' : 'EN',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class IVSectionScreen extends StatefulWidget {
  final List<FilteredSection> sections;
  final int initialIndex;
  final bool isEnglish;

  const IVSectionScreen({
    super.key,
    required this.sections,
    required this.initialIndex,
    required this.isEnglish,
  });

  @override
  State<IVSectionScreen> createState() => _IVSectionScreenState();
}

class _IVSectionScreenState extends State<IVSectionScreen> {
  late PageController _pageCtrl;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Color _color(String title) {
    switch (title) {
      case 'Ceritakan Diri Anda': return const Color(0xFF0288D1);
      case 'Kenapa JKR / Facility Management?': return const Color(0xFF0D7377);
      case 'Soalan HVAC (Aircond & Ventilasi)': return const Color(0xFF00ACC1);
      case 'Fire Fighting System': return const Color(0xFFD32F2F);
      case 'Plumbing & Water Supply': return const Color(0xFF1565C0);
      case 'Lift & Generator': return const Color(0xFFF9A825);
      case 'PM vs CM vs PdM': return const Color(0xFF7B1FA2);
      case 'Root Cause Analysis': return const Color(0xFFE64A19);
      case 'Troubleshooting Situations': return const Color(0xFFC62828);
      case 'Contractor Management': return const Color(0xFF283593);
      case 'KPI & Performance': return const Color(0xFF00897B);
      case 'Tips Temuduga': return const Color(0xFFF57C00);
      case 'Soalan Tambahan': return const Color(0xFF37474F);
      default: return const Color(0xFF0D7377);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = widget.sections[_currentPage];
    final section = fs.section;
    final color = _color(section.title);
    final title = AppLocalizations.translateSectionTitle(section.title, widget.isEnglish);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: widget.sections.map((fs) {
                final sec = fs.section;
                final c = _color(sec.title);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  children: [
                    Row(
                      children: [
                        Text(sec.icon, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.translateSectionTitle(sec.title, widget.isEnglish),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c, height: 1.2),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${fs.items.length} Q',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(height: 2, color: c.withValues(alpha: 0.2)),
                    const SizedBox(height: 12),
                    ...fs.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border(
                                  left: BorderSide(color: c.withValues(alpha: 0.4), width: 3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.help_outline_rounded, size: 16, color: c),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.question,
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: c, height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200, width: 1),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.lightbulb_outline_rounded, size: 14, color: Colors.amber.shade600),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.answer,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              }).toList(),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.sections.length, (i) {
                return GestureDetector(
                  onTap: () => _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _currentPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage ? color : color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class FilteredSection {
  final InterviewSection section;
  final List<InterviewItem> items;
  const FilteredSection({required this.section, required this.items});
}
