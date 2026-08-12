import 'package:flutter/material.dart';
import '../data/jkr_data.dart';
import '../localization.dart';
import '../widgets/fade_route.dart';
import 'system_screen.dart';

class GerakKerjaScreen extends StatefulWidget {
  const GerakKerjaScreen({super.key});

  @override
  State<GerakKerjaScreen> createState() => _GerakKerjaScreenState();
}

class _GerakKerjaScreenState extends State<GerakKerjaScreen> {
  String _query = '';

  List<JKRSystemData> get _filtered {
    if (_query.isEmpty) return jkrSystems;
    final q = _query.toLowerCase();
    return jkrSystems.where((s) =>
      s.title.toLowerCase().contains(q) || s.titleBM.toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('gkTitle', eng)),
        actions: [_langToggle(context, eng)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              AppLocalizations.t('gkSubtitle', eng),
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3),
            ),
          ),
          TextField(
            decoration: InputDecoration(
              hintText: AppLocalizations.t('searchHint', eng),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            ),
            style: const TextStyle(fontSize: 14),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          if (_filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text(AppLocalizations.t('noResults', eng), style: TextStyle(color: Colors.grey.shade500)),
              ),
            )
          else
            ..._filtered.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SystemCard(
                icon: _iconFor(s.title),
                title: eng ? s.title : s.titleBM,
                subtitle: '${AppLocalizations.t('tabFlow', eng)} â€¢ ${s.pmcm.length} ${eng ? 'PM areas' : 'kawasan PM'} â€¢ ${s.troubleshoot.length} ${eng ? 'troubleshoots' : 'penyelesaian'}',
                color: s.color,
                onTap: () => Navigator.of(context).push(
                  FadeRoute(page: SystemScreen(system: s, allSystems: jkrSystems)),
                ),
              ),
            )),
        ],
      ),
    );
  }

  IconData _iconFor(String title) {
    if (title.contains('HVAC')) return Icons.ac_unit_rounded;
    if (title.contains('Fire')) return Icons.fire_extinguisher_rounded;
    if (title.contains('Water') || title.contains('Plumbing')) return Icons.water_drop_rounded;
    if (title.contains('Lift')) return Icons.elevator_rounded;
    if (title.contains('Gondola')) return Icons.construction_rounded;
    if (title.contains('Kitchen')) return Icons.restaurant_rounded;
    if (title.contains('Irrigation') || title.contains('Landscape')) return Icons.yard_rounded;
    if (title.contains('Other') || title.contains('Mechanical')) return Icons.handyman_rounded;
    return Icons.build_rounded;
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

class _SystemCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SystemCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color, height: 1.2)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.3)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
