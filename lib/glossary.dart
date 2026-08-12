import 'package:flutter/material.dart';
import 'localization.dart';

class GlossaryEntry {
  final String term;
  final String full;
  final String category;
  const GlossaryEntry(this.term, this.full, this.category);
}

const List<GlossaryEntry> glossary = [
  GlossaryEntry('ACB', 'Air Circuit Breaker', 'Electrical'),
  GlossaryEntry('ACSU', 'Air Cooled Split Unit', 'ACMV'),
  GlossaryEntry('AHU', 'Air Handling Unit', 'ACMV'),
  GlossaryEntry('CHWP', 'Chilled Water Pump', 'ACMV'),
  GlossaryEntry('DB', 'Distribution Board', 'Electrical'),
  GlossaryEntry('DCW', 'Domestic Cold Water', 'Plumbing'),
  GlossaryEntry('EL', 'Electronic (Air Filter)', 'ACMV'),
  GlossaryEntry('FCU', 'Fan Coil Unit', 'ACMV'),
  GlossaryEntry('FM 200', 'Fire Suppression System', 'Fire Fighting'),
  GlossaryEntry('HV', 'High Voltage', 'Electrical'),
  GlossaryEntry('LV', 'Low Voltage', 'Electrical'),
  GlossaryEntry('MSB', 'Main Switch Board', 'Electrical'),
  GlossaryEntry('PABX', 'Private Automatic Branch Exchange', 'ICT'),
  GlossaryEntry('PAC', 'Package Air Conditioner', 'ACMV'),
  GlossaryEntry('PV', 'Photovoltaic', 'Electrical'),
  GlossaryEntry('RMU', 'Ring Main Unit', 'Electrical'),
  GlossaryEntry('S/S/O', 'Switch Socket Outlet', 'Electrical'),
  GlossaryEntry('SMATV', 'Satellite Master Antenna Television', 'ICT'),
  GlossaryEntry('SSB', 'Sub Switch Board', 'Electrical'),
  GlossaryEntry('TX', 'Transformer', 'Electrical'),
  GlossaryEntry('UPS', 'Uninterruptible Power Supply', 'Electrical'),
  GlossaryEntry('VAV', 'Variable Air Volume', 'ACMV'),
  GlossaryEntry('VESDA', 'Very Early Smoke Detection Apparatus', 'Fire Fighting'),
  GlossaryEntry('VRF', 'Variable Refrigerant Flow', 'ACMV'),
  GlossaryEntry('VSD', 'Variable Speed Drive', 'ACMV'),
  GlossaryEntry('WC', 'Water Closet', 'Plumbing'),
];

final _catOrder = ['ACMV', 'Electrical', 'Plumbing', 'Fire Fighting', 'ICT'];
final _catColors = {
  'ACMV': Color(0xFF0D7377),
  'Electrical': Color(0xFFE64A19),
  'Plumbing': Color(0xFF1565C0),
  'Fire Fighting': Color(0xFFDC2626),
  'ICT': Color(0xFF7B1FA2),
};

void showGlossary(BuildContext context) {
  final eng = LanguageProvider.isEnglish(context);
  final grouped = <String, List<GlossaryEntry>>{};
  for (final entry in glossary) {
    grouped.putIfAbsent(entry.category, () => []).add(entry);
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D7377).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF0D7377), size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  eng ? 'Glossary of Terms' : 'Glosari Istilah',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              eng ? 'Common abbreviations used in floor plans' : 'Singkatan biasa digunakan dalam pelan lantai',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            ..._catOrder.where((cat) => grouped.containsKey(cat)).map((cat) {
              final entries = grouped[cat]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(
                            color: _catColors[cat]!.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          eng ? cat : _catMalay(cat),
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: _catColors[cat],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...entries.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _catColors[cat]!.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _catColors[cat]!.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _catColors[cat]!.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              e.term,
                              style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: _catColors[cat],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              e.full,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    ),
  );
}

String _catMalay(String cat) {
  switch (cat) {
    case 'ACMV': return 'ACMV (Pendingin & Mekanikal)';
    case 'Electrical': return 'Elektrik';
    case 'Plumbing': return 'Paip';
    case 'Fire Fighting': return 'Kebakaran';
    case 'ICT': return 'ICT';
    default: return cat;
  }
}
