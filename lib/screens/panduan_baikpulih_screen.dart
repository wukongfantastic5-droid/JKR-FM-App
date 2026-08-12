import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../data/panduan_data.dart';
import '../localization.dart';
import '../services/repair_service.dart';
import 'po_screen.dart';
import 'repair_doc_screen.dart';

class PanduanBaikpulihScreen extends StatefulWidget {
  const PanduanBaikpulihScreen({super.key});

  @override
  State<PanduanBaikpulihScreen> createState() => _PanduanBaikpulihScreenState();
}

class _PanduanBaikpulihScreenState extends State<PanduanBaikpulihScreen> {
  ComplaintData _data = ComplaintData();

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.t('bpTitle', eng)),
        actions: [_langToggle(context, eng)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        children: [
          Text(
            AppLocalizations.t('bpSubtitle', eng),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _data.name.isEmpty
                  ? Colors.amber.withValues(alpha: 0.08)
                  : Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _data.name.isEmpty
                    ? Colors.amber.withValues(alpha: 0.2)
                    : Colors.green.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _data.name.isEmpty ? Icons.edit_note_rounded : Icons.check_circle_rounded,
                  size: 18,
                  color: _data.name.isEmpty ? Colors.amber.shade700 : Colors.green.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _data.name.isEmpty
                        ? (eng ? 'Fill complaint form in Step 1 to auto-populate documents' : 'Isi borang aduan di Langkah 1 untuk isi dokumen automatik')
                        : (eng ? 'Complaint data filled â€” templates will auto-populate' : 'Data aduan diisi â€” templat akan diisi automatik'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _data.name.isEmpty ? Colors.amber.shade800 : Colors.green.shade700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(PanduanData.steps.length, (i) {
            final step = PanduanData.steps[i];
            final isLast = i == PanduanData.steps.length - 1;
            return _BPStepCard(
              step: step,
              isLast: isLast,
              eng: eng,
              data: _data,
              isFirst: i == 0,
              onDataChanged: (d) => setState(() => _data = d),
            );
          }),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    eng ? 'Reference: PPM Bangunan JKR.xlsx for scope verification.' : 'Rujukan: PPM Bangunan JKR.xlsx untuk pengesahan skop.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700, height: 1.3),
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

class _BPStepCard extends StatefulWidget {
  final BPStep step;
  final bool isLast;
  final bool eng;
  final ComplaintData data;
  final bool isFirst;
  final ValueChanged<ComplaintData> onDataChanged;

  const _BPStepCard({
    required this.step,
    required this.isLast,
    required this.eng,
    required this.data,
    required this.isFirst,
    required this.onDataChanged,
  });

  @override
  State<_BPStepCard> createState() => _BPStepCardState();
}

class _BPStepCardState extends State<_BPStepCard> {
  bool _expanded = false;

  final _nameCtrl = TextEditingController();
  final _posCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  final _buildCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _source = 'JKR';
  String _system = 'HVAC System (ACMV)';
  String _priority = 'Normal';
  String _problemType = 'Mechanical Fault';
  List<Uint8List> _images = [];
  List<String> _imageNames = [];
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _expanded = widget.isFirst;
    _nameCtrl.text = widget.data.name;
    _posCtrl.text = widget.data.position;
    _dateCtrl.text = widget.data.dateReceived;
    _timeCtrl.text = widget.data.timeReceived;
    _buildCtrl.text = widget.data.building;
    _descCtrl.text = widget.data.description;
    if (widget.data.source.isNotEmpty) _source = widget.data.source;
    if (widget.data.systemInvolved.isNotEmpty) _system = widget.data.systemInvolved;
    if (widget.data.priority.isNotEmpty) _priority = widget.data.priority;
    if (widget.data.problemType.isNotEmpty) _problemType = widget.data.problemType;
    if (widget.data.imageBase64List.isNotEmpty) {
      _images = widget.data.imageBase64List.map((e) => base64Decode(e)).toList();
      _imageNames = List.from(widget.data.imageNames);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final xFile = await _picker.pickImage(source: source, maxWidth: 1024);
    if (xFile != null) {
      final bytes = await xFile.readAsBytes();
      setState(() {
        _images.add(bytes);
        _imageNames.add(xFile.name);
      });
      _emit();
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      _imageNames.removeAt(index);
    });
    _emit();
  }

  void _emit() {
    widget.onDataChanged(ComplaintData(
      name: _nameCtrl.text,
      position: _posCtrl.text,
      source: _source,
      dateReceived: _dateCtrl.text,
      timeReceived: _timeCtrl.text,
      systemInvolved: _system,
      building: _buildCtrl.text,
      problemType: _problemType,
      description: _descCtrl.text,
      priority: _priority,
      imageBase64List: _images.map((e) => base64Encode(e)).toList(),
      imageNames: List.from(_imageNames),
    ));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _posCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _buildCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  final _sources = ['KKR', 'JKR', 'FMI'];
  final _systemsEn = [
    'HVAC System (ACMV)', 'Fire Fighting System', 'Lift System',
    'Gondola System', 'Water Supply & Plumbing', 'Kitchen System',
    'Irrigation & Landscape', 'Other Mechanical System',
  ];
  final _systemsBm = [
    'Sistem HVAC (ACMV)', 'Sistem Pemadam Kebakaran', 'Sistem Lif',
    'Sistem Gondola', 'Bekalan Air & Paip', 'Sistem Dapur',
    'Pengairan & Landskap', 'Sistem Mekanikal Lain',
  ];
  final _priorities = ['Emergency', 'Urgent', 'Normal'];
  final _pTypesEn = ['Mechanical Fault', 'Electrical Fault', 'Leakage / Water Damage', 'Noise / Vibration', 'Control Failure', 'Structural Damage', 'Other'];
  final _pTypesBm = ['Kerosakan Mekanikal', 'Kerosakan Elektrikal', 'Bocor / Kerosakan Air', 'Bunyi / Gegaran', 'Kegagalan Kawalan', 'Kerosakan Struktur', 'Lain-lain'];

  @override
  Widget build(BuildContext context) {
    final s = widget.step;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: s.color.withValues(alpha: 0.3)),
                  ),
                  child: Center(child: Text(s.icon, style: const TextStyle(fontSize: 18))),
                ),
                if (!widget.isLast)
                  Expanded(
                    child: Container(width: 2, color: s.color.withValues(alpha: 0.2)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: s.color.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                AppLocalizations.t(s.titleKey, widget.eng),
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: s.color, height: 1.2),
                              ),
                            ),
                            Icon(
                              _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              size: 20, color: s.color,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.t(s.descKey, widget.eng),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                      ),
                      if (_expanded) ...[
                        const SizedBox(height: 8),
                        if (widget.isFirst) _buildForm(),
                        if (s.titleKey == 'bpStep3Title') ...[
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          _DocsWorkspace(eng: widget.eng),
                        ] else if (s.templates.isNotEmpty) ...[
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Text(
                            widget.eng ? 'Available Templates:' : 'Templat Tersedia:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: s.color),
                          ),
                          const SizedBox(height: 6),
                          ...s.templates.map((t) => _BPTemplateCard(
                            template: t, color: s.color, eng: widget.eng, data: widget.data,
                          )),
                        ],
                        if (s.templates.isEmpty && s.titleKey == 'bpStep2Title')
                          _ScopeDecision(color: s.color, eng: widget.eng),
                        if (s.templates.isEmpty && s.titleKey == 'bpStep4Title')
                          _ApprovalDecision(color: s.color, eng: widget.eng),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        _buildField(widget.eng ? 'Complainer Name' : 'Nama Pengadu', _nameCtrl, Icons.person_rounded),
        const SizedBox(height: 8),
        _buildField(widget.eng ? 'Position' : 'Jawatan', _posCtrl, Icons.badge_rounded),
        const SizedBox(height: 8),
        _buildDropdown(widget.eng ? 'Source (KKR/JKR/FMI)' : 'Sumber (KKR/JKR/FMI)', _source, _sources, (v) {
          setState(() { _source = v!; _emit(); });
        }),
        const SizedBox(height: 8),
        _buildDateField(),
        const SizedBox(height: 8),
        _buildTimeField(),
        const SizedBox(height: 8),
        _buildDropdown(widget.eng ? 'System Involved' : 'Sistem Terlibat', _system, widget.eng ? _systemsEn : _systemsBm, (v) {
          setState(() { _system = v!; _emit(); });
        }, icon: Icons.build_rounded),
        const SizedBox(height: 8),
        _buildDropdown(widget.eng ? 'Problem Type' : 'Jenis Masalah', _problemType, widget.eng ? _pTypesEn : _pTypesBm, (v) {
          setState(() { _problemType = v!; _emit(); });
        }, icon: Icons.report_problem_rounded),
        const SizedBox(height: 8),
        _buildField(widget.eng ? 'Building / Location' : 'Bangunan / Lokasi', _buildCtrl, Icons.location_on_rounded),
        const SizedBox(height: 8),
        _buildDropdown(widget.eng ? 'Priority' : 'Keutamaan', _priority, _priorities, (v) {
          setState(() { _priority = v!; _emit(); });
        }, icon: Icons.flag_rounded),
        const SizedBox(height: 8),
        _buildField(widget.eng ? 'Description of Issue' : 'Penerangan Masalah', _descCtrl, Icons.description_rounded, maxLines: 3),
        const SizedBox(height: 8),
        _buildPhotoSection(),
      ],
    );
  }

  Widget _buildPhotoSection() {
    final eng = widget.eng;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eng ? 'Photos of Issue' : 'Gambar Masalah',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _photoButton(
              icon: Icons.camera_alt_rounded,
              label: eng ? 'Camera' : 'Kamera',
              color: Colors.blue,
              onTap: () => _pickImage(ImageSource.camera),
            ),
            const SizedBox(width: 8),
            _photoButton(
              icon: Icons.photo_library_rounded,
              label: eng ? 'Gallery' : 'Galeri',
              color: Colors.green,
              onTap: () => _pickImage(ImageSource.gallery),
            ),
          ],
        ),
        if (_images.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_images.length, (i) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _images[i],
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: -4,
                    right: -4,
                    child: GestureDetector(
                      onTap: () => _removeImage(i),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            eng ? '${_images.length} image(s) attached' : '${_images.length} gambar dilampirkan',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ],
    );
  }

  Widget _photoButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    final eng = widget.eng;
    return Row(
      children: [
        Expanded(
          child: _buildField(eng ? 'Date (dd/mm/yyyy)' : 'Tarikh (hh/bb/tttt)', _dateCtrl, Icons.calendar_today_rounded),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.date_range_rounded),
          tooltip: eng ? 'Pick date' : 'Pilih tarikh',
          style: IconButton.styleFrom(
            backgroundColor: Colors.blue.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: now,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              helpText: eng ? 'Select complaint date' : 'Pilih tarikh aduan',
            );
            if (picked != null) {
              _dateCtrl.text = '${picked.day}/${picked.month}/${picked.year}';
              _emit();
            }
          },
        ),
      ],
    );
  }

  Widget _buildTimeField() {
    final eng = widget.eng;
    return Row(
      children: [
        Expanded(
          child: _buildField(eng ? 'Time (HH:MM)' : 'Masa (HH:MM)', _timeCtrl, Icons.access_time_rounded),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.watch_later_rounded),
          tooltip: eng ? 'Now' : 'Sekarang',
          style: IconButton.styleFrom(
            backgroundColor: Colors.green.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            final now = DateTime.now();
            _timeCtrl.text = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            _emit();
          },
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.access_time_rounded),
          tooltip: eng ? 'Pick time' : 'Pilih masa',
          style: IconButton.styleFrom(
            backgroundColor: Colors.orange.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () async {
            final now = TimeOfDay.now();
            final picked = await showTimePicker(
              context: context,
              initialTime: now,
              helpText: eng ? 'Select complaint time' : 'Pilih masa aduan',
            );
            if (picked != null) {
              _timeCtrl.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
              _emit();
            }
          },
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
      style: const TextStyle(fontSize: 13),
      onChanged: (_) => _emit(),
    );
  }

  Widget _buildDropdown(String label, String currentValue, List<String> items, ValueChanged<String?> onChanged, {IconData? icon}) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentValue,
          isDense: true,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: Color(0xFF37474F)),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _BPTemplateCard extends StatelessWidget {
  final BPTemplate template;
  final Color color;
  final bool eng;
  final ComplaintData data;

  const _BPTemplateCard({
    required this.template,
    required this.color,
    required this.eng,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _showTemplate(context),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.description_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  eng ? template.title : template.titleBM,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, height: 1.2),
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 14, color: color.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormalLetterContent(String filledContent) {
    const marker = '________________________';
    final idx = filledContent.lastIndexOf(marker);
    if (idx == -1) {
      return SelectableText(
        filledContent,
        style: const TextStyle(fontSize: 12, color: Color(0xFF37474F), height: 1.5, fontFamily: 'monospace'),
      );
    }
    final before = filledContent.substring(0, idx);
    final after = filledContent.substring(idx + marker.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          before,
          style: const TextStyle(fontSize: 12, color: Color(0xFF37474F), height: 1.5, fontFamily: 'monospace'),
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Image.asset(
            'assets/images/signature.png',
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (ctx2, err, stk) => Container(
              height: 30,
              color: Colors.grey.shade200,
              child: const Center(child: Text('(signature)', style: TextStyle(fontSize: 10, color: Colors.grey))),
            ),
          ),
        ),
        Text(
          '________________________',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontFamily: 'monospace', height: 1.0),
        ),
        const SizedBox(height: 2),
        SelectableText(
          after,
          style: const TextStyle(fontSize: 12, color: Color(0xFF37474F), height: 1.5, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  void _showTemplate(BuildContext context) {
    final filledContent = fillTemplate(eng ? template.content : template.contentBM, data);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.description_rounded, size: 20, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      eng ? template.title : template.titleBM,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                    color: color,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (template.title.contains('Formal Letter') || template.titleBM.contains('Surat Rasmi'))
                      _buildFormalLetterContent(filledContent)
                    else
                      SelectableText(
                        filledContent,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF37474F), height: 1.5, fontFamily: 'monospace'),
                      ),
                    if (data.imageBase64List.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        eng ? 'Attached Photos:' : 'Gambar Dilampirkan:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 6),
                      ...data.imageBase64List.map((b64) {
                        final bytes = base64Decode(b64);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(bytes, fit: BoxFit.contain, width: double.infinity),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocsWorkspace extends StatelessWidget {
  final bool eng;
  const _DocsWorkspace({required this.eng});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D7377),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: const Icon(Icons.receipt_long_rounded, size: 18),
            label: Text(
              eng ? 'Purchase Order (Mechanical)' : 'Pesanan Belian (Mekanikal)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PoScreen()),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D7377),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: const Icon(Icons.description_rounded, size: 18),
            label: Text(
              eng ? 'Prepare Documents Workspace' : 'Ruang Kerja Sedia Dokumen',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RepairDocScreen()),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7C3AED),
              side: const BorderSide(color: Color(0xFF7C3AED), width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: Text(
              eng ? 'Upload Template Sheet (reference)' : 'Muat Naik Helaian Templat (rujukan)',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            onPressed: () => _uploadTemplate(context),
          ),
        ),
        Text(
          eng
              ? 'Fully branded documents (logo header, field tables, photos & signature) are generated and saved in the database. Upload your own template sheets as reference — they are stored under Templates/RepairGuide.'
              : 'Dokumen berjenama lengkap (kepala logo, jadual medan, gambar & tandatangan) dijana dan disimpan dalam database. Muat naik helaian templat anda sendiri sebagai rujukan — disimpan di bawah Templates/RepairGuide.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.35),
        ),
      ],
    );
  }

  Future<void> _uploadTemplate(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'doc', 'xlsx', 'xls', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    if (f.bytes == null || f.bytes!.isEmpty) return;
    final ok = await RepairService.uploadTemplate(f.name, f.bytes!);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (eng ? 'Template saved in database' : 'Templat disimpan dalam database')
            : (eng ? 'Upload failed' : 'Muat naik gagal')),
      ));
    }
  }
}

class _ScopeDecision extends StatelessWidget {
  final Color color;
  final bool eng;
  const _ScopeDecision({required this.color, required this.eng});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: Colors.green.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppLocalizations.t('bpInScope', eng),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.cancel_rounded, size: 16, color: Colors.red.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppLocalizations.t('bpOutScope', eng),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApprovalDecision extends StatelessWidget {
  final Color color;
  final bool eng;
  const _ApprovalDecision({required this.color, required this.eng});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.thumb_up_rounded, size: 16, color: Colors.green.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppLocalizations.t('bpApproved', eng),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.archive_rounded, size: 16, color: Colors.orange.shade600),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  AppLocalizations.t('bpRejected', eng),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange.shade700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
