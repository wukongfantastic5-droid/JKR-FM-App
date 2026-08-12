import 'package:flutter/material.dart';

class JKRTask {
  final String description;
  final String descriptionBm;
  final String frequency;

  const JKRTask({
    required this.description,
    required this.descriptionBm,
    required this.frequency,
  });
}

class JKRSection {
  final String title;
  final String titleBm;
  final List<JKRTask> tasks;

  const JKRSection({
    required this.title,
    required this.titleBm,
    required this.tasks,
  });
}

class JKRTroubleshoot {
  final String problem;
  final String problemBm;
  final String icon;
  final List<String> causes;
  final List<String> causesBm;
  final List<String> solutions;
  final List<String> solutionsBm;

  const JKRTroubleshoot({
    required this.problem,
    required this.problemBm,
    required this.icon,
    required this.causes,
    required this.causesBm,
    required this.solutions,
    required this.solutionsBm,
  });
}

class JKRSystemData {
  final String title;
  final String titleBM;
  final String imageAsset;
  final Color color;
  final String icon;
  final String description;
  final String descriptionBM;
  final List<JKRSection> pmcm;
  final List<JKRTroubleshoot> troubleshoot;

  const JKRSystemData({
    required this.title,
    required this.titleBM,
    required this.imageAsset,
    required this.color,
    required this.icon,
    required this.description,
    required this.descriptionBM,
    required this.pmcm,
    required this.troubleshoot,
  });
}

const List<JKRSystemData> jkrSystems = [
  // ─── HVAC ───
  JKRSystemData(
    title: 'HVAC System (ACMV)',
    titleBM: 'Sistem HVAC (ACMV)',
    imageAsset: 'assets/images/HVAC system.jpg',
    color: Color(0xFF00ACC1),
    icon: '❄️',
    description: 'Complete HVAC system including chiller, cooling tower, AHU, FCU, and VRF/split units for building comfort cooling.',
    descriptionBM: 'Sistem HVAC lengkap termasuk chiller, cooling tower, AHU, FCU, dan unit VRF/split untuk penyejukan keselesaan bangunan.',
    pmcm: [
      JKRSection(title: 'Chiller Plant', titleBm: 'Loji Chiller', tasks: [
        JKRTask(description: 'Inspect chiller operation & record parameters', descriptionBm: 'Periksa operasi chiller & rekod parameter', frequency: 'D'),
        JKRTask(description: 'Check chilled water temp (supply/return)', descriptionBm: 'Periksa suhu air sejuk (bekalan/pulangan)', frequency: 'D'),
        JKRTask(description: 'Check refrigerant pressures & oil level', descriptionBm: 'Periksa tekanan refrigerant & paras minyak', frequency: 'W'),
        JKRTask(description: 'Inspect purge unit operation', descriptionBm: 'Periksa operasi unit purge', frequency: 'M'),
        JKRTask(description: 'Clean condenser tubes', descriptionBm: 'Bersihkan tiub kondenser', frequency: 'Y'),
        JKRTask(description: 'Check safety devices & calibration', descriptionBm: 'Periksa peranti keselamatan & kalibrasi', frequency: '6M'),
      ]),
      JKRSection(title: 'Cooling Tower', titleBm: 'Menara Penyejuk', tasks: [
        JKRTask(description: 'Check water level & bleed rate', descriptionBm: 'Periksa paras air & kadar bleed', frequency: 'D'),
        JKRTask(description: 'Inspect spray nozzles & fill media', descriptionBm: 'Periksa muncung sembur & media pengisi', frequency: 'M'),
        JKRTask(description: 'Clean basin & strainer', descriptionBm: 'Bersihkan bekas & penapis', frequency: 'M'),
        JKRTask(description: 'Water quality test (pH, TDS)', descriptionBm: 'Ujian kualiti air (pH, TDS)', frequency: '3M'),
        JKRTask(description: 'Lubricate fan bearings', descriptionBm: 'Lumur galas kipas', frequency: '6M'),
      ]),
      JKRSection(title: 'AHU & FCU', titleBm: 'AHU & FCU', tasks: [
        JKRTask(description: 'Check return/supply air temperature', descriptionBm: 'Periksa suhu udara pulangan/bekalan', frequency: 'D'),
        JKRTask(description: 'Clean or replace air filter', descriptionBm: 'Bersihkan atau ganti penapis udara', frequency: 'M'),
        JKRTask(description: 'Check condensate drain & fan belt', descriptionBm: 'Periksa saliran kondensat & tali sawat kipas', frequency: 'M'),
        JKRTask(description: 'Measure motor amperage', descriptionBm: 'Ukur amperage motor', frequency: 'M'),
        JKRTask(description: 'Lubricate fan bearings', descriptionBm: 'Lumur galas kipas', frequency: '3M'),
        JKRTask(description: 'Chemical coil cleaning', descriptionBm: 'Pembersihan gegelung kimia', frequency: 'Y'),
      ]),
    ],
    troubleshoot: [
      JKRTroubleshoot(
        problem: 'AHU not cooling', problemBm: 'AHU tidak sejuk',
        icon: '🌡️',
        causes: ['Chilled water valve closed', 'Filter clogged', 'Cooling coil dirty', 'Fan belt broken/slipping', 'Chilled water temp too high'],
        causesBm: ['Injap air sejuk tertutup', 'Penapis tersumbat', 'Gegelung penyejuk kotor', 'Tali sawat kipas putus/tergelincir', 'Suhu air sejuk terlalu tinggi'],
        solutions: ['Open chilled water valve manually', 'Replace air filter', 'Chemical clean cooling coil', 'Replace/adjust fan belt', 'Check chiller operation & setpoint'],
        solutionsBm: ['Buka injap air sejuk secara manual', 'Ganti penapis udara', 'Bersih gegelung penyejuk secara kimia', 'Ganti/laras tali sawat kipas', 'Periksa operasi chiller & setpoint'],
      ),
      JKRTroubleshoot(
        problem: 'Chiller high pressure trip', problemBm: 'Chiller tersentuh tekanan tinggi',
        icon: '⚠️',
        causes: ['Condenser tubes fouled', 'Cooling tower fan not running', 'Water flow low', 'Refrigerant overcharge', 'Non-condensables in system'],
        causesBm: ['Tiub kondenser kotor', 'Kipas menara penyejuk tidak berjalan', 'Aliran air rendah', 'Refrigeran berlebihan', 'Bahan tak terkondensasi dalam sistem'],
        solutions: ['Brush/chemical clean condenser tubes', 'Repair/replace cooling tower fan', 'Check condenser water pump & strainer', 'Recover excess refrigerant', 'Purge system of non-condensables'],
        solutionsBm: ['Berus/bersih tiub kondenser secara kimia', 'Baiki/ganti kipas menara penyejuk', 'Periksa pam air kondenser & penapis', 'Pulihkan refrigerant berlebihan', 'Tulenyapkan sistem dari bahan tak terkondensasi'],
      ),
      JKRTroubleshoot(
        problem: 'FCU leaking water', problemBm: 'FCU bocor air',
        icon: '💧',
        causes: ['Condensate drain blocked', 'Drain pan rusted/hole', 'Coil frozen then thawed', 'Pipe insulation missing', 'Unit not levelled'],
        causesBm: ['Saliran kondensat tersumbat', 'Dulang saliran berkarat/berlubang', 'Gegelung beku kemudian cair', 'Penebat paip hilang', 'Unit tidak rata'],
        solutions: ['Flush/clean condensate drain pipe', 'Replace drain pan', 'Check air filter & coil temp', 'Insulate condensate pipe', 'Re-level FCU unit'],
        solutionsBm: ['Siram/bersih paip saliran kondensat', 'Ganti dulang saliran', 'Periksa penapis udara & suhu gegelung', 'Penebat paip kondensat', 'Ratakan semula unit FCU'],
      ),
      JKRTroubleshoot(
        problem: 'Cooling tower water loss', problemBm: 'Kehilangan air menara penyejuk',
        icon: '🌊',
        causes: ['Float valve stuck', 'Bleed rate too high', 'Drift eliminators damaged', 'Basin crack/leak', 'Overflows blocked'],
        causesBm: ['Injap apung tersekat', 'Kadar bleed terlalu tinggi', 'Penghapus hanyutan rosak', 'Bekas retak/bocor', 'Limpahan tersumbat'],
        solutions: ['Repair/replace float valve', 'Adjust bleed valve', 'Replace drift eliminators', 'Repair basin crack', 'Clear overflow pipe'],
        solutionsBm: ['Baiki/ganti injap apung', 'Laras injap bleed', 'Ganti penghapus hanyutan', 'Baiki rekahan bekas', 'Bersih paip limpahan'],
      ),
    ],
  ),

  // ─── FIRE FIGHTING ───
  JKRSystemData(
    title: 'Fire Fighting System',
    titleBM: 'Sistem Pemadam Kebakaran',
    imageAsset: 'assets/images/Fire Fighting System.jpg',
    color: Color(0xFFD32F2F),
    icon: '🔥',
    description: 'Complete fire detection, alarm, and suppression system including sprinklers, hose reels, hydrants, and fire pumps.',
    descriptionBM: 'Sistem pengesanan kebakaran, penggera, dan pemadaman lengkap termasuk sprinkler, hose reel, pili bomba, dan pam kebakaran.',
    pmcm: [
      JKRSection(title: 'Control & Monitoring', titleBm: 'Kawalan & Pemantauan', tasks: [
        JKRTask(description: 'Man fire control room 24hrs', descriptionBm: 'Kawal bilik kawalan kebakaran 24 jam', frequency: 'D'),
        JKRTask(description: 'Respond to complaints from FSO/SO', descriptionBm: 'Tindak balas aduan dari FSO/SO', frequency: 'D'),
        JKRTask(description: 'Check FACP for fault/alarm signals', descriptionBm: 'Periksa FACP untuk isyarat rosak/penggera', frequency: 'D'),
        JKRTask(description: 'Test run fire system & simulate alarm', descriptionBm: 'Uji jalan sistem kebakaran & simulasi penggera', frequency: '6M'),
        JKRTask(description: 'Conduct fire drill with JBPM', descriptionBm: 'Jalankan latihan kebakaran dengan JBPM', frequency: 'Y'),
      ]),
      JKRSection(title: 'Pump Room', titleBm: 'Bilik Pam', tasks: [
        JKRTask(description: 'Inspect plant room cleanliness', descriptionBm: 'Periksa kebersihan bilik loji', frequency: 'W'),
        JKRTask(description: 'Inspect emergency light & ventilation', descriptionBm: 'Periksa lampu kecemasan & pengudaraan', frequency: 'W'),
        JKRTask(description: 'Record water level in fire tank', descriptionBm: 'Rekod paras air dalam tangki kebakaran', frequency: 'W'),
        JKRTask(description: 'Inspect pumps (cleanliness, noise)', descriptionBm: 'Periksa pam (kebersihan, bunyi)', frequency: 'M'),
        JKRTask(description: 'Test run pump auto & manual mode', descriptionBm: 'Uji jalan pam mod auto & manual', frequency: 'M'),
        JKRTask(description: 'Inspect pump bearings & lubricate', descriptionBm: 'Periksa galas pam & lumur', frequency: 'M'),
        JKRTask(description: 'Inspect mechanical seals for leaks', descriptionBm: 'Periksa pengedap mekanikal untuk bocor', frequency: 'M'),
        JKRTask(description: 'Check pressure switch operation', descriptionBm: 'Periksa operasi suis tekanan', frequency: 'M'),
        JKRTask(description: 'Check motor bearings & grease', descriptionBm: 'Periksa galas motor & gris', frequency: 'M'),
        JKRTask(description: 'Inspect electrical connections & contactors', descriptionBm: 'Periksa sambungan elektrik & kontaktor', frequency: 'M'),
        JKRTask(description: 'Inspect relief valve & flow meter', descriptionBm: 'Periksa injap lega & meter aliran', frequency: '3M'),
        JKRTask(description: 'Check labelling & diagrams up to date', descriptionBm: 'Periksa pelabelan & gambar rajah terkini', frequency: '3M'),
        JKRTask(description: 'Inspect batteries & battery charger', descriptionBm: 'Periksa bateri & pengecas bateri', frequency: '6M'),
        JKRTask(description: 'Full flow test with hydrant/hose reel', descriptionBm: 'Ujian aliran penuh dengan pili bomba/hose reel', frequency: 'Y'),
      ]),
      JKRSection(title: 'Sprinkler & Wet Riser', titleBm: 'Sprinkler & Penaik Basah', tasks: [
        JKRTask(description: 'Check main control valve open & sealed', descriptionBm: 'Periksa injap kawalan utama terbuka & dimeterai', frequency: 'W'),
        JKRTask(description: 'Visual inspect sprinkler heads', descriptionBm: 'Periksa visual kepala sprinkler', frequency: 'M'),
        JKRTask(description: 'Test flow switch & alarm valve', descriptionBm: 'Uji suis aliran & injap penggera', frequency: 'M'),
        JKRTask(description: 'Test water motor gong', descriptionBm: 'Uji gong motor air', frequency: 'M'),
        JKRTask(description: 'Test end of line valve', descriptionBm: 'Uji injap hujung talian', frequency: '3M'),
        JKRTask(description: 'Full flow test through test valve', descriptionBm: 'Ujian aliran penuh melalui injap ujian', frequency: '6M'),
        JKRTask(description: 'Full system pressure test (MS 1910)', descriptionBm: 'Ujian tekanan sistem penuh (MS 1910)', frequency: 'Y'),
        JKRTask(description: 'Sample test sprinkler heads (lab)', descriptionBm: 'Ujian sampel kepala sprinkler (makmal)', frequency: '5Y'),
      ]),
    ],
    troubleshoot: [
      JKRTroubleshoot(
        problem: 'Fire pump not starting', problemBm: 'Pam kebakaran tidak hidup',
        icon: '🚫',
        causes: ['No power supply', 'Controller in manual mode', 'Faulty pressure switch', 'Battery flat (diesel pump)', 'Battery charger faulty'],
        causesBm: ['Tiada bekalan kuasa', 'Pengawal dalam mod manual', 'Suis tekanan rosak', 'Bateri flat (pam diesel)', 'Pengecas bateri rosak'],
        solutions: ['Check MCCB/breaker & restore power', 'Switch controller to auto mode', 'Replace/calibrate pressure switch', 'Charge/replace batteries', 'Repair/replace battery charger'],
        solutionsBm: ['Periksa MCCB/pemutus & pulihkan kuasa', 'Tukar pengawal ke mod auto', 'Ganti/kalibrasi suis tekanan', 'Cas/ganti bateri', 'Baiki/ganti pengecas bateri'],
      ),
      JKRTroubleshoot(
        problem: 'System pressure dropping', problemBm: 'Tekanan sistem menurun',
        icon: '📉',
        causes: ['Leak in piping', 'Jockey pump failed', 'Sprinkler head activated', 'Pressure relief valve passing', 'Air in system'],
        causesBm: ['Kebocoran dalam paip', 'Pam joki gagal', 'Kepala sprinkler diaktifkan', 'Injap lega tekanan bocor', 'Udara dalam sistem'],
        solutions: ['Locate & repair leak', 'Repair jockey pump', 'Check for water flow/activation', 'Replace relief valve', 'Bleed air from system'],
        solutionsBm: ['Cari & baiki kebocoran', 'Baiki pam joki', 'Periksa aliran air/pengaktifan', 'Ganti injap lega', 'Keluarkan udara dari sistem'],
      ),
      JKRTroubleshoot(
        problem: 'FACP showing fault', problemBm: 'FACP menunjukkan kerosakan',
        icon: '🔔',
        causes: ['Detector head dirty/faulty', 'Loop wiring open/short', 'Battery low', 'Earth fault on loop', 'Module not responding'],
        causesBm: ['Kepala pengesan kotor/rosak', 'Pendawaian gelung terbuka/pendek', 'Bateri lemah', 'Kesilapan bumi pada gelung', 'Modul tidak respons'],
        solutions: ['Clean/replace detector', 'Check & repair loop wiring', 'Replace backup battery', 'Locate & clear earth fault', 'Replace faulty addressable module'],
        solutionsBm: ['Bersih/ganti pengesan', 'Periksa & baiki pendawaian gelung', 'Ganti bateri sandaran', 'Cari & bersih kesilapan bumi', 'Ganti modul boleh alamat rosak'],
      ),
      JKRTroubleshoot(
        problem: 'Diesel pump battery flat', problemBm: 'Bateri pam diesel flat',
        icon: '🔋',
        causes: ['Battery charger failed', 'Battery reached end of life', 'Faulty charging circuit', 'Parasitic drain', 'Loose battery terminals'],
        causesBm: ['Pengecas bateri gagal', 'Bateri mencapai hayat akhir', 'Litar pengecasan rosak', 'Kebocoran parasit', 'Terminal bateri longgar'],
        solutions: ['Repair/replace battery charger', 'Replace batteries (every 3-5 yrs)', 'Check wiring & fuses', 'Measure quiescent current', 'Clean & tighten terminals'],
        solutionsBm: ['Baiki/ganti pengecas bateri', 'Ganti bateri (setiap 3-5 thn)', 'Periksa pendawaian & fius', 'Ukur arus senyap', 'Bersih & ketatkan terminal'],
      ),
    ],
  ),

  // ─── LIFT ───
  JKRSystemData(
    title: 'Lift System',
    titleBM: 'Sistem Lif',
    imageAsset: 'assets/images/Lift System.jpg',
    color: Color(0xFF7B1FA2),
    icon: '🛗',
    description: 'Passenger and goods lifts including motor room, hoist way, car, and all safety systems per DOSH requirements.',
    descriptionBM: 'Lif penumpang dan barangan termasuk bilik motor, ruang angkat, kabin, dan semua sistem keselamatan mengikut keperluan DOSH.',
    pmcm: [
      JKRSection(title: 'Motor Room', titleBm: 'Bilik Motor', tasks: [
        JKRTask(description: 'Inspect motor room cleanliness', descriptionBm: 'Periksa kebersihan bilik motor', frequency: 'M'),
        JKRTask(description: 'Check emergency light & ventilation', descriptionBm: 'Periksa lampu kecemasan & pengudaraan', frequency: 'M'),
        JKRTask(description: 'Inspect for abnormal noise/vibration', descriptionBm: 'Periksa bunyi/getaran tidak normal', frequency: 'M'),
        JKRTask(description: 'Check gearbox oil level & leaks', descriptionBm: 'Periksa paras minyak kotak gear & bocor', frequency: 'M'),
        JKRTask(description: 'Inspect brake action & lining', descriptionBm: 'Periksa tindakan brek & lapisan', frequency: 'M'),
        JKRTask(description: 'Inspect overspeed governor', descriptionBm: 'Periksa governor lebih laju', frequency: 'M'),
        JKRTask(description: 'Inspect controller fans, relays, contactors', descriptionBm: 'Periksa kipas, geganti, kontaktor pengawal', frequency: 'M'),
        JKRTask(description: 'Clean governor & traction machine', descriptionBm: 'Bersihkan governor & mesin tarikan', frequency: 'M'),
        JKRTask(description: 'Check portable fire extinguisher (CO2)', descriptionBm: 'Periksa alat pemadam api mudah alih (CO2)', frequency: 'M'),
        JKRTask(description: 'Inspect inverter operation', descriptionBm: 'Periksa operasi inverter', frequency: 'M'),
        JKRTask(description: 'Check EBOPS battery & emergency light', descriptionBm: 'Periksa bateri EBOPS & lampu kecemasan', frequency: 'M'),
      ]),
      JKRSection(title: 'Hoist Way', titleBm: 'Ruang Angkat', tasks: [
        JKRTask(description: 'Inspect cleanliness of car top', descriptionBm: 'Periksa kebersihan atas kabin', frequency: 'M'),
        JKRTask(description: 'Check & adjust safety gear linkage', descriptionBm: 'Periksa & laras pautan gear keselamatan', frequency: 'M'),
        JKRTask(description: 'Inspect & lubricate car top pulley', descriptionBm: 'Periksa & lumur takal atas kabin', frequency: 'M'),
        JKRTask(description: 'Inspect hoist way limit switches', descriptionBm: 'Periksa suis had ruang angkat', frequency: 'M'),
        JKRTask(description: 'Check load compensating device', descriptionBm: 'Periksa peranti pampasan beban', frequency: 'M'),
        JKRTask(description: 'Inspect car guide shoes/rollers & oil', descriptionBm: 'Periksa kasut/pelaras panduan kabin & minyak', frequency: 'M'),
        JKRTask(description: 'Inspect wire ropes condition & tension', descriptionBm: 'Periksa keadaan & ketegangan tali wayar', frequency: 'M'),
        JKRTask(description: 'Inspect guide rails condition', descriptionBm: 'Periksa keadaan rel panduan', frequency: 'M'),
        JKRTask(description: 'Check traveling cable alignment', descriptionBm: 'Periksa penjajaran kabel bergerak', frequency: 'M'),
      ]),
    ],
    troubleshoot: [
      JKRTroubleshoot(
        problem: 'Lift not moving / stuck', problemBm: 'Lif tidak bergerak / tersekat',
        icon: '🛑',
        causes: ['Safety circuit open (door, limit switch)', 'Controller fault/failure', 'No power to lift', 'Overspeed governor tripped', 'Brake not releasing'],
        causesBm: ['Litar keselamatan terbuka (pintu, suis had)', 'Kerosakan pengawal', 'Tiada kuasa ke lif', 'Governor lebih laju tersentuh', 'Brek tidak lepas'],
        solutions: ['Reset safety circuit, check all door locks', 'Reboot controller, check error log', 'Check main breaker/isolator', 'Reset governor arm (CP required)', 'Check brake coil & adjust brake'],
        solutionsBm: ['Set semula litar keselamatan, periksa semua kunci pintu', 'But semula pengawal, periksa log ralat', 'Periksa pemutus utama/pengasing', 'Set semula lengan governor (perlukan CP)', 'Periksa gegelung brek & laras brek'],
      ),
      JKRTroubleshoot(
        problem: 'Lift noisy operation', problemBm: 'Operasi lif bising',
        icon: '🔊',
        causes: ['Guide shoes/rollers worn', 'Wire ropes dry/noisy', 'Sheave bearings worn', 'Door mechanism loose', 'Counterweight guide worn'],
        causesBm: ['Kasut/pelaras panduan haus', 'Tali wayar kering/bising', 'Galas sheave haus', 'Mekanisme pintu longgar', 'Panduan pemberat imbang haus'],
        solutions: ['Replace guide shoes/rollers', 'Lubricate wire ropes', 'Replace sheave bearings', 'Tighten/adjust door mechanism', 'Replace counterweight guide shoes'],
        solutionsBm: ['Ganti kasut/pelaras panduan', 'Lumur tali wayar', 'Ganti galas sheave', 'Ketatkan/laras mekanisme pintu', 'Ganti kasut panduan pemberat imbang'],
      ),
      JKRTroubleshoot(
        problem: 'Door not opening/closing', problemBm: 'Pintu tidak buka/tutup',
        icon: '🚪',
        causes: ['Door track obstructed', 'Door motor coupling worn', 'Door control board faulty', 'Safety edge sensor dirty/faulty', 'Door rollers worn'],
        causesBm: ['Laluan pintu terhalang', 'Gandingan motor pintu haus', 'Papan kawalan pintu rosak', 'Sensor tepi keselamatan kotor/rosak', 'Pelaras pintu haus'],
        solutions: ['Clean door track & lubricate', 'Replace door motor coupling', 'Replace/repair door control board', 'Clean/replace safety edge', 'Replace door rollers'],
        solutionsBm: ['Bersih laluan pintu & lumur', 'Ganti gandingan motor pintu', 'Ganti/baiki papan kawalan pintu', 'Bersih/ganti tepi keselamatan', 'Ganti pelaras pintu'],
      ),
      JKRTroubleshoot(
        problem: 'Lift leveling inaccurate', problemBm: 'Lif tidak tepat aras',
        icon: '📏',
        causes: ['Position sensor misaligned', 'Encoder faulty', 'Brake dragging', 'Controller leveling parameters wrong', 'Floor selector faulty'],
        causesBm: ['Sensor kedudukan tidak sejajar', 'Encoder rosak', 'Brek menyeret', 'Parameter aras pengawal salah', 'Pemilih tingkat rosak'],
        solutions: ['Re-align position sensors', 'Replace encoder', 'Adjust brake spring', 'Re-calibrate controller', 'Repair/replace floor selector'],
        solutionsBm: ['Sejajarkan semula sensor kedudukan', 'Ganti encoder', 'Laras spring brek', 'Kalibrasi semula pengawal', 'Baiki/ganti pemilih tingkat'],
      ),
    ],
  ),

  // ─── GONDOLA ───
  JKRSystemData(
    title: 'Gondola System',
    titleBM: 'Sistem Gondola',
    imageAsset: 'assets/images/Gondola System.jpg',
    color: Color(0xFFE64A19),
    icon: '🏗️',
    description: 'Building maintenance gondola (BMU) for facade cleaning and maintenance, with DOSH certified inspection.',
    descriptionBM: 'Gondola penyelenggaraan bangunan (BMU) untuk pembersihan dan penyelenggaraan fasad, dengan pemeriksaan diperakui DOSH.',
    pmcm: [
      JKRSection(title: 'Gondola Unit', titleBm: 'Unit Gondola', tasks: [
        JKRTask(description: 'Inspect motor bearings & parts', descriptionBm: 'Periksa galas motor & bahagian', frequency: 'M'),
        JKRTask(description: 'Check hydraulic oil leakage', descriptionBm: 'Periksa kebocoran minyak hidraulik', frequency: 'M'),
        JKRTask(description: 'Inspect safety catch & emergency brake', descriptionBm: 'Periksa pengancing keselamatan & brek kecemasan', frequency: 'M'),
        JKRTask(description: 'Check main switch, power cable, E-stop', descriptionBm: 'Periksa suis utama, kabel kuasa, henti-kecemasan', frequency: 'M'),
        JKRTask(description: 'Test buzzer/alarm', descriptionBm: 'Uji buzzer/penggera', frequency: 'M'),
        JKRTask(description: 'Test run unit for good operation', descriptionBm: 'Uji jalan unit untuk operasi baik', frequency: 'M'),
        JKRTask(description: 'Inspect wire ropes for damage', descriptionBm: 'Periksa tali wayar untuk kerosakan', frequency: 'M'),
        JKRTask(description: 'Arrange DOSH inspection & testing', descriptionBm: 'Atur pemeriksaan & ujian DOSH', frequency: 'Y'),
      ]),
    ],
    troubleshoot: [
      JKRTroubleshoot(
        problem: 'Gondola not moving', problemBm: 'Gondola tidak bergerak',
        icon: '⛔',
        causes: ['Power supply fault', 'Emergency stop pressed', 'Limit switch tripped', 'Motor overload protection', 'Controller fault'],
        causesBm: ['Bekalan kuasa rosak', 'Henti-kecemasan ditekan', 'Suis had tersentuh', 'Perlindungan beban lampau motor', 'Pengawal rosak'],
        solutions: ['Check breaker & power cable', 'Reset all E-stop buttons', 'Reset limit switches', 'Reset motor overload', 'Reboot controller'],
        solutionsBm: ['Periksa pemutus & kabel kuasa', 'Set semula semua butang henti-kecemasan', 'Set semula suis had', 'Set semula beban lampau motor', 'But semula pengawal'],
      ),
      JKRTroubleshoot(
        problem: 'Abnormal noise from motor', problemBm: 'Bunyi tidak normal dari motor',
        icon: '🔊',
        causes: ['Motor bearing worn', 'Gearbox low oil', 'Coupling misaligned', 'Brake dragging', 'Mounting bolts loose'],
        causesBm: ['Galas motor haus', 'Minyak kotak gear rendah', 'Gandingan tidak sejajar', 'Brek menyeret', 'Bolt pemasangan longgar'],
        solutions: ['Replace motor bearing', 'Top up gearbox oil', 'Realign coupling', 'Adjust brake clearance', 'Tighten mounting bolts'],
        solutionsBm: ['Ganti galas motor', 'Tambah minyak kotak gear', 'Sejajarkan semula gandingan', 'Laras kelonggaran brek', 'Ketatkan bolt pemasangan'],
      ),
    ],
  ),

  // ─── WATER SUPPLY ───
  JKRSystemData(
    title: 'Water Supply & Plumbing',
    titleBM: 'Bekalan Air & Paip',
    imageAsset: 'assets/images/Water Supply and Plumbing System.jpg',
    color: Color(0xFF1565C0),
    icon: '💧',
    description: 'Clean water supply system including pumps, tanks, booster sets, and plumbing distribution network.',
    descriptionBM: 'Sistem bekalan air bersih termasuk pam, tangki, set booster, dan rangkaian agihan paip.',
    pmcm: [
      JKRSection(title: 'Pump Room', titleBm: 'Bilik Pam', tasks: [
        JKRTask(description: 'Inspect pump room cleanliness', descriptionBm: 'Periksa kebersihan bilik pam', frequency: 'W'),
        JKRTask(description: 'Check emergency light & door condition', descriptionBm: 'Periksa lampu kecemasan & keadaan pintu', frequency: 'W'),
        JKRTask(description: 'Inspect pump condition & noise', descriptionBm: 'Periksa keadaan pam & bunyi', frequency: 'M'),
        JKRTask(description: 'Test run pump auto & manual mode', descriptionBm: 'Uji jalan pam mod auto & manual', frequency: 'M'),
        JKRTask(description: 'Check pressure switch cut-in/out', descriptionBm: 'Periksa suis tekanan masukan/keluaran', frequency: 'M'),
        JKRTask(description: 'Inspect pump bearings & lubricate', descriptionBm: 'Periksa galas pam & lumur', frequency: 'M'),
        JKRTask(description: 'Inspect motor bearings & lubricate', descriptionBm: 'Periksa galas motor & lumur', frequency: 'M'),
        JKRTask(description: 'Check mechanical seals for leaks', descriptionBm: 'Periksa pengedap mekanikal untuk bocor', frequency: 'M'),
        JKRTask(description: 'Inspect rubber couplings', descriptionBm: 'Periksa gandingan getah', frequency: 'M'),
        JKRTask(description: 'Check & tighten electrical connections', descriptionBm: 'Periksa & ketatkan sambungan elektrik', frequency: 'M'),
        JKRTask(description: 'Inspect control panel & starters', descriptionBm: 'Periksa panel kawalan & pemula', frequency: 'M'),
      ]),
      JKRSection(title: 'Tanks', titleBm: 'Tangki', tasks: [
        JKRTask(description: 'Check structure integrity & leaks', descriptionBm: 'Periksa integriti struktur & kebocoran', frequency: 'M'),
        JKRTask(description: 'Inspect ball valve operation', descriptionBm: 'Periksa operasi injap bola', frequency: 'M'),
        JKRTask(description: 'Check water level indicator', descriptionBm: 'Periksa penunjuk paras air', frequency: 'M'),
        JKRTask(description: 'Inspect electrodes & clean', descriptionBm: 'Periksa elektrod & bersih', frequency: 'M'),
        JKRTask(description: 'Clean & flush sediment', descriptionBm: 'Bersih & siram sedimen', frequency: '6M'),
        JKRTask(description: 'Inspect cat ladder', descriptionBm: 'Periksa tangga kucing', frequency: '6M'),
      ]),
    ],
    troubleshoot: [
      JKRTroubleshoot(
        problem: 'Low water pressure at top floors', problemBm: 'Tekanan air rendah di tingkat atas',
        icon: '📉',
        causes: ['Booster pump not running', 'Pressure vessel air charge low', 'Pressure switch faulty', 'Pump impeller worn', 'Pipe restriction/blockage'],
        causesBm: ['Pam booster tidak jalan', 'Tekanan udara bekas tekanan rendah', 'Suis tekanan rosak', 'Pemutar pam haus', 'Sekatan paip'],
        solutions: ['Check & restart booster pump', 'Recharge pressure vessel air pre-charge', 'Replace pressure switch', 'Replace pump impeller', 'Clear pipe blockage'],
        solutionsBm: ['Periksa & hidupkan semula pam booster', 'Isi semula tekanan udara bekas tekanan', 'Ganti suis tekanan', 'Ganti pemutar pam', 'Bersih sekatan paip'],
      ),
      JKRTroubleshoot(
        problem: 'Water pump short cycling', problemBm: 'Pam air kitar pendek',
        icon: '🔄',
        causes: ['Pressure vessel air bladder burst', 'Leak in system piping', 'Non-return valve passing', 'Pressure switch wide differential', 'Faulty pressure transducer'],
        causesBm: ['Pundi udara bekas tekanan pecah', 'Bocor dalam paip sistem', 'Injap sehala bocor', 'Perbezaan suis tekanan lebar', 'Transduser tekanan rosak'],
        solutions: ['Replace pressure vessel', 'Locate & repair leak', 'Replace non-return valve', 'Adjust/replace pressure switch', 'Replace transducer'],
        solutionsBm: ['Ganti bekas tekanan', 'Cari & baiki kebocoran', 'Ganti injap sehala', 'Laras/ganti suis tekanan', 'Ganti transduser'],
      ),
      JKRTroubleshoot(
        problem: 'No water at taps', problemBm: 'Tiada air di paip',
        icon: '🚱',
        causes: ['Main tank empty', 'Pump failed', 'Power supply off', 'Float switch stuck', 'Pipe burst/isolation valve closed'],
        causesBm: ['Tangki utama kosong', 'Pam gagal', 'Bekalan kuasa terputus', 'Suis apung tersekat', 'Paip pecah/injap pengasing tertutup'],
        solutions: ['Check main supply & float valve', 'Repair/replace pump', 'Check MCCB & starter', 'Free/replace float switch', 'Open isolation valves'],
        solutionsBm: ['Periksa bekalan utama & injap apung', 'Baiki/ganti pam', 'Periksa MCCB & pemula', 'Bebas/ganti suis apung', 'Buka injap pengasing'],
      ),
    ],
  ),

  // ─── KITCHEN ───
  JKRSystemData(
    title: 'Kitchen System',
    titleBM: 'Sistem Dapur',
    imageAsset: 'assets/images/Kitchen System.jpg',
    color: Color(0xFFF9A825),
    icon: '🍳',
    description: 'Commercial kitchen equipment including gas range, hobs, kitchen hood, exhaust fans, and wet chemical fire suppression.',
    descriptionBM: 'Peralatan dapur komersial termasuk dapur gas, hob, hud dapur, kipas ekzos, dan pemadaman api kimia basah.',
    pmcm: [
      JKRSection(title: 'Kitchen Hood & Exhaust', titleBm: 'Hud Dapur & Ekzos', tasks: [
        JKRTask(description: 'Clean kitchen hood (interior & exterior)', descriptionBm: 'Bersih hud dapur (dalam & luar)', frequency: 'W'),
        JKRTask(description: 'Grease bearings & balance fan blades', descriptionBm: 'Gris galas & imbang bilah kipas', frequency: 'M'),
        JKRTask(description: 'Inspect & replace belts', descriptionBm: 'Periksa & ganti tali sawat', frequency: 'M'),
        JKRTask(description: 'Replace filters, lights, globes', descriptionBm: 'Ganti penapis, lampu, glob', frequency: 'M'),
        JKRTask(description: 'Test operation under simulated fire', descriptionBm: 'Uji operasi di bawah simulasi kebakaran', frequency: 'M'),
        JKRTask(description: 'Measure & adjust air flow', descriptionBm: 'Ukur & laras aliran udara', frequency: '6M'),
      ]),
      JKRSection(title: 'Gas Equipment', titleBm: 'Peralatan Gas', tasks: [
        JKRTask(description: 'Check nozzle for blockage', descriptionBm: 'Periksa muncung untuk sumbatan', frequency: 'M'),
        JKRTask(description: 'Check gas valve for leakage', descriptionBm: 'Periksa injap gas untuk bocor', frequency: '3M'),
        JKRTask(description: 'Clean & adjust thermocouple angle', descriptionBm: 'Bersih & laras sudut termoganding', frequency: '3M'),
        JKRTask(description: 'Check manifold joints tightness', descriptionBm: 'Periksa ketegangan sambungan manifold', frequency: '3M'),
      ]),
      JKRSection(title: 'Wet Chemical System', titleBm: 'Sistem Kimia Basah', tasks: [
        JKRTask(description: 'Inspect gas cylinder & pressure gauge', descriptionBm: 'Periksa silinder gas & tolok tekanan', frequency: 'M'),
        JKRTask(description: 'Check cylinder weight', descriptionBm: 'Periksa berat silinder', frequency: 'M'),
        JKRTask(description: 'Inspect & test control panel', descriptionBm: 'Periksa & uji panel kawalan', frequency: 'M'),
        JKRTask(description: 'Inspect detectors & wiring', descriptionBm: 'Periksa pengesan & pendawaian', frequency: 'M'),
        JKRTask(description: 'Inspect rusty parts & replace', descriptionBm: 'Periksa bahagian berkarat & ganti', frequency: 'M'),
        JKRTask(description: 'Conduct simulation test (minus discharge)', descriptionBm: 'Jalankan ujian simulasi (tanpa pancaran)', frequency: '6M'),
        JKRTask(description: 'Check time delay (25-30 sec)', descriptionBm: 'Periksa lengahan masa (25-30 saat)', frequency: '6M'),
        JKRTask(description: 'Test bell & warning light', descriptionBm: 'Uji loceng & lampu amaran', frequency: '6M'),
      ]),
    ],
    troubleshoot: [
      JKRTroubleshoot(
        problem: 'Kitchen hood not extracting', problemBm: 'Hud dapur tidak sedut',
        icon: '💨',
        causes: ['Filter clogged with grease', 'Fan belt broken/slipping', 'Motor failed', 'Damper closed/stuck', 'Duct blocked'],
        causesBm: ['Penapis tersumbat gris', 'Tali sawat kipas putus/tergelincir', 'Motor rosak', 'Damper tutup/tersekat', 'Saluran tersumbat'],
        solutions: ['Clean/replace grease filter', 'Replace/adjust fan belt', 'Repair/replace motor', 'Open/unstick damper', 'Clean ductwork'],
        solutionsBm: ['Bersih/ganti penapis gris', 'Ganti/laras tali sawat kipas', 'Baiki/ganti motor', 'Buka/bebas damper', 'Bersih saluran udara'],
      ),
      JKRTroubleshoot(
        problem: 'Gas burner not lighting', problemBm: 'Pembakar gas tidak nyala',
        icon: '🔥',
        causes: ['Nozzle blocked', 'Gas supply off', 'Thermocouple faulty', 'Ignition electrode dirty', 'Gas valve closed'],
        causesBm: ['Muncung tersumbat', 'Bekalan gas tertutup', 'Termoganding rosak', 'Elektrod pencucuh kotor', 'Injap gas tertutup'],
        solutions: ['Clean/replace nozzle', 'Open main gas valve', 'Replace thermocouple', 'Clean electrode gap', 'Open appliance gas valve'],
        solutionsBm: ['Bersih/ganti muncung', 'Buka injap gas utama', 'Ganti termoganding', 'Bersih celah elektrod', 'Buka injap gas perkakas'],
      ),
    ],
  ),

  // ─── IRRIGATION ───
  JKRSystemData(
    title: 'Irrigation & Landscape',
    titleBM: 'Pengairan & Landskap',
    imageAsset: 'assets/images/Irrigation and Landscape System.jpg',
    color: Color(0xFF2E7D32),
    icon: '🌿',
    description: 'Irrigation system including water pump, piping, sprinklers, control panel for landscape maintenance.',
    descriptionBM: 'Sistem pengairan termasuk pam air, paip, sprinkler, panel kawalan untuk penyelenggaraan landskap.',
    pmcm: [
      JKRSection(title: 'Water Pump', titleBm: 'Pam Air', tasks: [
        JKRTask(description: 'Inspect bearings & lubricate with grease', descriptionBm: 'Periksa galas & lumur dengan gris', frequency: 'M'),
        JKRTask(description: 'Check coupling & alignment', descriptionBm: 'Periksa gandingan & penjajaran', frequency: 'M'),
        JKRTask(description: 'Tighten all hold-down bolts', descriptionBm: 'Ketatkan semua bolt pengikat', frequency: 'M'),
        JKRTask(description: 'Check flow switch & pressure switch', descriptionBm: 'Periksa suis aliran & suis tekanan', frequency: '3M'),
        JKRTask(description: 'Clean pipe line filter', descriptionBm: 'Bersih penapis talian paip', frequency: '3M'),
        JKRTask(description: 'Open pump to inspect for wear', descriptionBm: 'Buka pam untuk periksa kehausan', frequency: 'Y'),
      ]),
      JKRSection(title: 'Control Panel', titleBm: 'Panel Kawalan', tasks: [
        JKRTask(description: 'Inspect starter coil & contacts', descriptionBm: 'Periksa gegelung pemula & sesentuh', frequency: 'M'),
        JKRTask(description: 'Check contactors & timer', descriptionBm: 'Periksa kontaktor & pemasa', frequency: 'M'),
        JKRTask(description: 'Check voltage & running ampere', descriptionBm: 'Periksa voltan & ampere jalan', frequency: 'M'),
        JKRTask(description: 'Check thermal overload & relays', descriptionBm: 'Periksa beban lampau terma & geganti', frequency: '6M'),
      ]),
      JKRSection(title: 'Piping & Filters', titleBm: 'Paip & Penapis', tasks: [
        JKRTask(description: 'Check for leaks at valves & fittings', descriptionBm: 'Periksa bocor di injap & kelengkapan', frequency: 'M'),
        JKRTask(description: 'Clean strainer', descriptionBm: 'Bersih penapis', frequency: 'M'),
        JKRTask(description: 'Clean filter media', descriptionBm: 'Bersih media penapis', frequency: 'M'),
        JKRTask(description: 'Check flow rate & record', descriptionBm: 'Periksa kadar aliran & rekod', frequency: 'M'),
      ]),
    ],
    troubleshoot: [
      JKRTroubleshoot(
        problem: 'No water from sprinklers', problemBm: 'Tiada air dari sprinkler',
        icon: '🚫💧',
        causes: ['Pump not running', 'Water supply empty', 'Control valve closed', 'Filter blocked', 'Pipe burst'],
        causesBm: ['Pam tidak jalan', 'Bekalan air kosong', 'Injap kawalan tertutup', 'Penapis tersumbat', 'Paip pecah'],
        solutions: ['Check pump controller & restart', 'Fill water tank/recharge', 'Open control valve', 'Clean filter', 'Repair pipe burst'],
        solutionsBm: ['Periksa pengawal pam & hidup semula', 'Isi tangki air/cas semula', 'Buka injap kawalan', 'Bersih penapis', 'Baiki paip pecah'],
      ),
      JKRTroubleshoot(
        problem: 'Low water pressure in system', problemBm: 'Tekanan air rendah dalam sistem',
        icon: '📉',
        causes: ['Pump impeller worn', 'Filter partially blocked', 'Pipe leak/break', 'Suction line blocked', 'Clogged nozzles'],
        causesBm: ['Pemutar pam haus', 'Penapis separa tersumbat', 'Paip bocor/pecah', 'Talian sedut tersumbat', 'Muncung tersumbat'],
        solutions: ['Replace pump impeller', 'Clean/replace filter', 'Locate & repair leak', 'Clear suction strainer', 'Clean/clear nozzles'],
        solutionsBm: ['Ganti pemutar pam', 'Bersih/ganti penapis', 'Cari & baiki kebocoran', 'Bersih penapis sedut', 'Bersih/bebas muncung'],
      ),
    ],
  ),

  // ─── OTHER MECHANICAL ───
  JKRSystemData(
    title: 'Other Mechanical System',
    titleBM: 'Sistem Mekanikal Lain',
    imageAsset: 'assets/images/Other Mechanical System.jpg',
    color: Color(0xFF546E7A),
    icon: '⚙️',
    description: 'Other mechanical equipment including roller shutters, hand dryers, grey water system, and general plant rooms.',
    descriptionBM: 'Peralatan mekanikal lain termasuk penggelek shutters, pengering tangan, sistem air kelabu, dan bilik loji am.',
    pmcm: [
      JKRSection(title: 'General Plant Room', titleBm: 'Bilik Loji Am', tasks: [
        JKRTask(description: 'Respond to daily operation complaints', descriptionBm: 'Tindak balas aduan operasi harian', frequency: 'D'),
        JKRTask(description: 'Inspect general condition of equipment', descriptionBm: 'Periksa keadaan umum peralatan', frequency: 'M'),
        JKRTask(description: 'Test systems for manual/auto operation', descriptionBm: 'Uji sistem untuk operasi manual/auto', frequency: 'M'),
        JKRTask(description: 'Inspect & rectify leakages', descriptionBm: 'Periksa & baiki kebocoran', frequency: 'M'),
        JKRTask(description: 'Lubricate all bearings & moving parts', descriptionBm: 'Lumur semua galas & bahagian bergerak', frequency: 'M'),
        JKRTask(description: 'Inspect for abnormal noise/vibration', descriptionBm: 'Periksa bunyi/getaran tidak normal', frequency: 'M'),
        JKRTask(description: 'Tighten all bolts & nuts', descriptionBm: 'Ketatkan semua bolt & nat', frequency: 'M'),
        JKRTask(description: 'Inspect pressure switches & gauges', descriptionBm: 'Periksa suis tekanan & tolok', frequency: 'M'),
      ]),
      JKRSection(title: 'Roller Shutter', titleBm: 'Penggelek Shutter', tasks: [
        JKRTask(description: 'Check curtain, guides, locking condition', descriptionBm: 'Periksa tirai, panduan, keadaan kunci', frequency: 'M'),
        JKRTask(description: 'Test door manually (smooth operation)', descriptionBm: 'Uji pintu manual (operasi lancar)', frequency: 'M'),
        JKRTask(description: 'Inspect link to MFAP', descriptionBm: 'Perikta sambungan ke MFAP', frequency: 'M'),
        JKRTask(description: 'Inspect motor bearings & lubricate', descriptionBm: 'Periksa galas motor & lumur', frequency: 'M'),
        JKRTask(description: 'Inspect & test control panel', descriptionBm: 'Periksa & uji panel kawalan', frequency: 'M'),
      ]),
      JKRSection(title: 'Hand Dryer', titleBm: 'Pengering Tangan', tasks: [
        JKRTask(description: 'Inspect condition of hand dryers', descriptionBm: 'Periksa keadaan pengering tangan', frequency: 'W'),
        JKRTask(description: 'Test run each hand dryer', descriptionBm: 'Uji jalan setiap pengering tangan', frequency: 'M'),
      ]),
    ],
    troubleshoot: [
      JKRTroubleshoot(
        problem: 'Roller shutter not closing', problemBm: 'Penggelek shutter tidak tutup',
        icon: '🔄',
        causes: ['Track obstructed', 'Motor coupling worn', 'Limit switch misaligned', 'Power supply fault', 'Safety beam obstructed'],
        causesBm: ['Laluan terhalang', 'Gandingan motor haus', 'Suis had tidak sejajar', 'Bekalan kuasa rosak', 'Rasuk keselamatan terhalang'],
        solutions: ['Clear track obstruction', 'Replace motor coupling', 'Adjust limit switch', 'Check breaker & wiring', 'Clear safety beam path'],
        solutionsBm: ['Bersih halangan laluan', 'Ganti gandingan motor', 'Laras suis had', 'Periksa pemutus & pendawaian', 'Bersih laluan rasuk keselamatan'],
      ),
      JKRTroubleshoot(
        problem: 'Hand dryer not working', problemBm: 'Pengering tangan tidak jalan',
        icon: '💨',
        causes: ['Power not connected', 'Thermal cut-out tripped', 'Fan motor failed', 'Heating element burned', 'Timer/IR sensor faulty'],
        causesBm: ['Kuasa tidak disambung', 'Pemotong terma tersentuh', 'Motor kipas rosak', 'Elemen pemanas terbakar', 'Pemasa/sensor IR rosak'],
        solutions: ['Check & reset breaker', 'Allow to cool (auto reset)', 'Replace fan motor', 'Replace heating element', 'Replace sensor board'],
        solutionsBm: ['Periksa & set semula pemutus', 'Biarkan sejuk (set semula auto)', 'Ganti motor kipas', 'Ganti elemen pemanas', 'Ganti papan sensor'],
      ),
    ],
  ),
];
