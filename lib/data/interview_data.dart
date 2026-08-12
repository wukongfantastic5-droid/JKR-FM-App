class InterviewSection {
  final String title;
  final String icon;
  final List<InterviewItem> items;

  const InterviewSection({
    required this.title,
    required this.icon,
    required this.items,
  });
}

class InterviewItem {
  final String question;
  final String answer;

  const InterviewItem({
    required this.question,
    required this.answer,
  });
}

const List<InterviewSection> interviewData = [
  InterviewSection(
    title: 'Jurutera Mekanikal JKR FM',
    icon: '⚙️',
    items: [
      InterviewItem(
        question: 'Apa peranan Jurutera Mekanikal dalam FM JKR?',
        answer:
            'Sebagai Jurutera Mekanikal dalam FM JKR, peranan saya merangkumi:\n\n1. Pengurusan Sistem Mekanikal: HVAC (ACMV), fire fighting, lift, eskalator, gondola, plumbing & water supply, sistem dapur, pengairan & landskap.\n\n2. Penyelenggaraan Berjadual (PM): Memastikan semua PM mengikut jadual berdasarkan PPM JKR – weekly, monthly, quarterly, half-yearly, yearly.\n\n3. Pembaikan (CM): Mengurus aduan, diagnose masalah, laksana pembaikan, dan buat RCA.\n\n4. Pengurusan Kontraktor: Beri arahan, semak method statement, witness testing, verify work, approve claim.\n\n5. Pelaporan: Sediakan laporan teknikal, laporan aduan, laporan PM, dan laporan kepada JKR/KKR.\n\n6. Pematuhan: Pastikan semua kerja mematuhi standard JKR, DOSH, Bomba, dan Suruhanjaya Tenaga.',
      ),
      InterviewItem(
        question: 'Bagaimana anda mengurus HVAC system di bangunan JKR?',
        answer:
            'HVAC adalah sistem paling kritikal di bangunan JKR. Tanggungjawab saya:\n\n1. PM Schedule:\n   - Weekly: Semak chiller log, cooling tower operation, AHU/FCU operation\n   - Monthly: Tukar filter, check belt tension, lubricate bearing\n   - Quarterly: Clean condenser coil, check refrigerant pressure\n   - Yearly: Major overhaul chiller, chemical cleaning cooling tower\n\n2. VRF/VRV System:\n   - PM: Clean outdoor unit condenser coil, check refrigerant pressure, check indoor unit filter\n   - Check for refrigerant leakage (common issue)\n   - Monitor error code pada outdoor unit PCB\n   - Check communication wiring antara outdoor & indoor units\n   - Pastikan branch selector box berfungsi\n\n3. Troubleshooting biasa:\n   - "Tidak sejuk" - check setpoint, filter, belt, valve, refrigerant, VRF error code\n   - "Bising" - check bearing, belt, fan blade\n   - "Aircond bocor" - check drainage pipe, clean tray\n   - "Kompressor trip" - check overload, refrigerant pressure, contactor\n\n4. Energy optimization:\n   - Setpoint sesuai (24°C ± 1°C)\n   - Schedule operation ikut waktu pejabat\n   - VSD pada pump/fan\n   - Chiller sequencing\n\n5. Compliance: Pastikan CGSO (Competent Gas Service Officer) untuk refrigerant handling.',
      ),
      InterviewItem(
        question: 'Bagaimana anda mengurus Fire Fighting system?',
        answer:
            'Sistem fire fighting di bangunan JKR merangkumi:\n\n1. Fire Pump System:\n   - Weekly test: Run jockey pump, electric pump, diesel pump (15 min each)\n   - Check pressure setting, battery diesel pump, fuel level\n   - Simulate power failure - pastikan diesel pump auto start\n\n2. Sprinkler & Hose Reel:\n   - Check valve position (normally open)\n   - Check pressure gauge\n   - Annual pressure test\n   - Pastikan tiada halangan pada sprinkler head\n\n3. Fire Extinguisher:\n   - Monthly check: pressure, weight, pin, hose\n   - Annual service by vendor\n   - 5-yearly hydraulic test\n\n4. Smoke Detector & Alarm:\n   - Test function\n   - Clean detector (debu boleh cause false alarm)\n   - Check battery backup\n\n5. Compliance: Bomba Act 1988, Uniform Building By-Laws (UBBL).',
      ),
      InterviewItem(
        question: 'Apa tugas Jurutera Mekanikal terhadap Lift & Gondola?',
        answer:
            'Walaupun lift dan gondola diselenggara oleh kontraktor khusus, Jurutera Mekanikal perlu:\n\n1. Lift:\n   - Semak laporan PM kontraktor\n   - Pastikan CP DOSH (Certificate of Fitness) masih sah\n   - Pantau breakdown frequency dan MTBF\n   - Koordinasi dengan kontraktor jika ada aduan\n   - Pastikan sparepart kritikal ada stock\n   - Semak log book harian\n\n2. Gondola:\n   - Pastikan annual load test dilakukan\n   - Check wire rope condition\n   - Check limit switch dan emergency stop\n   - Pastikan operator terlatih\n\nJangan lupa: Walaupun kontraktor yang kerja, tanggungjawab keselamatan tetap pada Jurutera Fasiliti.',
      ),
      InterviewItem(
        question: 'Bagaimana pendekatan anda terhadap Plumbing & Water Supply?',
        answer:
            'Sistem plumbing di bangunan JKR:\n\n1. Water Supply System:\n   - Ground tank, roof tank, booster pump, hydro-pneumatic system\n   - PM: Check pump operation, clean tank (annual), check valve, check pressure\n   - Weekly: Run pump, check for leakage, check water level\n\n2. Sanitary System:\n   - Soil pipe, waste pipe, ventilation pipe\n   - Check for blockage, leakage, odor\n   - Periodically flush system\n\n3. Common issues:\n   - "Tekanan air rendah" - check pump, check valve, check tank level\n   - "Air kotor/berkarat" - need tank cleaning, check piping material\n   - "Paip bocor" - identify source, isolate, repair\n   - "Sewage backup" - call for suction, identify blockage\n\n4. Water quality: Sampling and testing ikut standard KKM.',
      ),
      InterviewItem(
        question: 'Bagaimana anda mengurus PM bagi semua sistem mekanikal?',
        answer:
            'Pengurusan PM untuk bangunan JKR mengikut PPM (Pelan Penyelenggaraan Pencegahan):\n\n1. Rujuk PPM JKR untuk skop dan kekerapan setiap sistem\n\n2. Kategori PM:\n   - Weekly: Visual check, run test, log reading\n   - Monthly: Clean filter, lubricate, tighten connection\n   - Quarterly: Change filter, check refrigerant, test safety device\n   - Half-yearly: Overhaul minor, check performance\n   - Yearly: Major overhaul, chemical cleaning, calibration\n\n3. Sistem:\n   a) HVAC: Chiller, cooling tower, AHU, FCU, pump, VRF\n   b) Fire: Fire pump, sprinkler, extinguisher, alarm\n   c) Lift: Cab, machine room, safety device, door\n   d) Plumbing: Pump, tank, valve, pipe\n   e) Electrical (not mekanikal but related): Panel, breaker, cable\n\n4. Dokumentasi:\n   - PM schedule & checklist\n   - Log book (bacaan harian/mingguan)\n   - Laporan PM (completed)\n   - Defect list (jika ada)\n   - Follow-up action\n\n5. Software: Gunakan CMMS (Computerized Maintenance Management System) jika ada.',
      ),
      InterviewItem(
        question: 'Arahan Keselamatan (HSE) untuk kerja mekanikal?',
        answer:
            'Sebagai Jurutera Mekanikal, pastikan:\n\n1. Permit Kerja (Work Permit):\n   - Hot Work Permit (welding, grinding)\n   - Working at Height Permit (kerja tinggi)\n   - Confined Space Permit (tangki, ducting)\n   - Electrical Isolation Permit (Lockout-Tagout)\n\n2. HSE untuk kerja mekanikal:\n   - LOTO (Lockout-Tagout) - pastikan punca kuasa diisolasi\n   - PPE: Helmet, safety shoes, gloves, safety glasses\n   - Jika refrigerant: pastikan ventilation cukup, guna gas detector\n   - Jika lifting: pastikan crane/hoist certified\n\n3. Contractor Management:\n   - Semak HIRARC sebelum kerja\n   - Toolbox meeting setiap hari\n   - Semak cert mesin dan peralatan\n   - Pastikan pekerja ada latihan/training\n\n4. Emergency Response:\n   - First aid kit\n   - Fire extinguisher nearby\n   - Emergency contact number\n   - Spill kit (untuk minyak/chemical)',
      ),
      InterviewItem(
        question: 'Bagaimana mengurus aduan sistem mekanikal?',
        answer:
            'Prosedur sistematik dari terima aduan hingga tutup kes:\n\n1. Terima Aduan:\n   - Catat nama, tarikh, masa, sistem, lokasi, description, priority\n   - Gunakan borang aduan JKR/online system\n\n2. Triage (Priority):\n   - Emergency (30 min response) - contoh: fire pump failure, lift trap\n   - Urgent (2 jam) - contoh: HVAC down di kawasan kritikal\n   - Normal (24 jam) - contoh: FCU bising\n\n3. Diagnosis:\n   - Hantar technician jurutera mekanikal\n   - Diagnose masalah (pakai kaedah S-A-A-R atau 5 Whys)\n   - Tentukan tindakan\n\n4. Tindakan:\n   - Minor repair: laksana sendiri/team\n   - Major repair: koordinasi dengan kontraktor\n   - Temp work: sementara menunggu sparepart\n\n5. Testing:\n   - Test selepas repair\n   - Pastikan sistem berfungsi normal\n\n6. Close Report:\n   - Document masalah, punca, tindakan, hasil\n   - Tandatangan pengadu (jika perlu)\n   - Archive untuk rujukan masa depan\n\n7. RCA untuk isu berulang: buat Root Cause Analysis.',
      ),
      InterviewItem(
        question: 'Apa yang perlu ada dalam laporan teknikal kepada JKR?',
        answer:
            'Laporan teknikal kepada JKR mesti profesional dan lengkap:\n\n1. Header: Letterhead syarikat, rujukan, tarikh\n\n2. Recipient: Pengarah/Unit FAS JKR\n\n3. Tajuk: Laporkan mengikut kes (Contoh: Laporan Kerosakan Sistem HVAC Blok G)\n\n4. Isi Kandungan:\n   a) Objektif / Latar belakang\n   b) Lokasi dan sistem terlibat\n   c) Pemeriksaan / Diagnosis\n   d) Dapatan (findings) - sertakan gambar\n   e) Tindakan yang diambil\n   f) Status (completed/pending/tindakan lanjut)\n   g) Cadangan (jika ada)\n   h) Kos (jika ada)\n\n5. Lampiran:\n   - Gambar\n   - Data bacaan (sebelum & selepas)\n   - Work permit\n   - Method statement\n\n6. Signature: Jurutera Mekanikal, disahkan oleh Pengurus\n\nTips: Guna format profesional, ringkas tapi lengkap, dan sertakan bukti visual.',
      ),
      InterviewItem(
        question: 'Apa perbezaan kerja Jurutera Mekanikal di tapak projek vs di FM?',
        answer:
            'Perbezaan utama:\n\nDi Tapak Projek (Construction):\n- Fokus pada pemasangan baru (new installation)\n- Kerja ikut drawing dan specification\n- Testing & Commissioning untuk handover\n- Pengurus kontraktor pemasangan\n- Deadline ikut kontrak projek\n- Kerja selesai bila projek handover\n\nDi FM (Facility Management):\n- Fokus pada penyelenggaraan sistem sedia ada\n- Kerja ikut PPM schedule dan aduan harian\n- Troubleshooting dan repair\n- Pengurus kontraktor penyelenggaraan\n- Deadline ikut service level (response time)\n- Kerja berterusan (building ada selama-lamanya)\n- Kena pandai prioritise banyak aduan serentak\n\nKemahiran sama: Sistem mekanikal, electrical knowledge, problem solving, people management.',
      ),
      InterviewItem(
        question: 'Sistem apa saja yang perlu dikuasai oleh Jurutera Mekanikal di JKR?',
        answer:
            'Jurutera Mekanikal di bangunan JKR perlu menguasai:\n\n1. HVAC System (ACMV):\n   - Chiller (water-cooled, air-cooled)\n   - Cooling Tower, AHU, FCU\n   - VRF/VRV System (Variable Refrigerant Flow/Volume) — outdoor unit, indoor unit, branch selector box, refrigerant piping\n   - Ducting, diffuser, thermostat, BMS\n\n2. Fire Fighting System:\n   - Fire pump (electric & diesel), jockey pump\n   - Sprinkler system, hose reel, fire extinguisher\n   - Smoke detector, alarm panel, VFB\n\n3. Lift & Escalator:\n   - Traction lift, hydraulic lift\n   - Machine room & machine-roomless\n   - Safety devices, COP, limit switch\n\n4. Gondola:\n   - Manual & electric gondola\n   - Wire rope, motor, control system\n\n5. Plumbing & Water Supply:\n   - Water pump (booster, transfer, submersible)\n   - Water tank (ground, roof)\n   - Hydro-pneumatic system\n   - Piping, valve, fitting\n\n6. Kitchen System:\n   - Range hood, exhaust fan, grease trap\n   - Kitchen equipment (jika included)\n\n7. Irrigation & Landscape:\n   - Water pump irrigation\n   - Sprinkler, timer control\n\n8. Other Systems:\n   - Compressed air system\n   - Medical gas (jika hospital)\n   - Swimming pool system (jika ada)',
      ),
      InterviewItem(
        question: 'Apa peranan BMS dalam pengurusan sistem mekanikal?',
        answer:
            'BMS (Building Management System) adalah sistem kawalan berpusat yang memantau dan mengawal semua sistem mekanikal bangunan. Peranan BMS dalam FM JKR:\n\n1. HVAC System:\n   - Monitor & control chiller, cooling tower, AHU, FCU, VRF\n   - Setpoint temperature control\n   - Schedule ON/OFF ikut waktu operasi\n   - Trend temperature, humidity, CO2\n   - Alarm jika berlaku deviation\n\n2. Fire Fighting System:\n   - Monitor fire pump status (run/stop/fault)\n   - Integrate with fire alarm panel\n   - Receive signal from smoke/heat detector\n   - Close fire damper automatically\n   - Trigger exhaust fan semasa fire mode\n\n3. Lift System:\n   - Monitor lift position, status, alarm\n   - Display lift car location di BMS screen\n   - Log lift trip/fault\n\n4. Plumbing & Water:\n   - Monitor water tank level (high/low alarm)\n   - Monitor pump status (running/fault)\n   - Monitor water pressure\n   - Leakage detection\n\n5. Electrical (related):\n   - Monitor power consumption (energy meter)\n   - Generator status & fuel level\n   - ATS status\n\n6. Energy Management:\n   - Track energy usage for HVAC, lighting, etc.\n   - Identify wastage & optimization opportunity\n   - Generate energy report\n\nKelebihan BMS: Centralized monitoring, remote control, trend analysis, predictive maintenance, energy saving, dan compliance reporting.',
      ),
      InterviewItem(
        question: 'Arahan JKR yang perlu dipatuhi dalam FM?',
        answer:
            'Dokumen dan garis panduan JKR:\n\n1. PPM (Pelan Penyelenggaraan Pencegahan):\n   - Dokumen rujukan utama untuk skop PM setiap sistem\n   - Tetapkan kekerapan, tindakan, dan spesifikasi\n\n2. FPPS (Functional Procurement and Professional Service):\n   - Prosedur perolehan dan pelantikan kontraktor\n\n3. SPP (Standard Procurement Procedure):\n   - Prosedur perolehan kerajaan\n\n4. SOP FM JKR:\n   - Standard Operating Procedure untuk FM\n   - Prosedur aduan, work order, pelaporan\n\n5. Garis Panduan Pengurusan Aset:\n   - Asset tagging, inventory, condition assessment\n\n6. Akta & Peraturan:\n   - Akta Kilang dan Jentera 1967\n   - Akta Keselamatan dan Kesihatan Pekerjaan 1994 (OSHA)\n   - UBBL (Uniform Building By-Laws)\n   - Akta Bomba 1988\n   - Peraturan-Peraturan Elektrik 1994\n\n7. MS & ISO:\n   - MS 1525: Energy Efficiency\n   - ISO 41001: Facility Management\n   - ISO 55001: Asset Management',
      ),
    ],
  ),
  InterviewSection(
    title: 'Ceritakan Diri Anda',
    icon: '👤',
    items: [
      InterviewItem(
        question: 'Perkenalkan diri anda dalam 2 minit',
        answer:
            'Nama saya [Nama]. Saya berpengalaman dalam kerja pembinaan, pemasangan sistem mekanikal, testing & commissioning, serta penyelenggaraan asas. Saya pernah terlibat dalam pendawaian elektrik, plumbing, roofing, dan pengurusan tapak.\n\nSaya kini ingin mengembangkan kerjaya dalam bidang Facility Management kerana saya yakin pengalaman teknikal di tapak dapat membantu saya mengurus sistem mekanikal bangunan secara lebih profesional dan sistematik.',
      ),
    ],
  ),
  InterviewSection(
    title: 'Kenapa JKR / Facility Management?',
    icon: '🎯',
    items: [
      InterviewItem(
        question: 'Kenapa anda mahu kerja di sini?',
        answer:
            'Saya ingin mengembangkan kerjaya dalam bidang Facility Management kerana saya mempunyai pengalaman teknikal di tapak pembinaan dan penyelenggaraan. Saya ingin menggunakan pengalaman tersebut dalam mengurus sistem mekanikal bangunan secara lebih profesional dan sistematik, khususnya dalam projek JKR yang memberi impak besar kepada kemudahan awam.',
      ),
      InterviewItem(
        question: 'Apa yang anda tahu tentang JKR?',
        answer:
            'JKR (Jabatan Kerja Raya) bertanggungjawab:\n• Mengurus pembangunan infrastruktur kerajaan\n• Mengurus aset dan bangunan kerajaan\n• Menyelaras projek pembangunan\n• Memastikan bangunan kerajaan selamat dan berfungsi\n\nDalam pengurusan fasiliti, JKR menekankan penyelenggaraan berjadual, pengurusan aset, dan pematuhan prosedur operasi.',
      ),
      InterviewItem(
        question: 'Apa itu Facility Management?',
        answer:
            'Facility Management (Pengurusan Fasiliti) bukan sekadar membaiki kerosakan. Ia melibatkan memastikan:\n• Keseluruhan bangunan sentiasa selamat digunakan\n• Semua sistem mekanikal berfungsi\n• Kos operasi terkawal\n• Pengguna bangunan selesa\n• Kontraktor menjalankan kerja mengikut kontrak\n• Penyelenggaraan dilakukan mengikut jadual\n\nSkop FM JKR: operasi aset, utiliti, tenaga, keselamatan, pengemasan, landskap, penyelenggaraan pencegahan dan pembaikan bagi sistem mekanikal, elektrikal dan struktur.',
      ),
    ],
  ),
  InterviewSection(
    title: 'Soalan HVAC (Aircond & Ventilasi)',
    icon: '❄️',
    items: [
      InterviewItem(
        question: 'Bagaimana anda tahu AHU rosak?',
        answer:
            'Tanda-tanda AHU rosak:\n• Suhu tidak mencapai setpoint\n• Motor overload\n• Belt putus atau haus\n• Filter tersumbat\n• Bearing berbunyi (noise)\n• Vibration tinggi\n• Airflow rendah di ducting',
      ),
      InterviewItem(
        question: 'Jika AHU tidak sejuk, apa langkah anda?',
        answer:
            'Ikut langkah sistematik ini:\n1. Semak thermostat setting\n2. Semak breaker/MCCB\n3. Semak motor - adakah running?\n4. Semak belt - adakah putus/loose?\n5. Semak filter - adakah tersumbat?\n6. Semak chilled water valve - adakah terbuka?\n7. Semak tekanan air chilled water\n8. Semak BMS untuk alarm/trend\n\nIni menunjukkan anda berfikir secara sistematik sebagai jurutera.',
      ),
      InterviewItem(
        question: 'Jika ada aduan penghawa dingin, apa tindakan anda?',
        answer:
            'Prosedur sistematik:\n1. Terima aduan & lokasi\n2. Semak severity (urgent atau tidak)\n3. Hantar technician ke lokasi\n4. Kenal pasti punca masalah\n5. Ambil tindakan sementara jika perlu\n6. Jalankan repair jika minor\n7. Testing selepas repair\n8. Tutup aduan (close report)\n9. Buat laporan lengkap',
      ),
      InterviewItem(
        question: 'Apa fungsi cooling tower?',
        answer:
            'Cooling tower berfungsi untuk membuang haba dari sistem chilled water melalui proses penyejatan air (evaporation). Air panas dari condenser chiller dipam ke cooling tower, disembur melalui nozzle, dan kipas meniup udara untuk menyejukkan air sebelum dikembalikan ke chiller.',
      ),
      InterviewItem(
        question: 'Apa beza FCU dengan AHU?',
        answer:
            'FCU (Fan Coil Unit): Unit kecil, biasanya dalam bilik/service area, tanpa fresh air intake, kawalan setempat.\n\nAHU (Air Handling Unit): Unit besar, central, ada fresh air intake, filter yang lebih lengkap, kawalan central melalui BMS, melayan beberapa zon.',
      ),
      InterviewItem(
        question: 'Apa itu VRF system?',
        answer:
            'VRF (Variable Refrigerant Flow) adalah sistem penghawa dingin yang menggunakan refrigerant sebagai medium penyejukan/pemanasan. Satu outdoor unit boleh melayan beberapa indoor unit dengan kawalan refrigerant flow yang berbeza. Kelebihan: individual control, energy efficient, less ductwork.',
      ),
    ],
  ),
  InterviewSection(
    title: 'Fire Fighting System',
    icon: '🔥',
    items: [
      InterviewItem(
        question: 'Apa fungsi jockey pump?',
        answer:
            'Jockey pump berfungsi mengekalkan tekanan dalam sistem paip fire fighting supaya fire pump utama tidak perlu hidup setiap kali ada sedikit penurunan tekanan. Ia pam kecil yang auto start/stop berdasarkan tekanan sistem.',
      ),
      InterviewItem(
        question: 'Apa beza fire pump diesel dan electric?',
        answer:
            'Fire pump electric menggunakan bekalan kuasa elektrik. Fire pump diesel menggunakan enjin diesel sebagai backup jika bekalan elektrik terputus. Kedua-duanya mesti diuji secara berkala (weekly run).',
      ),
      InterviewItem(
        question: 'Bagaimana sistem sprinkler berfungsi?',
        answer:
            'Kepala sprinkler mengandungi bulb kaca yang akan pecah pada suhu tertentu (biasanya 68°C). Apabila bulb pecah, air akan keluar dari paip sistem. Sistem ini akan terus beroperasi sehingga valve utama ditutup secara manual.',
      ),
      InterviewItem(
        question: 'Apa yang perlu diperiksa pada fire extinguisher?',
        answer:
            'Pemeriksaan fire extinguisher:\n• Tekanan dalam green zone\n• Berat - masih mencukupi\n• Tarikh luput (pressure test)\n• Pin keselamatan masih ada\n• Hose tidak rosak\n• Label pemeriksaan terkini\n• Tiada halangan di hadapan',
      ),
    ],
  ),
  InterviewSection(
    title: 'Plumbing & Water Supply',
    icon: '💧',
    items: [
      InterviewItem(
        question: 'Apa fungsi booster pump?',
        answer:
            'Booster pump berfungsi meningkatkan tekanan air dari tangki simpanan bawah (ground tank) atau dari bekalan utama untuk dihantar ke tangki atas (roof tank) atau terus ke paip bangunan bertingkat.',
      ),
      InterviewItem(
        question: 'Jika pam air gagal beroperasi, apa tindakan anda?',
        answer:
            'Situasi -> Analisis -> Tindakan -> Hasil:\n\n1. Pastikan keselamatan kawasan\n2. Semak bekalan kuasa & panel kawalan\n3. Kenal pasti punca: motor, breaker, sensor, atau kabel\n4. Selaras pembaikan dengan juruteknik/kontraktor\n5. Selepas pembaikan, uji sistem\n6. Sediakan laporan untuk cegahan masa depan',
      ),
      InterviewItem(
        question: 'Apa itu hydro-pneumatic system?',
        answer:
            'Sistem yang menggunakan pressure vessel (tangki berisi air dan udara termampat) untuk mengekalkan tekanan air tanpa perlu pam hidup setiap kali. Apabila tekanan turun, pam akan hidup semula. Ini mengurangkan kitaran hidup/mati pam.',
      ),
    ],
  ),
  InterviewSection(
    title: 'Lift & Generator',
    icon: '⚡',
    items: [
      InterviewItem(
        question: 'Apa tugas jurutera fasiliti terhadap lift?',
        answer:
            'Walaupun kontraktor yang menjaga lift, jurutera fasiliti perlu:\n• Semak laporan pemeriksaan CP DOSH\n• Pastikan PM dibuat mengikut jadual\n• Pantau downtime dan breakdown\n• Pastikan keselamatan pengguna\n• Koordinasi dengan kontraktor jika ada masalah',
      ),
      InterviewItem(
        question: 'Apa itu ATS dan AMF?',
        answer:
            'ATS (Automatic Transfer Switch): Menukar bekalan elektrik dari utama (utility) ke generator secara automatik apabila bekalan utama terputus.\n\nAMF (Automatic Mains Failure): Sistem yang mengesan kegagalan bekalan utama dan memulakan generator secara automatik.',
      ),
      InterviewItem(
        question: 'Apakah weekly test untuk generator?',
        answer:
            'Weekly test generator:\n• Jalankan generator selama 15-30 minit dengan beban\n• Periksa suhu enjin, tekanan minyak, bateri\n• Periksa fuel level\n• Periksa ATS berfungsi\n• Pastikan tiada kebocoran (minyak, fuel, coolant)\n• Catat bacaan dalam log book',
      ),
    ],
  ),
  InterviewSection(
    title: 'PM vs CM vs PdM',
    icon: '📊',
    items: [
      InterviewItem(
        question: 'Apa beza PM, CM dan PdM?',
        answer:
            'PM (Preventive Maintenance): Penyelenggaraan berjadual sebelum rosak. Contoh: tukar bearing, grease motor, tukar belt, bersih filter.\n\nCM (Corrective Maintenance): Pembaikan selepas rosak. Contoh: motor pump terbakar - baru tukar.\n\nPdM (Predictive Maintenance): Berdasarkan data dan kondisi. Contoh: vibration analysis, thermal imaging, oil analysis. Dilakukan hanya bila diperlukan.',
      ),
    ],
  ),
  InterviewSection(
    title: 'Root Cause Analysis',
    icon: '🔍',
    items: [
      InterviewItem(
        question: 'Apa itu Root Cause Analysis (RCA)?',
        answer:
            'RCA adalah kaedah mencari punca sebenar sesuatu masalah, bukan hanya memperbaiki simptom.\n\nContoh: Motor pump terbakar.\n• Simptom: Motor terbakar\n• Punca segera: Overload\n• Root cause: Bearing motor haus → rotor jam → arus tinggi → overload\n\nTindakan: Bukan saja tukar motor, tapi kena pastikan bearing baru dan schedule PM untuk lubrication bearing.',
      ),
      InterviewItem(
        question: 'Terangkan kaedah 5 Whys',
        answer:
            'Kaedah 5 Whys: Tanya "Kenapa" sebanyak 5 kali untuk sampai ke punca sebenar.\n\nContoh: Chiller trip.\n1. Kenapa trip? - High pressure\n2. Kenapa high pressure? - Condenser kotor\n3. Kenapa condenser kotor? - Cooling tower basin kotor\n4. Kenapa basin kotor? - Bleed valve tak berfungsi\n5. Kenapa tak berfungsi? - Tiada PM schedule untuk bleed valve\n\nRoot cause: Tiada PM pada bleed valve cooling tower.',
      ),
    ],
  ),
  InterviewSection(
    title: 'Troubleshooting Situations',
    icon: '🛠️',
    items: [
      InterviewItem(
        question: 'Jika chiller tiba-tiba shutdown, apa tindakan?',
        answer:
            '1. Pastikan keselamatan (electrical safety, refrigerant leak)\n2. Semak alarm pada chiller panel\n3. Semak BMS untuk trend/parameter\n4. Semak tekanan refrigerant\n5. Semak electrical supply (voltage, current)\n6. Hubungi vendor jika perlu\n7. Aktifkan contingency plan (contoh: portable AC)\n8. Sediakan report dan RCA',
      ),
      InterviewItem(
        question: 'Bagaimana mengurus banyak aduan serentak?',
        answer:
            'Utamakan berdasarkan:\n1. Keselamatan - mengancam nyawa?\n2. Operasi kritikal - sistem penting terjejas?\n3. Bilangan pengguna terlibat\n4. Severity - berapa serius?\n\nBuat sistem triage: Urgent -> High -> Medium -> Low. Sentiasa update pengadu tentang status.',
      ),
      InterviewItem(
        question: 'Apa tindakan jika ada kebocoran gas?',
        answer:
            '1. Jangan ON/OFF sebarang suis elektrik\n2. Buka tingkap/pintu untuk ventilasi\n3. Tutup valve gas utama\n4. Keluarkan orang dari kawasan\n5. Hubungi pihak bomba/fire department\n6. Jangan masuk sehingga gas hilang\n7. Selepas selamat, cari punca bocor\n8. Repair dan test sebelum buka semula',
      ),
    ],
  ),
  InterviewSection(
    title: 'Contractor Management',
    icon: '👷',
    items: [
      InterviewItem(
        question: 'Bagaimana anda mengurus kontraktor?',
        answer:
            'Sebagai jurutera, anda bukan buat semua kerja sendiri. Tanggungjawab:\n• Beri arahan jelas (scope of work)\n• Semak method statement\n• Semak permit kerja/work permit\n• Pastikan PPE dipakai\n• Semak kualiti kerja\n• Witness testing & commissioning\n• Verify completion\n• Approve claim jika ikut kontrak\n\nGaris panduan JKR menekankan pemantauan kerja operasi dan penyenggaraan serta pengesahan kualiti kerja sebelum pembayaran.',
      ),
      InterviewItem(
        question: 'Arahan Keselamatan (HSE) untuk kontraktor?',
        answer:
            'Kontraktor mesti:\n• Ada permit kerja (hot work, working at height, etc.)\n• Pakai PPE lengkap (helmet, vest, safety shoes)\n• Ada method statement (MS)\n• Ada JSA/HIRARC\n• Pastikan kawasan kerja selamat\n• Mesin/peralatan ada valid certificate\n• Buat toolbox meeting sebelum kerja',
      ),
    ],
  ),
  InterviewSection(
    title: 'KPI & Performance',
    icon: '📈',
    items: [
      InterviewItem(
        question: 'KPI apa yang biasa digunakan dalam FM?',
        answer:
            'KPI lazim:\n• Response Time - masa respon aduan\n• Rectification Time - masa siap repair\n• PM Compliance - % PM siap ikut jadual\n• Downtime - masa sistem tidak beroperasi\n• Asset Availability - % masa sistem available\n• Customer Satisfaction - kepuasan pengguna\n• Backlog - jumlah kerja tertunggak\n• Cost per unit area - kos penyelenggaraan',
      ),
    ],
  ),
  InterviewSection(
    title: 'Tips Temuduga',
    icon: '💡',
    items: [
      InterviewItem(
        question: 'Bagaimana nak jawab soalan teknikal?',
        answer:
            'Guna kaedah S-A-A-R:\n\nSituation - Terangkan situasi\nAnalysis - Analisa masalah\nAction - Tindakan anda\nResult - Hasil tindakan\n\nContoh: "Jika pam air gagal beroperasi, saya akan (S) pastikan keselamatan kawasan, (A) semak bekalan kuasa dan panel, (A) kenal pasti punca, (R) selaras pembaikan, uji sistem, dan buat laporan."',
      ),
      InterviewItem(
        question: 'Mengapa kami perlu ambil anda?',
        answer:
            'Saya mempunyai pengalaman dalam kerja pembinaan, pemasangan sistem, testing & commissioning, penyelenggaraan asas mekanikal dan elektrik serta penyelesaian masalah di tapak. Saya juga biasa bekerja dengan pelbagai pihak di tapak projek dan mampu belajar dengan cepat.\n\nSaya yakin pengalaman tersebut boleh membantu saya mengurus penyelenggaraan fasiliti bangunan kerajaan dengan berkesan.',
      ),
      InterviewItem(
        question: 'Apa weakness anda?',
        answer:
            'Saya baru dalam FM secara formal. Tapi saya cepat belajar dan mempunyai asas teknikal yang kuat dari pengalaman di tapak. Saya akan gunakan pengalaman sedia ada dan belajar dari rakan senior untuk menguasai FM dengan cepat.',
      ),
    ],
  ),
  InterviewSection(
    title: 'Soalan Tambahan',
    icon: '📋',
    items: [
      InterviewItem(
        question: 'Apa itu BMS?',
        answer:
            'BMS (Building Management System) adalah sistem kawalan berpusat yang memantau dan mengawal sistem mekanikal dan elektrikal bangunan seperti HVAC, lighting, fire alarm, dan tenaga. Ia membolehkan:\n• Monitoring real-time\n• Trend analysis\n• Alarm management\n• Energy optimization\n• Scheduled operation',
      ),
      InterviewItem(
        question: 'Apa itu Energy Audit?',
        answer:
            'Energy audit adalah proses mengenal pasti peluang penjimatan tenaga dalam bangunan. Ia melibatkan:\n1. Data collection - bil elektrik, bacaan meter\n2. Walkthrough survey - periksa sistem utama\n3. Analysis - cari wastage\n4. Recommendation - cadangan penjimatan\n5. Implementation - laksana\n6. Monitoring - pantau hasil\n\nContoh: ubah setpoint, install VSD pada pump/fan, tukar ke LED, optimize schedule HVAC.',
      ),
      InterviewItem(
        question: 'Apa tindakan jika berlaku banjir/water leakage di bangunan?',
        answer:
            '1. Pastikan keselamatan - risiko elektrik?\n2. Kenal pasti punca kebocoran\n3. Tutup valve air utama jika perlu\n4. Alihkan barang berharga\n5. Gunakan pump untuk buang air\n6. Keringkan kawasan (blower/dehumidifier)\n7. Periksa kerosakan akibat air\n8. Repair dan buat laporan\n9. Ambil langkah pencegahan masa depan',
      ),
    ],
  ),
];
