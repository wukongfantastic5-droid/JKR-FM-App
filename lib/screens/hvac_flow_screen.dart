import 'package:flutter/material.dart';
import '../localization.dart';
import '../widgets/image_viewer.dart';

class HVACFlowScreen extends StatelessWidget {
  const HVACFlowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isEnglish = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(isEnglish ? 'HVAC System Flow' : 'Aliran Sistem HVAC'),
        actions: [_langToggle(context, isEnglish)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _SectionHeader(
            icon: Icons.image_rounded,
            title: isEnglish ? 'System Overview' : 'Gambaran Sistem',
            color: const Color(0xFF00ACC1),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => ImageViewer.show(context, 'assets/images/HVAC system.jpg', 'hvac_diagram'),
            child: Hero(
              tag: 'hvac_diagram',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/images/HVAC system.jpg',
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00ACC1).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_not_supported_rounded, size: 40, color: Colors.grey),
                          SizedBox(height: 4),
                          Text('HVAC system diagram', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              isEnglish ? 'Tap image to enlarge • Scroll to zoom' : 'Tekan gambar untuk besarkan • Skrol untuk zum',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.router_rounded,
            title: isEnglish ? 'How HVAC Works' : 'Cara HVAC Berfungsi',
            color: const Color(0xFF00ACC1),
          ),
          const SizedBox(height: 10),
          _FlowStep(
            number: 1,
            icon: Icons.ac_unit_rounded,
            title: isEnglish ? 'Chiller Produces Chilled Water' : 'Chiller Menghasilkan Air Sejuk',
            description: isEnglish
                ? 'The chiller uses a refrigeration cycle (compressor → condenser → expansion valve → evaporator) to cool water to 6–8°C. This chilled water is pumped to AHUs and FCUs throughout the building.'
                : 'Chiller menggunakan kitaran penyejukan (compressor → condenser → expansion valve → evaporator) untuk menyejukkan air ke 6–8°C. Air sejuk ini dipam ke AHU dan FCU di seluruh bangunan.',
            color: const Color(0xFF1565C0),
          ),
          _FlowArrow(),
          _FlowStep(
            number: 2,
            icon: Icons.water_rounded,
            title: isEnglish ? 'Cooling Tower Rejects Heat' : 'Cooling Tower Membuang Haba',
            description: isEnglish
                ? 'Heat from the chiller condenser is transferred to cooling tower water. The cooling tower fan blows air across the water to evaporate heat, cooling the water from ~37°C to ~32°C before returning to the chiller.'
                : 'Haba dari condenser chiller dipindahkan ke air cooling tower. Kipas cooling tower meniup udara merentasi air untuk menyejatkan haba, menyejukkan air dari ~37°C ke ~32°C sebelum kembali ke chiller.',
            color: const Color(0xFF00ACC1),
          ),
          _FlowArrow(),
          _FlowStep(
            number: 3,
            icon: Icons.toys_rounded,
            title: isEnglish ? 'AHU Conditions & Distributes Air' : 'AHU Mengkondisi & Mengagih Udara',
            description: isEnglish
                ? 'The Air Handling Unit draws fresh air + return air through filters, then passes it over the chilled water coil to cool and dehumidify. The supply fan pushes conditioned air through ductwork to multiple zones. Temperature is controlled by the chilled water valve.'
                : 'Unit Pengendali Udara menarik udara segar + udara kembali melalui penapis, kemudian melepasinya ke atas gegelung air sejuk untuk menyejuk dan menyahlembap. Kipas bekalan menolak udara yang dikondisikan melalui saluran ke pelbagai zon. Suhu dikawal oleh injap air sejuk.',
            color: const Color(0xFF0288D1),
          ),
          _FlowArrow(),
          _FlowStep(
            number: 4,
            icon: Icons.air_rounded,
            title: isEnglish ? 'FCU Provides Localized Cooling' : 'FCU Menyediakan Penyejukan Setempat',
            description: isEnglish
                ? 'Fan Coil Units are smaller terminal units installed in individual rooms or zones. Each FCU has a fan that blows room air over a chilled water coil for localized temperature control. Condensate water drains away through pipes.'
                : 'Unit Kipas Gegelung adalah unit terminal yang lebih kecil dipasang di bilik atau zon individu. Setiap FCU mempunyai kipas yang meniup udara bilik ke atas gegelung air sejuk untuk kawalan suhu setempat. Air kondensat dialirkan melalui paip.',
            color: const Color(0xFF039BE5),
          ),
          _FlowArrow(),
          _FlowStep(
            number: 5,
            icon: Icons.home_work_rounded,
            title: isEnglish ? 'VRF/Split for Individual Zones' : 'VRF/Split untuk Zon Individu',
            description: isEnglish
                ? 'Variable Refrigerant Flow (VRF) systems use refrigerant directly instead of chilled water. One outdoor unit connects to multiple indoor units, each with independent temperature control. Ideal for buildings with varying zone requirements.'
                : 'Sistem Aliran Refrigeran Berubah (VRF) menggunakan refrigerant secara langsung dan bukannya air sejuk. Satu unit luaran disambung ke pelbagai unit dalaman, masing-masing dengan kawalan suhu bebas. Sesuai untuk bangunan dengan keperluan zon yang berbeza.',
            color: const Color(0xFF00897B),
          ),
          const SizedBox(height: 20),
          _SectionHeader(
            icon: Icons.checklist_rounded,
            title: isEnglish ? 'Key Components Summary' : 'Ringkasan Komponen Utama',
            color: const Color(0xFF0D7377),
          ),
          const SizedBox(height: 10),
          _ComponentRow(icon: Icons.ac_unit_rounded, label: 'Chiller', desc: isEnglish ? 'Produces chilled water' : 'Menghasilkan air sejuk', color: const Color(0xFF1565C0)),
          _ComponentRow(icon: Icons.water_rounded, label: 'Cooling Tower', desc: isEnglish ? 'Rejects condenser heat' : 'Membuang haba condenser', color: const Color(0xFF00ACC1)),
          _ComponentRow(icon: Icons.toys_rounded, label: 'AHU', desc: isEnglish ? 'Central air handling' : 'Pengendalian udara pusat', color: const Color(0xFF0288D1)),
          _ComponentRow(icon: Icons.air_rounded, label: 'FCU', desc: isEnglish ? 'Local room cooling' : 'Penyejukan bilik setempat', color: const Color(0xFF039BE5)),
          _ComponentRow(icon: Icons.home_work_rounded, label: 'VRF / Split', desc: isEnglish ? 'Direct refrigerant cooling' : 'Penyejukan refrigerant terus', color: const Color(0xFF00897B)),
          _ComponentRow(icon: Icons.settings_rounded, label: 'BMS', desc: isEnglish ? 'Central control & monitoring' : 'Kawalan & pemantauan pusat', color: const Color(0xFF0D7377)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D7377).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF0D7377).withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: const Color(0xFF0D7377)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEnglish
                        ? 'The entire HVAC system is interconnected — if one component fails (e.g. cooling tower), the whole system performance drops. Regular PPM on every component is essential per JKR GBSMG guidelines.'
                        : 'Keseluruhan sistem HVAC saling berkait — jika satu komponen gagal (contoh: cooling tower), prestasi keseluruhan sistem menurun. PPM berkala pada setiap komponen adalah penting mengikut garis panduan JKR GBSMG.',
                    style: TextStyle(fontSize: 12, color: const Color(0xFF37474F), height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color, height: 1.2),
        ),
      ],
    );
  }
}

class _FlowStep extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _FlowStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color, height: 1.2)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(description, style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Center(
        child: Icon(Icons.arrow_downward_rounded, size: 20, color: Color(0xFFCBD5E1)),
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String desc;
  final Color color;

  const _ComponentRow({required this.icon, required this.label, required this.desc, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
          ),
          Text(desc, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
