import 'package:flutter/material.dart';
import '../data/jkr_data.dart';
import '../localization.dart';
import '../widgets/image_viewer.dart';

class SystemScreen extends StatefulWidget {
  final JKRSystemData system;
  final List<JKRSystemData>? allSystems;

  const SystemScreen({super.key, required this.system, this.allSystems});

  @override
  State<SystemScreen> createState() => _SystemScreenState();
}

class _SystemScreenState extends State<SystemScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  late PageController _pageCtrl;
  late List<JKRSystemData> _systems;
  late int _currentIndex;
  Set<int> _expandedTroubleshoot = {};

  @override
  void initState() {
    super.initState();
    _systems = widget.allSystems ?? [widget.system];
    _currentIndex = _systems.indexOf(widget.system);
    if (_currentIndex == -1) _currentIndex = 0;
    _tabCtrl = TabController(length: 3, vsync: this);
    _pageCtrl = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  String _freq(String f, bool eng) {
    switch (f) {
      case 'D': return AppLocalizations.t('freqDaily', eng);
      case 'W': return AppLocalizations.t('freqWeekly', eng);
      case 'M': return AppLocalizations.t('freqMonthly', eng);
      case '3M': return AppLocalizations.t('freq3M', eng);
      case '6M': return AppLocalizations.t('freq6M', eng);
      case 'Y': return AppLocalizations.t('freqYearly', eng);
      case '5Y': return AppLocalizations.t('freq5Y', eng);
      default: return f;
    }
  }

  Color _freqColor(String f) {
    switch (f) {
      case 'D': return Colors.green;
      case 'W': return Colors.teal;
      case 'M': return Colors.blue;
      case '3M': return Colors.indigo;
      case '6M': return Colors.deepPurple;
      case 'Y': return Colors.orange.shade800;
      case '5Y': return Colors.red.shade800;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialSystem = _systems[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text(LanguageProvider.isEnglish(context) ? initialSystem.title : initialSystem.titleBM),
        actions: [_langToggle(context)],
      ),
      body: _systems.length > 1
          ? Column(
              children: [
                _buildTabBar(context, initialSystem),
                Expanded(
                  child: PageView(
                    controller: _pageCtrl,
                    onPageChanged: (i) {
                      setState(() {
                        _currentIndex = i;
                        _expandedTroubleshoot.clear();
                      });
                    },
                    children: _systems.map((s) => _buildPageBody(s)).toList(),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildTabBar(context, initialSystem),
                Expanded(child: _buildPageBody(initialSystem)),
              ],
            ),
      bottomNavigationBar: _systems.length > 1
          ? _buildPageIndicator(context)
          : null,
    );
  }

  Widget _buildTabBar(BuildContext context, JKRSystemData s) {
    final eng = LanguageProvider.isEnglish(context);
    return Container(
      color: Theme.of(context).appBarTheme.backgroundColor ?? const Color(0xFF0D7377),
      child: TabBar(
        controller: _tabCtrl,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        tabs: [
          Tab(icon: const Icon(Icons.image_rounded, size: 18), text: AppLocalizations.t('tabFlow', eng)),
          Tab(icon: const Icon(Icons.build_rounded, size: 18), text: 'PM/CM JKR'),
          Tab(icon: const Icon(Icons.troubleshoot_rounded, size: 18), text: AppLocalizations.t('tabTroubleshoot', eng)),
        ],
      ),
    );
  }

  Widget _buildPageBody(JKRSystemData s) {
    final eng = LanguageProvider.isEnglish(context);
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildFlowTab(s, eng),
        _buildPMCMTab(s, eng),
        _buildTroubleshootTab(s, eng),
      ],
    );
  }

  Widget _buildFlowTab(JKRSystemData s, bool eng) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GestureDetector(
          onTap: () => ImageViewer.show(context, s.imageAsset, s.title),
          child: Hero(
            tag: s.title,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                s.imageAsset,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(child: Text(s.icon, style: const TextStyle(fontSize: 48))),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            AppLocalizations.t('tapToZoom', eng),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          eng ? s.description : s.descriptionBM,
          style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: s.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: s.color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: s.color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.t('sysInfo', eng),
                  style: TextStyle(fontSize: 12, color: s.color.withValues(alpha: 0.8), height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPMCMTab(JKRSystemData s, bool eng) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: s.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.checklist_rounded, size: 18, color: s.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${AppLocalizations.t('jkrSchedule', eng)} â€” ${AppLocalizations.t('refExcel', eng)}',
                  style: TextStyle(fontSize: 12, color: s.color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...s.pmcm.map((section) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.folder_rounded, size: 14, color: s.color),
                ),
                const SizedBox(width: 8),
                Text(eng ? section.title : section.titleBm, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: s.color)),
              ],
            ),
            const SizedBox(height: 8),
            ...section.tasks.map((t) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: _freqColor(t.frequency).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _freqColor(t.frequency).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _freq(t.frequency, eng),
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: _freqColor(t.frequency)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      eng ? t.description : t.descriptionBm,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF37474F), height: 1.3),
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 14),
          ],
        )),
      ],
    );
  }

  Widget _buildTroubleshootTab(JKRSystemData s, bool eng) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 18, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.t('selectProblem', eng),
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade800, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _expandedTroubleshoot = {for (int i = 0; i < s.troubleshoot.length; i++) i};
                  });
                },
                icon: const Icon(Icons.expand_circle_down_rounded, size: 16),
                label: Text(AppLocalizations.t('expAll', eng), style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: s.color,
                  side: BorderSide(color: s.color.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _expandedTroubleshoot.clear());
                },
                icon: const Icon(Icons.unfold_less_rounded, size: 16),
                label: Text(AppLocalizations.t('collAll', eng), style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: s.color,
                  side: BorderSide(color: s.color.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...s.troubleshoot.asMap().entries.map((entry) => _TroubleshootCard(
          key: ValueKey('${s.title}_ts_${entry.key}'),
          t: entry.value,
          color: s.color,
          eng: eng,
          isExpanded: _expandedTroubleshoot.contains(entry.key),
          onToggle: () {
            setState(() {
              if (_expandedTroubleshoot.contains(entry.key)) {
                _expandedTroubleshoot.remove(entry.key);
              } else {
                _expandedTroubleshoot.add(entry.key);
              }
            });
          },
        )),
      ],
    );
  }

  Widget _buildPageIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_systems.length, (i) {
          final isActive = i == _currentIndex;
          return GestureDetector(
            onTap: () {
              _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _langToggle(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
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

class _TroubleshootCard extends StatefulWidget {
  final JKRTroubleshoot t;
  final Color color;
  final bool eng;
  final bool isExpanded;
  final VoidCallback onToggle;

  const _TroubleshootCard({
    super.key,
    required this.t,
    required this.color,
    required this.eng,
    required this.isExpanded,
    required this.onToggle,
  });

  @override
  State<_TroubleshootCard> createState() => _TroubleshootCardState();
}

class _TroubleshootCardState extends State<_TroubleshootCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 250), vsync: this);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    if (widget.isExpanded) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_TroubleshootCard old) {
    super.didUpdateWidget(old);
    if (widget.isExpanded != old.isExpanded) {
      widget.isExpanded ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(t.icon, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.eng ? t.problem : t.problemBm,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: widget.color, height: 1.2),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _anim,
                    builder: (ctx, _) => Transform.rotate(
                      angle: _anim.value * 3.14159,
                      child: Icon(Icons.expand_more_rounded, color: widget.color),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _anim,
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.t('possibleCauses', widget.eng),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red.shade700),
                  ),
                  const SizedBox(height: 4),
                  ...(widget.eng ? t.causes : t.causesBm).map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.circle, size: 5, color: Colors.red.shade300),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c, style: const TextStyle(fontSize: 11.5, color: Color(0xFF37474F), height: 1.3))),
                      ],
                    ),
                  )),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.t('solutions', widget.eng),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.green.shade700),
                  ),
                  const SizedBox(height: 4),
                  ...(widget.eng ? t.solutions : t.solutionsBm).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.green.shade400),
                        const SizedBox(width: 6),
                        Expanded(child: Text(s, style: const TextStyle(fontSize: 11.5, color: Color(0xFF37474F), height: 1.3))),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


