import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../localization.dart';
import '../data/complaint_data.dart';
import '../services/complaint_service.dart';
import '../services/form_ocr_service.dart';
import '../services/repo_service.dart';
import '../widgets/form_scan_sheet.dart';

class NewComplaintScreen extends StatefulWidget {
  const NewComplaintScreen({super.key});

  @override
  State<NewComplaintScreen> createState() => _NewComplaintScreenState();
}

class _NewComplaintScreenState extends State<NewComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noRujCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _selectedFloor = '1';
  String _selectedIssue = 'lift';
  String _selectedWorkCategory = 'CORRECTIVE';
  String _selectedIssueCategory = 'ELECTRICAL';
  String _selectedPriority = 'NORMAL';
  String? _scannedReportedAt;
  String? _selectedAsset;
  bool _loading = false;
  bool _scanning = false;
  List<String> _floors = [];
  List<_AssetOption> _assetOptions = [];
  String? _evidenceBase64;

  static const _issueTypes = [
    'lift', 'chiller', 'ahu', 'pump', 'fcu', 'cooling_tower', 'tank',
    'panel', 'toilet', 'pantry', 'escalator', 'door', 'window', 'lighting',
    'plumbing', 'other',
  ];

  static const _workCategories = [
    'CORRECTIVE', 'PREVENTIVE', 'PREDICTIVE', 'EMERGENCY', 'ROUTINE',
  ];

  static const _issueCategories = [
    'ELECTRICAL', 'MECHANICAL', 'CIVIL', 'LANDSCAPE', 'ARCHITECTURAL',
  ];

  static const _priorities = [
    'URGENT', 'NORMAL', 'HIGH', 'MEDIUM', 'LOW', 'CRITICAL',
  ];

  @override
  void initState() {
    super.initState();
    _loadFloors();
    _prefillUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _noRujCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _prefillUser() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('complainer_name') ?? '';
    if (name.isNotEmpty && _nameCtrl.text.isEmpty) {
      _nameCtrl.text = name;
    }
  }

  Future<void> _loadFloors() async {
    try {
      await RepoService.refresh();
      final fcaItems = RepoService.fcaItems;
      final floors = fcaItems.map((f) => f.aras).toSet().toList();
      floors.sort((a, b) {
        final ia = int.tryParse(a), ib = int.tryParse(b);
        if (ia != null && ib != null) return ia.compareTo(ib);
        return a.compareTo(b);
      });
      if (mounted) setState(() => _floors = floors.isNotEmpty ? floors : List.generate(37, (i) => '${i + 1}'));
    } catch (_) {
      if (mounted) setState(() => _floors = List.generate(37, (i) => '${i + 1}'));
    }
    // also preload asset options for default floor
    await _loadAssetsForFloor(_selectedFloor);
  }

  Future<void> _loadAssetsForFloor(String floor) async {
    try {
      final data = await RepoService.readFile('me_assets.json');
      if (data is Map<String, dynamic>) {
        final floorKey = 'L$floor';
        final items = data[floorKey] as List?;
        if (items != null) {
          final options = <_AssetOption>[];
          for (final item in items) {
            final type = item['type'] as String;
            final qty = item['qty'] as int;
            if (qty <= 1) {
              options.add(_AssetOption(type, type));
            } else {
              for (int i = 1; i <= qty; i++) {
                options.add(_AssetOption('$type $i', '$type $i'));
              }
            }
          }
          if (mounted) setState(() => _assetOptions = options);
        }
      }
    } catch (_) {}
  }

  Future<void> _pickEvidence({bool scan = false}) async {
    if (!scan) {
      await _pickPlainEvidence();
      return;
    }
    await _scanForm();
  }

  Future<void> _pickPlainEvidence() async {
    final eng = LanguageProvider.isEnglish(context);
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(eng ? 'Add Evidence' : 'Tambah Bukti', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0D7377)),
              title: Text(eng ? 'Take Photo' : 'Ambil Gambar'),
              subtitle: Text(eng ? 'Use camera' : 'Guna kamera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0D7377)),
              title: Text(eng ? 'Choose from Gallery' : 'Pilih dari Galeri'),
              subtitle: Text(eng ? 'Browse photos' : 'Cari gambar'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;
    final file = await ImagePicker().pickImage(source: src, maxWidth: 1600, maxHeight: 1600, imageQuality: 90);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final b64 = base64Encode(bytes);
    if (mounted) setState(() => _evidenceBase64 = b64);
  }

  Future<void> _scanForm() async {
    final eng = LanguageProvider.isEnglish(context);
    setState(() => _scanning = true);
    try {
      final outcome = await pickAndScanForm(context, eng: eng);
      if (outcome == null || !mounted) return;
      setState(() => _evidenceBase64 = outcome.evidenceBase64);
      final result = outcome.result;
      if (result.filledCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(eng ? 'No form fields recognised. Try a clearer photo.' : 'Tiada medan borang dikenali. Cuba gambar yang lebih jelas.'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
        return;
      }
      final apply = await _showScanSummary(result, eng);
      if (apply != true) return;
      final issueType = FormOcrService.matchIssueType(
        '${result.description} ${result.asset}',
        ocrIssueType: result.issueType,
      );
      setState(() {
        if (result.complainerName.isNotEmpty) _nameCtrl.text = result.complainerName;
        if (result.phone.isNotEmpty) _phoneCtrl.text = result.phone;
        if (result.floor.isNotEmpty) _selectedFloor = result.floor;
        if (result.noRuj.isNotEmpty) _noRujCtrl.text = result.noRuj;
        if (result.dateTime.isNotEmpty) _scannedReportedAt = result.dateTime;
        if (_workCategories.contains(result.issueType)) _selectedWorkCategory = result.issueType;
        if (_issueCategories.contains(result.workCategory)) _selectedIssueCategory = result.workCategory;
        if (_priorities.contains(result.priority)) _selectedPriority = result.priority;
        _selectedIssue = issueType;
        if (result.description.isNotEmpty) _descCtrl.text = result.description;
        if (_floors.isNotEmpty && _floors.contains(result.floor)) {
          _selectedAsset = null;
          _assetOptions = [];
          _loadAssetsForFloor(result.floor);
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eng ? 'Form scanned. Review & submit.' : 'Borang diimbas. Semak & hantar.'),
          backgroundColor: const Color(0xFF0D7377),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eng ? 'Scan failed: $e' : 'Imbasan gagal: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<bool?> _showScanSummary(FormOcrResult r, bool eng) {
    final rows = <(String, String)>[
      (eng ? 'Nama Pengadu' : 'Nama Pengadu', r.complainerName),
      (eng ? 'No. Telefon' : 'No. Telefon', r.phone),
      (eng ? 'Tarikh & Masa' : 'Tarikh & Masa', r.dateTime),
      (eng ? 'Aras (Floor)' : 'Aras', r.floor),
      (eng ? 'Jenis Kerja' : 'Jenis Kerja', r.issueType),
      (eng ? 'Katagori Kerja' : 'Katagori Kerja', r.workCategory),
      (eng ? 'Keutamaan' : 'Keutamaan', r.priority),
      (eng ? 'No. Ruj' : 'No. Ruj', r.noRuj),
      (eng ? 'Aset' : 'Aset', r.asset),
      (eng ? 'Keterangan' : 'Keterangan', r.description),
    ].where((e) => e.$2.isNotEmpty).toList();
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Form Scanned' : 'Borang Diimbas'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                eng
                  ? '${rows.length} field(s) found. Apply to the form?'
                  : '${rows.length} medan ditemui. Guna dalam borang?',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              for (final (label, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                      Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(false);
              _showRawOcr(r, eng);
            },
            child: Text(eng ? 'Raw OCR' : 'OCR Mentah'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(eng ? 'Cancel' : 'Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(eng ? 'Apply' : 'Guna'),
          ),
        ],
      ),
    );
  }

  void _showRawOcr(FormOcrResult r, bool eng) {
    final text = r.rawLines.isEmpty
        ? (eng ? '(no text detected)' : '(tiada teks dikesan)')
        : r.rawLines.join('\n');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(eng ? 'Raw OCR Text' : 'Teks OCR Mentah'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(text, style: const TextStyle(fontSize: 12.5)),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(eng ? 'OK' : 'OK'),
          ),
        ],
      ),
    );
  }

  void _removeEvidence() {
    setState(() => _evidenceBase64 = null);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final eng = LanguageProvider.isEnglish(context);

    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('complainer_uid') ?? 'unknown';
    final name = prefs.getString('complainer_name') ?? 'Complainer';

    final ticket = ComplaintTicket(
      userId: uid,
      complainerName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : name,
      complainerPhone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
      reportedAt: _scannedReportedAt,
      floor: _selectedFloor,
      issueType: _selectedIssue,
      workCategory: _selectedWorkCategory,
      priority: _selectedPriority,
      noRuj: _noRujCtrl.text.trim().isNotEmpty ? _noRujCtrl.text.trim() : null,
      assetName: _selectedAsset,
      description: _descCtrl.text.trim(),
    );

    final ok = await ComplaintService.add(ticket, evidenceBase64: _evidenceBase64);
    setState(() => _loading = false);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Complaint submitted!'),
          backgroundColor: const Color(0xFF22C55E),
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(eng ? 'Failed to submit. Check network & try again.' : 'Gagal hantar. Periksa rangkaian & cuba lagi.'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  String _issueLabel(String key, bool eng) {
    switch (key) {
      case 'lift': return eng ? 'Lift' : 'Lif';
      case 'chiller': return 'Chiller';
      case 'ahu': return 'AHU';
      case 'pump': return eng ? 'Pump' : 'Pam';
      case 'fcu': return 'FCU';
      case 'cooling_tower': return eng ? 'Cooling Tower' : 'Menara Penyejuk';
      case 'tank': return eng ? 'Tank' : 'Tangki';
      case 'panel': return eng ? 'Panel' : 'Panel';
      case 'toilet': return eng ? 'Toilet' : 'Tandas';
      case 'pantry': return eng ? 'Pantry' : 'Pantry';
      case 'escalator': return 'Escalator';
      case 'door': return eng ? 'Door' : 'Pintu';
      case 'window': return eng ? 'Window' : 'Tingkap';
      case 'lighting': return eng ? 'Lighting' : 'Lampu';
      case 'plumbing': return eng ? 'Plumbing' : 'Paip';
      case 'other': return eng ? 'Other' : 'Lain-lain';
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(title: Text(eng ? 'New Complaint' : 'Aduan Baru')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(eng ? 'Report an issue in the building' : 'Laporkan masalah di bangunan',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 16),

            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _scanning ? null : () => _pickEvidence(scan: true),
                icon: _scanning
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.document_scanner_rounded),
                label: Text(eng ? 'Scan Complaint Form' : 'Imbas Borang Aduan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D7377),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: eng ? 'Nama Pengadu (Complainer)' : 'Nama Pengadu',
                prefixIcon: const Icon(Icons.person_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? (eng ? 'Enter your name' : 'Masukkan nama') : null,
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: eng ? 'No. Telefon' : 'No. Telefon',
                prefixIcon: const Icon(Icons.phone_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                final t = v?.trim() ?? '';
                if (t.isEmpty) return eng ? 'Enter phone number' : 'Masukkan no. telefon';
                if (!RegExp(r'^0\d{8,11}$').hasMatch(t.replaceAll(RegExp(r'[\s-]'), ''))) {
                  return eng ? 'Invalid phone number' : 'No. telefon tidak sah';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _selectedFloor,
              decoration: InputDecoration(
                labelText: eng ? 'Floor' : 'Aras',
                prefixIcon: const Icon(Icons.layers_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _floors.map((f) => DropdownMenuItem(value: f, child: Text('Aras $f'))).toList(),
              onChanged: (v) {
                setState(() {
                  _selectedFloor = v!;
                  _selectedAsset = null;
                  _assetOptions = [];
                });
                _loadAssetsForFloor(_selectedFloor);
              },
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _selectedIssue,
              decoration: InputDecoration(
                labelText: eng ? 'Issue Type' : 'Jenis Masalah',
                prefixIcon: const Icon(Icons.build_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _issueTypes.map((t) => DropdownMenuItem(value: t, child: Text(_issueLabel(t, eng)))).toList(),
              onChanged: (v) => setState(() => _selectedIssue = v!),
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _selectedWorkCategory,
              decoration: InputDecoration(
                labelText: eng ? 'Work Type (Jenis Kerja)' : 'Jenis Kerja',
                prefixIcon: const Icon(Icons.build_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _workCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedWorkCategory = v!),
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _selectedIssueCategory,
              decoration: InputDecoration(
                labelText: eng ? 'Category (Katagori Kerja)' : 'Katagori Kerja',
                prefixIcon: const Icon(Icons.category_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _issueCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedIssueCategory = v!),
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _selectedPriority,
              decoration: InputDecoration(
                labelText: eng ? 'Priority (Keutamaan)' : 'Keutamaan',
                prefixIcon: const Icon(Icons.priority_high_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _selectedPriority = v!),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _noRujCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: eng ? 'No. Ruj (optional)' : 'No. Ruj (pilihan)',
                hintText: eng ? 'e.g. JKRBG26002742 — auto if empty' : 'Cth: JKRBG26002742 — auto jika kosong',
                prefixIcon: const Icon(Icons.tag_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            if (_assetOptions.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: _selectedAsset,
                decoration: InputDecoration(
                  labelText: eng ? 'Specific Asset (optional)' : 'Aset Spesifik (pilihan)',
                  prefixIcon: const Icon(Icons.precision_manufacturing_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _assetOptions.map((a) => DropdownMenuItem(value: a.value, child: Text(a.label))).toList(),
                onChanged: (v) => setState(() => _selectedAsset = v),
              ),
              const SizedBox(height: 14),
            ],

            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: eng ? 'Description' : 'Penerangan',
                hintText: eng ? 'e.g. Lift not working on floor 34' : 'Cth: Lif tak berfungsi di aras 34',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v?.trim().length ?? 0) >= 5 ? null : (eng ? 'Minimum 5 characters' : 'Minimum 5 huruf'),
            ),
            const SizedBox(height: 16),

            Text(eng ? 'Evidence (optional)' : 'Bukti (pilihan)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
            const SizedBox(height: 8),

            if (_evidenceBase64 != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      base64Decode(_evidenceBase64!),
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: _removeEvidence,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _pickEvidence,
                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                label: Text(eng ? 'Take / Choose Photo' : 'Ambil / Pilih Gambar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D7377),
                  side: const BorderSide(color: Color(0xFF0D7377)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),

            const SizedBox(height: 20),

            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
                label: Text(eng ? 'Submit Complaint' : 'Hantar Aduan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D7377),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetOption {
  final String label;
  final String value;
  const _AssetOption(this.label, this.value);
}