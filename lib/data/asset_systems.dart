import 'package:flutter/material.dart';

/// Main asset system definitions as shown in the register (CENTRALIX V2).
/// Each map to the 'System' column value in me_assets.json ([full]).
/// [full] empty means the system exists in the register.
class AssetSystem {
  final String short;
  final String full;
  final Color color;
  final IconData icon;

  const AssetSystem({
    required this.short,
    this.full = '',
    required this.color,
    required this.icon,
  });
}

const assetSystems = [
  AssetSystem(short: 'ACMV', full: '1.0 ACMV', color: Color(0xFF0D7377), icon: Icons.ac_unit_rounded),
  AssetSystem(short: 'FIRE FIGHTING', full: '2.0 Fire Fighting system', color: Color(0xFFDC2626), icon: Icons.fire_extinguisher_rounded),
  AssetSystem(short: 'LIFT', full: '3.0 LIFT', color: Color(0xFFCA8A04), icon: Icons.elevator_rounded),
  AssetSystem(short: 'GONDOLA', full: '4.0 Gondola', color: Color(0xFF7C3AED), icon: Icons.construction_rounded),
  AssetSystem(short: 'COLD WATER SYSTEM', full: '5.0 Cold Water Supply', color: Color(0xFF2563EB), icon: Icons.water_drop_rounded),
  AssetSystem(short: 'MECHANICAL CEILING', full: '', color: Color(0xFF9CA3AF), icon: Icons.grid_view_rounded),
  AssetSystem(short: 'KITCHEN EQUIPMENT', full: '7.0 Kitchen Equipment', color: Color(0xFFEA580C), icon: Icons.restaurant_rounded),
  AssetSystem(short: 'IRRIGATION & LANDSCAPE', full: '8.0 Irrigation and landscape', color: Color(0xFF16A34A), icon: Icons.eco_rounded),
  AssetSystem(short: 'OTHER MECHANICAL', full: '9.0 Other Mechanical', color: Color(0xFF64748B), icon: Icons.build_circle_rounded),
];

/// Maps an entry's system string to its AssetSystem (short name / color).
AssetSystem systemFor(String system) {
  for (final s in assetSystems) {
    if (s.full.isNotEmpty && system.startsWith(s.full)) return s;
  }
  return const AssetSystem(short: 'OTHER', color: Color(0xFF94A3B8), icon: Icons.inventory_2_rounded);
}