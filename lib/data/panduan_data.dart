import 'package:flutter/material.dart';

class ComplaintData {
  String name;
  String position;
  String source;
  String dateReceived;
  String timeReceived;
  String systemInvolved;
  String building;
  String problemType;
  String description;
  String priority;
  List<String> imageBase64List;
  List<String> imageNames;

  ComplaintData({
    this.name = '',
    this.position = '',
    this.source = 'JKR',
    this.dateReceived = '',
    this.timeReceived = '',
    this.systemInvolved = '',
    this.building = '',
    this.problemType = '',
    this.description = '',
    this.priority = 'Normal',
    this.imageBase64List = const [],
    this.imageNames = const [],
  });

  ComplaintData copy() => ComplaintData(
    name: name, position: position, source: source,
    dateReceived: dateReceived, timeReceived: timeReceived,
    systemInvolved: systemInvolved, building: building,
    problemType: problemType, description: description, priority: priority,
    imageBase64List: List.from(imageBase64List),
    imageNames: List.from(imageNames),
  );
}

String fillTemplate(String template, ComplaintData d) {
  final now = DateTime.now();
  final dateStr = d.dateReceived.isEmpty ? '${now.day}/${now.month}/${now.year}' : d.dateReceived;
  final timeStr = d.timeReceived.isEmpty ? '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}' : d.timeReceived;

  final imgCount = d.imageBase64List.length;
  final imgList = imgCount > 0
      ? d.imageNames.asMap().entries.map((e) => '  ${e.key + 1}. ${e.value}').join('\n')
      : '  (none)';

  final map = {
    '{{name}}': d.name,
    '{{position}}': d.position,
    '{{source}}': d.source,
    '{{date}}': dateStr,
    '{{time}}': timeStr,
    '{{system}}': d.systemInvolved,
    '{{building}}': d.building,
    '{{problem_type}}': d.problemType,
    '{{description}}': d.description,
    '{{priority}}': d.priority,
    '{{imageCount}}': imgCount.toString(),
    '{{imageList}}': imgList,
  };

  var result = template;
  for (final e in map.entries) {
    result = result.replaceAll(e.key, e.value.isEmpty ? '_______________' : e.value);
  }
  return result;
}

class BPTemplate {
  final String title;
  final String titleBM;
  final String content;
  final String contentBM;

  const BPTemplate({
    required this.title,
    required this.titleBM,
    required this.content,
    required this.contentBM,
  });
}

class BPStep {
  final String titleKey;
  final String icon;
  final Color color;
  final String descKey;
  final List<BPTemplate> templates;

  const BPStep({
    required this.titleKey,
    required this.icon,
    required this.color,
    required this.descKey,
    this.templates = const [],
  });
}

class PanduanData {
  static const List<BPStep> steps = [
    BPStep(
      titleKey: 'bpStep1Title',
      icon: '📞',
      color: Color(0xFF0288D1),
      descKey: 'bpStep1Desc',
      templates: [],
    ),
    BPStep(
      titleKey: 'bpStep2Title',
      icon: '🔍',
      color: Color(0xFF0D7377),
      descKey: 'bpStep2Desc',
      templates: [],
    ),
    BPStep(
      titleKey: 'bpStep3Title',
      icon: '📄',
      color: Color(0xFFF9A825),
      descKey: 'bpStep3Desc',
      templates: [
        BPTemplate(
          title: 'Incident / Complaint Report',
          titleBM: 'Laporan Insiden / Aduan',
          content: '''INCIDENT REPORT

Ref No: JKR/FS/{{building}}/{{date}}
Date: {{date}}
Time: {{time}}
Reported by: {{name}} ({{position}})
Source: {{source}}

BUILDING / LOCATION: {{building}}
SYSTEM INVOLVED: {{system}}
PROBLEM TYPE: {{problem_type}}
PRIORITY: {{priority}}

DESCRIPTION OF ISSUE:
{{description}}

ATTACHMENTS:
[x] Photos ({{imageCount}} images)

Image List:
{{imageList}}

[  ] Drawings / Diagrams
[  ] Previous Reports
[  ] Site Measurements

Prepared by: {{name}}
Designation: {{position}}
Date: {{date}}
''',
          contentBM: '''LAPORAN INSIDEN

No Ruj: JKR/FS/{{building}}/{{date}}
Tarikh: {{date}}
Masa: {{time}}
Dilapor oleh: {{name}} ({{position}})
Sumber: {{source}}

BANGUNAN / LOKASI: {{building}}
SISTEM TERLIBAT: {{system}}
JENIS MASALAH: {{problem_type}}
KEUTAMAAN: {{priority}}

PENERANGAN MASALAH:
{{description}}

LAMPIRAN:
[x] Gambar ({{imageCount}} gambar)

Senarai Gambar:
{{imageList}}

[  ] Lukisan / Gambar Rajah
[  ] Laporan Lepas
[  ] Ukuran Tapak

Disedia oleh: {{name}}
Jawatan: {{position}}
Tarikh: {{date}}
''',
        ),
        BPTemplate(
          title: 'Formal Letter to JKR/KKR',
          titleBM: 'Surat Rasmi kepada JKR/KKR',
          content: '''[CAKRA MAHKOTA SDN BHD]
Blok G, Ibu Pejabat JKR,
Jalan Sultan Salahuddin,
50480 Kuala Lumpur.

Our Ref: JKR/FS/{{building}}/{{date}}
Date: {{date}}

Kepada,
Pengarah Bahagian Penyelenggaraan Fasiliti,
Jabatan Kerja Raya Malaysia,
Ibu Pejabat JKR,
Jalan Sultan Salahuddin,
50480 Kuala Lumpur.

Daripada: ZAINALABIDIN BIN CHE HASSAN
Jawatan: Jurutera Mekanikal (Mechanical Engineer)
Syarikat: Cakra Mahkota Sdn Bhd

Tuan,

LAPORAN KEROSAKAN / ADUAN – SISTEM {{system}} DI {{building}}

Dengan segala hormatnya saya merujuk kepada perkara di atas.

2. Adalah dengan ini dilaporkan bahawa satu aduan telah diterima daripada {{source}} pada {{date}} ({{time}}) berkenaan {{problem_type}} yang melibatkan sistem {{system}} di {{building}}.

3. Butiran aduan adalah seperti berikut:
───────────────────────────────────────
Lokasi            : {{building}}
Sistem            : {{system}}
Jenis Kerosakan   : {{problem_type}}
Tarikh Aduan      : {{date}}
Masa Aduan        : {{time}}
Pelapor           : {{name}} ({{position}})
Keutamaan         : {{priority}}
───────────────────────────────────────

4. Pemerihalan masalah:
{{description}}

5. Tindakan yang dicadangkan:
  i.   Menjalankan pemeriksaan terperinci di tapak
  ii.  Menyediakan laporan penuh berserta dokumentasi bergambar
  iii. Mengemukakan cadangan kos pembaikan untuk kelulusan

6. Bersama-sama ini disertakan dokumen-dokumen berikut untuk rujukan dan tindakan selanjutnya:
  i.   Borang Laporan Insiden / Aduan
  ii.  Gambar-gambar kerosakan ({{imageCount}} keping)
  iii. Anggaran kos sementara

Sekian, terima kasih.

Yang benar,

________________________
ZAINALABIDIN BIN CHE HASSAN
Jurutera Mekanikal
Cakra Mahkota Sdn Bhd
(Tarikh: {{date}})
''',
          contentBM: '''[CAKRA MAHKOTA SDN BHD]
Blok G, Ibu Pejabat JKR,
Jalan Sultan Salahuddin,
50480 Kuala Lumpur.

Ruj Kami: JKR/FS/{{building}}/{{date}}
Tarikh: {{date}}

Kepada,
Pengarah Bahagian Penyelenggaraan Fasiliti,
Jabatan Kerja Raya Malaysia,
Ibu Pejabat JKR,
Jalan Sultan Salahuddin,
50480 Kuala Lumpur.

Daripada: ZAINALABIDIN BIN CHE HASSAN
Jawatan: Jurutera Mekanikal (Mechanical Engineer)
Syarikat: Cakra Mahkota Sdn Bhd

Tuan,

LAPORAN KEROSAKAN / ADUAN – SISTEM {{system}} DI {{building}}

Dengan segala hormatnya saya merujuk kepada perkara di atas.

2. Adalah dengan ini dilaporkan bahawa satu aduan telah diterima daripada {{source}} pada {{date}} ({{time}}) berkenaan {{problem_type}} yang melibatkan sistem {{system}} di {{building}}.

3. Butiran aduan adalah seperti berikut:
───────────────────────────────────────
Lokasi            : {{building}}
Sistem            : {{system}}
Jenis Kerosakan   : {{problem_type}}
Tarikh Aduan      : {{date}}
Masa Aduan        : {{time}}
Pelapor           : {{name}} ({{position}})
Keutamaan         : {{priority}}
───────────────────────────────────────

4. Pemerihalan masalah:
{{description}}

5. Tindakan yang dicadangkan:
  i.   Menjalankan pemeriksaan terperinci di tapak
  ii.  Menyediakan laporan penuh berserta dokumentasi bergambar
  iii. Mengemukakan cadangan kos pembaikan untuk kelulusan

6. Bersama-sama ini disertakan dokumen-dokumen berikut untuk rujukan dan tindakan selanjutnya:
  i.   Borang Laporan Insiden / Aduan
  ii.  Gambar-gambar kerosakan ({{imageCount}} keping)
  iii. Anggaran kos sementara

Sekian, terima kasih.

Yang benar,

________________________
ZAINALABIDIN BIN CHE HASSAN
Jurutera Mekanikal
Cakra Mahkota Sdn Bhd
(Tarikh: {{date}})
''',
        ),
        BPTemplate(
          title: 'Budget / Cost Proposal',
          titleBM: 'Cadangan Kos / Belanjawan',
          content: '''COST PROPOSAL

Project: Repair of {{system}} – {{building}}
Ref No: JKR/FS/{{building}}/{{date}}
Date: {{date}}
Prepared by: {{name}}

| No | Item Description                        | Qty | Unit Price (RM) | Total (RM) |
|----|-----------------------------------------|-----|-----------------|------------|
| 1  | Labour / Buruh                          |     |                 |            |
| 2  | Materials / Bahan                       |     |                 |            |
| 3  | Equipment / Peralatan                   |     |                 |            |
| 4  | Transport / Pengangkutan                |     |                 |            |
| 5  | Disposal / Pelupusan                    |     |                 |            |
|    |                                         |     | SUBTOTAL        |            |
|    |                                         |     | Contingency 10% |            |
|    |                                         |     | TOTAL           |            |

Notes:
- Validity of quotation: 30 days
- Subject to site verification

Prepared by: {{name}}
Checked by: _______________
Approved by: _______________
Date: {{date}}
''',
          contentBM: '''CADANGAN KOS

Projek: Pembaikan {{system}} – {{building}}
Ruj No: JKR/FS/{{building}}/{{date}}
Tarikh: {{date}}
Disedia oleh: {{name}}

| Bil | Penerangan Item                        | Kuantiti | Harga Unit (RM) | Jumlah (RM) |
|-----|---------------------------------------|----------|-----------------|-------------|
| 1   | Buruh / Labour                        |          |                 |             |
| 2   | Bahan / Materials                     |          |                 |             |
| 3   | Peralatan / Equipment                 |          |                 |             |
| 4   | Pengangkutan / Transport              |          |                 |             |
| 5   | Pelupusan / Disposal                  |          |                 |             |
|     |                                       |          | SUBJUMLAH       |             |
|     |                                       |          | Kontigensi 10%  |             |
|     |                                       |          | JUMLAH          |             |

Nota:
- Tempoh sah quotation: 30 hari
- Tertakluk kepada pengesahan tapak

Disedia oleh: {{name}}
Disemak oleh: _______________
Diluluskan oleh: _______________
Tarikh: {{date}}
''',
        ),
      ],
    ),
    BPStep(
      titleKey: 'bpStep4Title',
      icon: '✅',
      color: Color(0xFF2E7D32),
      descKey: 'bpStep4Desc',
      templates: [],
    ),
    BPStep(
      titleKey: 'bpStep5Title',
      icon: '📋',
      color: Color(0xFFE64A19),
      descKey: 'bpStep5Desc',
      templates: [
        BPTemplate(
          title: 'Permit to Work',
          titleBM: 'Permit Kerja',
          content: '''PERMIT TO WORK

Permit No: JKR/PTW/{{building}}/{{date}}
Date: {{date}}
Location: {{building}}

Work Description: Repair of {{system}} – {{problem_type}}
Reported by: {{name}} ({{position}})
Source of Complaint: {{source}}

Contractor: _______________
Supervisor: _______________

Validity Period:
From: _______________  To: _______________

Work Type:
[  ] Mechanical    [  ] Electrical    [  ] Civil    [  ] Other

Hazard Identification:
[  ] Working at height    [  ] Hot work
[  ] Electrical hazard    [  ] Confined space
[  ] Chemical             [  ] Heavy lifting

PPE Required:
[  ] Helmet      [  ] Safety shoes    [  ] Harness
[  ] Gloves      [  ] Safety glasses  [  ] Hearing protection

Isolation / Lockout-Tagout:
[  ] Electrical isolation
[  ] Mechanical isolation
[  ] Pipeline isolation
[  ] Gas isolation

Authorized Signatures:

Applicant: ___________________  Date: ________
HSE Officer: _________________  Date: ________
Project Manager: _____________  Date: ________

Work Completed:
Date: _______________  Signature: _______________
''',
          contentBM: '''PERMIT KERJA

No Permit: JKR/PTW/{{building}}/{{date}}
Tarikh: {{date}}
Lokasi: {{building}}

Penerangan Kerja: Pembaikan {{system}} – {{problem_type}}
Dilapor oleh: {{name}} ({{position}})
Sumber Aduan: {{source}}

Kontraktor: _______________
Penyelia: _______________

Tempoh Sah:
Dari: _______________  Hingga: _______________

Jenis Kerja:
[  ] Mekanikal    [  ] Elektrikal    [  ] Awam    [  ] Lain

Pengenalpastian Bahaya:
[  ] Kerja tinggi    [  ] Kerja panas
[  ] Bahaya elektrik    [  ] Ruang terkurung
[  ] Kimia    [  ] Angkat berat

PPE Diperlukan:
[  ] Topi keselamatan    [  ] Kasut keselamatan    [  ] Abah-abah
[  ] Sarung tangan    [  ] Cermin mata keselamatan    [  ] Pelindung pendengaran

Pengasingan / Lockout-Tagout:
[  ] Pengasingan elektrik
[  ] Pengasingan mekanikal
[  ] Pengasingan paip
[  ] Pengasingan gas

Tandatangan Dibenarkan:

Pemohon: ___________________  Tarikh: ________
Pegawai KKP: _______________  Tarikh: ________
Pengurus Projek: ___________  Tarikh: ________

Kerja Siap:
Tarikh: _______________  Tandatangan: _______________
''',
        ),
      ],
    ),
    BPStep(
      titleKey: 'bpStep6Title',
      icon: '🔧',
      color: Color(0xFF7B1FA2),
      descKey: 'bpStep6Desc',
      templates: [],
    ),
  ];
}
