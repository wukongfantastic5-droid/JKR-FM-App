import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization.dart';
import '../services/po_service.dart';
import '../services/quotation_pdf.dart';

/// Purchase Order (Mechanical) workspace: pick a supplier quotation PDF,
/// read its vendor/items/totals, then generate the branded PO workbook
/// (template `assets/po_mechanical_template.xlsx`) into Downloads.
class PoScreen extends StatefulWidget {
  const PoScreen({super.key});

  @override
  State<PoScreen> createState() => _PoScreenState();
}

class _PoScreenState extends State<PoScreen> {
  static const _accent = Color(0xFF0D7377);

  Quotation? _q;
  DateTime _date = DateTime.now();
  final _poCtrl = TextEditingController(text: 'CMSB/2026/PO-0054');
  final _termCtrl = TextEditingController();
  final _attnCtrl = TextEditingController(text: 'ZAINALABIDIN BIN CHE HASSAN');
  final _catCtrl = TextEditingController(text: 'MECHANICAL');
  final List<_PoRow> _rows = [];
  bool _busy = false;

  @override
  void dispose() {
    _poCtrl.dispose();
    _termCtrl.dispose();
    _attnCtrl.dispose();
    _catCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickQuotation() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (res == null || res.files.isEmpty) {
      return;
    }
    final f = res.files.first;
    var bytes = f.bytes;
    if (bytes == null && f.path != null) {
      try {
        bytes = await File(f.path!).readAsBytes();
      } catch (_) {}
    }
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        _snack(LanguageProvider.isEnglish(context)
            ? 'Could not read the selected file'
            : 'Tidak dapat membaca fail yang dipilih');
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final cells = QuotationPdf.extractCells(bytes);
      if (cells.isEmpty) {
        if (!mounted) return;
        setState(() => _busy = false);
        _snack(LanguageProvider.isEnglish(context)
            ? 'This PDF has no readable text (scanned image). Please pick a text quotation or fill the PO manually.'
            : 'PDF ini tiada teks boleh dibaca (imej imbas). Sila pilih sebut harga berteks atau isi PO secara manual.');
        return;
      }
      final q = QuotationPdf.parse(cells);
      if (!mounted) return;
      if (q.items.isEmpty) {
        setState(() => _busy = false);
        _snack(LanguageProvider.isEnglish(context)
            ? 'No item table found in this quotation'
            : 'Jadual item tidak dijumpai dalam sebut harga ini');
        return;
      }
      setState(() {
        _q = q;
        _rows
          ..clear()
          ..addAll([for (final i in q.items) _PoRow(i)]);
        _termCtrl.text = q.terms;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack('Reading quotation failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _sheetName(String po) {
    final p = po.trim();
    final last = p.split(RegExp(r'[/\\\s-]+')).last;
    return 'PO-$last';
  }

  String _fileSafe(String s) =>
      s.replaceAll(RegExp(r'[<>:"/\\|?*]'), '-');

  Future<Directory?> _saveDir() async {
    try {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'];
      if (home == null || home.isEmpty) return null;
      var downloads = Directory('$home\\Downloads');
      if (!downloads.existsSync()) downloads = Directory('$home/Downloads');
      final dir =
          Directory('${downloads.path}\\FM_Report\\Purchase_Order');
      dir.createSync(recursive: true);
      return dir;
    } catch (_) {
      return null;
    }
  }

  Future<void> _generate() async {
    final eng = LanguageProvider.isEnglish(context);
    final po = _poCtrl.text.trim();
    if (po.isEmpty) {
      _snack(eng ? 'Enter the PO number' : 'Masukkan nombor PO');
      return;
    }
    if (_rows.isEmpty) {
      _snack(eng ? 'No items to print' : 'Tiada item untuk dicetak');
      return;
    }
    setState(() => _busy = true);
    try {
      final input = PoInput(
        sheetName: _sheetName(po),
        poNumber: po,
        term: _termCtrl.text.trim(),
        attnCakra: _attnCtrl.text.trim(),
        date: _date,
        items: [
          for (final r in _rows) PoItem(r.desc, r.qty, r.price),
        ],
        vendorLines: _q?.vendor ?? [],
        vendorTel: _q == null ? '' : PoInput.vendorTelFrom(_q!.vendor),
        vendorAttn: _q?.attn ?? '',
      );
      final bytes = await PoService.buildFromAsset(input);
      final cat = _catCtrl.text.trim();
      final name = 'PO ${_fileSafe(po)}${cat.isEmpty ? '' : ' ($cat)'}.xlsx';
      final dir = await _saveDir();
      final dirPath = dir?.path;
      if (dirPath != null) {
        File('$dirPath\\$name').writeAsBytesSync(bytes);
      }
      if (!mounted) return;
      setState(() => _busy = false);
      if (dirPath != null) {
        _snack('${eng ? 'Saved' : 'Disimpan'}: $dirPath\\$name');
        try {
          await launchUrl(Uri.file('$dirPath\\$name'),
              mode: LaunchMode.platformDefault);
        } catch (_) {}
      } else {
        _snack(eng
            ? 'Generated but could not save (desktop only)'
            : 'Dijana tetapi tidak dapat disimpan (desktop sahaja)');
      }
    } catch (e) {
      debugPrint('[PO] generation error: $e');
      if (mounted) setState(() => _busy = false);
      if (mounted) {
        _snack('${eng ? 'Generation failed' : 'Penjanaan gagal'}: $e');
      }
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.year}';

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (p != null) setState(() => _date = p);
  }

  double get _total => _rows.fold(0, (a, r) => a + r.total);

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(title: Text(eng ? 'Purchase Order' : 'Pesanan Belian')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
            children: [
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eng ? '1. Quotation PDF' : '1. Sebut Harga (PDF)',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _accent),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: _accent),
                        icon: const Icon(Icons.picture_as_pdf_rounded,
                            size: 18),
                        label: Text(
                          _q == null
                              ? (eng
                                  ? 'Pick Supplier Quotation PDF'
                                  : 'Pilih PDF Sebut Harga Pembekal')
                              : (eng
                                  ? 'Replace Quotation'
                                  : 'Ganti Sebut Harga'),
                          style:
                              const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        onPressed: _busy ? null : _pickQuotation,
                      ),
                    ),
                    if (_q != null) ...[
                      const SizedBox(height: 10),
                      Text(_q!.vendor.join('\n'),
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.4)),
                      const SizedBox(height: 6),
                      Text(
                        '${eng ? 'To' : 'Kepada'}: ${_q!.toCompany}  •  '
                        '${eng ? 'Date' : 'Tarikh'}: ${_q!.dateText}  •  '
                        '${eng ? 'Terms' : 'Terma'}: ${_q!.terms}  •  '
                        'Attn: ${_q!.attn}',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade700,
                            height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
              if (_q != null) ...[
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eng ? '2. PO Details' : '2. Butiran PO',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _accent),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _poCtrl,
                        decoration: const InputDecoration(
                          labelText: 'PO Number / No. PO',
                          prefixIcon: Icon(Icons.tag_rounded, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8))),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _termCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Terms / Terma',
                                prefixIcon:
                                    Icon(Icons.schedule_rounded, size: 20),
                                isDense: true,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                        Radius.circular(8))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _catCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Category / Kategori',
                                prefixIcon: Icon(Icons.category_rounded,
                                    size: 20),
                                isDense: true,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                        Radius.circular(8))),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_month_rounded,
                            color: _accent),
                        title: Text(_fmtDate(_date)),
                        subtitle: Text(eng ? 'Date' : 'Tarikh'),
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _attnCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Attn (CAKRA)',
                          prefixIcon: Icon(Icons.person_rounded, size: 20),
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            eng ? '3. Items (from quotation)'
                                : '3. Item (dari sebut harga)',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _accent),
                          ),
                          const Spacer(),
                          Text(
                            'RM ${_total.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < _rows.length; i++)
                        _itemRow(_rows[i], i, eng),
                      const SizedBox(height: 8),
                      Text(
                        eng
                            ? 'Tap a value to edit quantity or unit price.'
                            : 'Tekan nilai untuk ubah kuantiti atau harga unit.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (_q != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: Icon(_busy
                    ? Icons.hourglass_top_rounded
                    : Icons.description_rounded),
                label: Text(
                  _busy
                      ? (eng ? 'Generating…' : 'Menjana…')
                      : (eng ? 'Generate PO Workbook' : 'Jana Buku Kerja PO'),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800),
                ),
                onPressed: _busy ? null : _generate,
              ),
            ),
          if (_busy)
            Positioned.fill(
              child: Container(
                color: const Color(0x99051E24),
                child: const Center(
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: CircularProgressIndicator(
                        strokeWidth: 4, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }

  void _edit(_PoRow r, bool isQty, bool eng) {
    final ctrl = TextEditingController(
        text: isQty ? '${r.qty}' : r.price.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isQty
            ? (eng ? 'Edit Quantity' : 'Ubah Kuantiti')
            : (eng ? 'Edit Unit Price' : 'Ubah Harga Unit')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: r.desc,
            suffixText: isQty ? '' : 'RM',
            border:
                const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(eng ? 'Cancel' : 'Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(eng ? 'Save' : 'Simpan',
                style: const TextStyle(color: _accent)),
          ),
        ],
      ),
    ).then((ok) {
      if (ok != true || !mounted) return;
      setState(() {
        if (isQty) {
          r.qty = int.tryParse(ctrl.text.trim()) ?? r.qty;
        } else {
          r.price = double.tryParse(ctrl.text.trim()) ?? r.price;
        }
      });
      ctrl.dispose();
    });
  }

  Widget _itemRow(_PoRow r, int i, bool eng) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: i.isEven ? Colors.grey.withValues(alpha: 0.06) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('${r.no}',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade700)),
          ),
          Expanded(
            child: Text(r.desc,
                style: const TextStyle(fontSize: 12.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _edit(r, true, eng),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${r.qty}',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _edit(r, false, eng),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(r.price.toStringAsFixed(2),
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
          SizedBox(
            width: 84,
            child: Text(
              r.total.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _PoRow {
  final int no;
  final String desc;
  int qty;
  double price;
  _PoRow(QuotationItem i)
      : no = i.no,
        desc = i.description,
        qty = i.qty,
        price = i.unitPrice;

  double get total => qty * price;
}