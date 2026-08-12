import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/spare_part_data.dart';
import '../localization.dart';
import '../services/repo_service.dart';
import '../services/spare_part_service.dart';
import '../services/tool_service.dart';

class SparePartScreen extends StatefulWidget {
  final bool isAdmin;
  final bool embedded;
  final bool tools;
  const SparePartScreen({
    super.key,
    this.isAdmin = false,
    this.embedded = false,
    this.tools = false,
  });

  @override
  State<SparePartScreen> createState() => _SparePartScreenState();
}

/// Opens WhatsApp to [s] with a short intro + quotation request for [part].
/// Shared by the list and the editor screens. [kind] switches the wording
/// between 'spare part' and 'tool'.
Future<void> launchWhatsAppQuotation(
    BuildContext context, SparePart part, SparePartSupplier s,
    {String kind = 'part'}) async {
  final eng = LanguageProvider.isEnglish(context);
  var phone = s.whatsapp.trim().replaceAll(RegExp(r'[^\d+]'), '');
  if (phone.startsWith('+')) phone = phone.substring(1);
  if (phone.startsWith('0')) phone = '60${phone.substring(1)}';
  if (phone.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(eng
          ? 'No WhatsApp number for ${s.name}'
          : 'Tiada nombor WhatsApp untuk ${s.name}'),
    ));
    return;
  }
  final item = kind == 'tool' ? 'tool' : 'spare part';
  final msg = eng
      ? 'Hi ${s.name}, I would like to request a quotation for "$item: ${part.name}" (qty ${part.quantity}). Please send me your best price. Thank you!'
      : 'Assalamualaikum ${s.name}, saya ingin meminta quotation untuk "$item: ${part.name}" (qty ${part.quantity}). Boleh tolong berikan sebut harga terbaik? Terima kasih!';
  final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(msg)}');
  if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(eng
        ? 'Could not open WhatsApp — check the number'
        : 'Tidak dapat buka WhatsApp — semak nombor'),
  ));
}

class _SparePartScreenState extends State<SparePartScreen> {
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _supplierFilter = '';
  bool _lowStockOnly = false;
  String _sort = 'name';

  static const int _lowStockThreshold = 5;

  @override
  void initState() {
    super.initState();
    RepoService.ensureEnv();
    (widget.tools ? ToolService.revision : SparePartService.revision)
        .addListener(_onRevision);
    _load();
  }

  @override
  void dispose() {
    (widget.tools ? ToolService.revision : SparePartService.revision)
        .removeListener(_onRevision);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onRevision() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    if (widget.tools) {
      await ToolService.load();
    } else {
      await SparePartService.load();
    }
    if (mounted) setState(() => _loading = false);
  }

  List<SparePart> get _entries =>
      widget.tools ? ToolService.entries : SparePartService.entries;

  Future<void> _openEditor({SparePart? part}) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _SparePartEditor(
          part: part,
          isAdmin: widget.isAdmin,
          tools: widget.tools,
        ),
      ),
    );
    if (ok == true && mounted) await _load();
  }

  List<String> get _supplierNames {
    final names = <String>{};
    for (final p in _entries) {
      for (final s in p.suppliers) {
        if (s.name.trim().isNotEmpty) names.add(s.name.trim());
      }
    }
    return names.toList()..sort();
  }

  List<SparePart> get _filteredParts {
    final q = _search.trim().toLowerCase();
    final result = _entries.where((p) {
      if (q.isNotEmpty) {
        final inName = p.name.toLowerCase().contains(q);
        final inSupplier = p.suppliers
            .any((s) => s.name.toLowerCase().contains(q));
        if (!inName && !inSupplier) return false;
      }
      if (_supplierFilter.isNotEmpty &&
          !p.suppliers.any((s) => s.name.trim() == _supplierFilter)) {
        return false;
      }
      if (_lowStockOnly && p.quantity > _lowStockThreshold) return false;
      return true;
    }).toList();
    switch (_sort) {
      case 'name':
        result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case 'qtyAsc':
        result.sort((a, b) => a.quantity.compareTo(b.quantity));
      case 'qtyDesc':
        result.sort((a, b) => b.quantity.compareTo(a.quantity));
      default:
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final parts = _filteredParts;
    final all = _entries;
    final totalQty = all.fold<int>(0, (sum, p) => sum + p.quantity);
    final supplierNames = _supplierNames;
    final isFiltering =
        _search.trim().isNotEmpty || _supplierFilter.isNotEmpty || _lowStockOnly;
    final tools = widget.tools;
    final listTitle = tools
        ? (eng ? 'Tools' : 'Perkakas')
        : (eng ? 'Spare Parts' : 'Alat Ganti');
    final addLabel = eng ? 'Add' : 'Tambah';

    final listBody = _loading
        ? const Center(child: CircularProgressIndicator())
        : all.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tools
                          ? Icons.handyman_rounded
                          : Icons.build_circle_rounded,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tools
                          ? (eng
                              ? 'No tools yet — tap + to add one'
                              : 'Tiada perkakas lagi — tekan + untuk tambah')
                          : (eng
                              ? 'No spare parts yet — tap + to add one'
                              : 'Tiada alat ganti lagi — tekan + untuk tambah'),
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildSearchBar(eng, tools),
                  _buildFilterRow(eng, supplierNames),
                  Expanded(
                    child: parts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded,
                                    size: 42, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                Text(
                                  tools
                                      ? (eng
                                          ? 'No tools match your search'
                                          : 'Tiada perkakas sepadan carian')
                                      : (eng
                                          ? 'No spare parts match your search'
                                          : 'Tiada alat ganti sepadan carian'),
                                  style: TextStyle(
                                      color: Colors.grey.shade500),
                                ),
                                if (isFiltering)
                                  TextButton.icon(
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() {
                                        _search = '';
                                        _supplierFilter = '';
                                        _lowStockOnly = false;
                                      });
                                    },
                                    icon: const Icon(
                                        Icons.filter_alt_off_rounded,
                                        size: 16),
                                    label: Text(eng
                                        ? 'Clear filters'
                                        : 'Kosongkan tapisan'),
                                  ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 4, 12, 90),
                              itemCount: parts.length,
                              itemBuilder: (_, i) => _partCard(parts[i], eng),
                            ),
                          ),
                  ),
                ],
              );

    if (widget.embedded) {
      return Column(
        children: [
          Expanded(child: listBody),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(addLabel,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  onPressed: () => _openEditor(),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(listTitle),
        actions: [
          if (!_loading) ...[
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text('$totalQty',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
            ),
            _buildSortMenu(eng),
          ],
        ],
      ),
      body: listBody,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: Colors.green.shade600,
        icon: const Icon(Icons.add_rounded),
        label: Text(addLabel,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSearchBar(bool eng, bool tools) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: tools
              ? (eng ? 'Search tool or supplier…' : 'Cari perkakas atau pembekal…')
              : (eng
                  ? 'Search spare part or supplier…'
                  : 'Cari alat ganti atau pembekal…'),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                )
              : null,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
      ),
    );
  }

  Widget _buildFilterRow(bool eng, List<String> supplierNames) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          FilterChip(
            avatar: _lowStockOnly
                ? null
                : const Icon(Icons.inventory_rounded,
                    size: 15, color: Color(0xFFB45309)),
            label: Text(eng ? 'Low stock' : 'Stok rendah'),
            selected: _lowStockOnly,
            onSelected: (v) => setState(() => _lowStockOnly = v),
          ),
          for (final s in supplierNames)
            FilterChip(
              label: Text(s,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              selected: _supplierFilter == s,
              onSelected: (v) => setState(
                  () => _supplierFilter = v ? s : ''),
            ),
        ],
      ),
    );
  }

  Widget _buildSortMenu(bool eng) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.sort_rounded),
      tooltip: eng ? 'Sort' : 'Susun',
      onSelected: (v) => setState(() => _sort = v),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'name',
          child: Row(
            children: [
              const Icon(Icons.sort_by_alpha_rounded, size: 17),
              const SizedBox(width: 8),
              Text(_sort == 'name'
                  ? '✓ ${eng ? 'Name A–Z' : 'Nama A–Z'}'
                  : (eng ? 'Name A–Z' : 'Nama A–Z')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'qtyDesc',
          child: Row(
            children: [
              const Icon(Icons.numbers_rounded, size: 17),
              const SizedBox(width: 8),
              Text(_sort == 'qtyDesc'
                  ? '✓ ${eng ? 'Quantity (high→low)' : 'Kuantiti (tinggi→rendah)'}'
                  : (eng
                      ? 'Quantity (high→low)'
                      : 'Kuantiti (tinggi→rendah)')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'qtyAsc',
          child: Row(
            children: [
              const Icon(Icons.trending_up_rounded, size: 17),
              const SizedBox(width: 8),
              Text(_sort == 'qtyAsc'
                  ? '✓ ${eng ? 'Quantity (low→high)' : 'Kuantiti (rendah→tinggi)'}'
                  : (eng
                      ? 'Quantity (low→high)'
                      : 'Kuantiti (rendah→tinggi)')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _partCard(SparePart part, bool eng) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openEditor(part: part),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _photo(part),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(part.name,
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(eng ? 'Qty' : 'Kuantiti',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                        Text('${part.quantity}',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0D7377))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    tooltip: eng ? 'Edit / delete' : 'Edit / padam',
                    onPressed: () => _openEditor(part: part),
                  ),
                ],
              ),
              if (part.suppliers.isNotEmpty) ...[
                const Divider(height: 18),
                Text(eng ? 'Suppliers' : 'Pembekal',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: part.suppliers.map((s) {
                    final rec = s.recommended;
                    return ActionChip(
                      avatar: rec
                          ? const Icon(Icons.star_rounded,
                              size: 16, color: Color(0xFFF59E0B))
                          : const Icon(Icons.store_rounded,
                              size: 16, color: Color(0xFF0D7377)),
                      label: Text('${s.name}${rec ? ' ✓' : ''}',
                          style: const TextStyle(fontSize: 11.5)),
                      onPressed: () => launchWhatsAppQuotation(
                              context,
                              part,
                              s,
                              kind: widget.tools ? 'tool' : 'part',
                            ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _photo(SparePart part) {
    if (part.photoBase64.isEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF0D7377).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.hardware_rounded, color: Color(0xFF0D7377)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.memory(
        base64Decode(part.photoBase64),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _SparePartEditor extends StatefulWidget {
  final SparePart? part;
  final bool isAdmin;
  final bool tools;
  const _SparePartEditor({this.part, required this.isAdmin, this.tools = false});

  @override
  State<_SparePartEditor> createState() => _SparePartEditorState();
}

class _SparePartEditorState extends State<_SparePartEditor> {
  late final SparePart _part;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  bool _saving = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final p = widget.part;
    _part = p != null
        ? SparePart(
            id: p.id,
            name: p.name,
            quantity: p.quantity,
            photoBase64: p.photoBase64,
            updatedAt: p.updatedAt,
            suppliers: p.suppliers.map((s) => SparePartSupplier(
                id: s.id,
                name: s.name,
                whatsapp: s.whatsapp,
                location: s.location,
                recommended: s.recommended)).toList(),
          )
        : SparePart();
    _nameCtrl = TextEditingController(text: _part.name);
    _qtyCtrl = TextEditingController(text: '${_part.quantity}');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _part.photoBase64 = base64Encode(bytes));
  }

  Future<void> _save() async {
    final eng = LanguageProvider.isEnglish(context);
    final name = _nameCtrl.text.trim();
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (name.isEmpty || qty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(eng ? 'Name required, qty ≥ 0' : 'Nama wajib, kuantiti ≥ 0')));
      return;
    }
    _part.name = name;
    _part.quantity = qty;
    setState(() => _saving = true);
    // Blocking overlay so nothing can be tapped mid-save.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: const Center(
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ),
      ),
    );
    final ok = widget.tools
        ? await ToolService.save(_part)
        : await SparePartService.save(_part);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (eng ? 'Saved ✓' : 'Disimpan ✓')
          : (eng ? 'Save failed — retry' : 'Gagal simpan — cuba lagi')),
    ));
    if (ok) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final eng = LanguageProvider.isEnglish(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.tools
            ? (eng ? 'Delete tool?' : 'Padam perkakas?')
            : (eng ? 'Delete spare part?' : 'Padam alat ganti?')),
        content: Text(eng
            ? '"${_part.name}" will be removed permanently.'
            : '"${_part.name}" akan dipadam kekal.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(eng ? 'Cancel' : 'Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(eng ? 'Delete' : 'Padam'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() => _saving = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => PopScope(
        canPop: false,
        child: const Center(
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16))),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ),
      ),
    );
    final ok = widget.tools
        ? await ToolService.remove(_part.id)
        : await SparePartService.remove(_part.id);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (eng ? 'Deleted ✓' : 'Dipadam ✓')
          : (eng ? 'Delete failed — retry' : 'Gagal padam — cuba lagi')),
    ));
    if (ok) Navigator.of(context).pop(true);
  }

  Future<void> _openSupplierEditor({SparePartSupplier? supplier}) async {
    final result = await Navigator.of(context).push<SparePartSupplier?>(
      MaterialPageRoute(
        builder: (_) => _SupplierEditor(supplier: supplier),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final idx = _part.suppliers.indexWhere((s) => s.id == result.id);
      if (result.recommended) {
        for (final s in _part.suppliers) {
          s.recommended = false;
        }
      }
      if (idx >= 0) {
        _part.suppliers[idx] = result;
      } else {
        _part.suppliers.add(result);
      }
    });
  }

  Future<void> _removeSupplier(SparePartSupplier s) async {
    setState(() => _part.suppliers.remove(s));
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final tools = widget.tools;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.part == null
            ? (tools
                ? (eng ? 'Add Tool' : 'Tambah Perkakas')
                : (eng ? 'Add Spare Part' : 'Tambah Alat Ganti'))
            : (tools
                ? (eng ? 'Edit Tool' : 'Edit Perkakas')
                : (eng ? 'Edit Spare Part' : 'Edit Alat Ganti'))),
        actions: [
          if (widget.part != null)
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              tooltip: eng ? 'Delete' : 'Padam',
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.isAdmin) ...[
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D7377).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          image: _part.photoBase64.isNotEmpty
                              ? DecorationImage(
                                  image: MemoryImage(
                                      base64Decode(_part.photoBase64)),
                                  fit: BoxFit.cover)
                              : null,
                        ),
                        child: _part.photoBase64.isEmpty
                            ? const Icon(Icons.add_a_photo_rounded,
                                size: 32, color: Color(0xFF0D7377))
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  eng ? 'Tap to add photo' : 'Tekan untuk tambah foto',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: tools
                    ? 'Tool name / Nama perkakas'
                    : 'Spare part name / Nama alat ganti',
                prefixIcon: Icon(tools ? Icons.handyman_rounded : Icons.build_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity / Kuantiti',
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
            ),
            if (widget.isAdmin) ...[
              const SizedBox(height: 22),
              Row(
                children: [
                  const Icon(Icons.store_rounded,
                      size: 18, color: Color(0xFF0D7377)),
                  const SizedBox(width: 6),
                  Text(eng ? 'Suppliers' : 'Pembekal',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _saving ? null : () => _openSupplierEditor(),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: Text(eng ? 'Add' : 'Tambah'),
                  ),
                ],
              ),
              if (_part.suppliers.isEmpty)
                Text(eng
                    ? 'No supplier yet — add one to request quotations via WhatsApp.'
                    : 'Tiada pembekal — tambah untuk minta quotation melalui WhatsApp.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ..._part.suppliers
                  .map((s) => Card(
                        margin: const EdgeInsets.only(top: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: _supplierAvatar(s),
                          title: Row(
                            children: [
                              Flexible(
                                  child: Text(s.name.isEmpty
                                      ? '(no name)'
                                      : s.name)),
                              if (s.recommended) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.star_rounded,
                                    size: 16, color: Color(0xFFF59E0B)),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            '${s.location.isNotEmpty ? s.location : ''}'
                            '${s.location.isNotEmpty && s.whatsapp.isNotEmpty ? ' · ' : ''}'
                            '${s.whatsapp.isNotEmpty ? s.whatsapp : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chat_rounded,
                                    size: 20, color: Color(0xFF25D366)),
                                tooltip: eng
                                    ? 'WhatsApp quotation'
                                    : 'WhatsApp quotation',
                                onPressed:
                                    () => launchWhatsAppQuotation(
                                        context,
                                        _part,
                                        s,
                                        kind: widget.tools ? 'tool' : 'part'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 20),
                                onPressed: _saving
                                    ? null
                                    : () => _openSupplierEditor(supplier: s),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded,
                                    size: 20, color: Colors.red),
                                onPressed: _saving
                                    ? null
                                    : () => _removeSupplier(s),
                              ),
                            ],
                          ),
                        ),
                      )),
            ],
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: Text(eng ? 'Save' : 'Simpan',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _supplierAvatar(SparePartSupplier s) {
    return CircleAvatar(
      backgroundColor: const Color(0xFF0D7377).withValues(alpha: 0.15),
      child: Text(
        s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
        style: const TextStyle(color: Color(0xFF0D7377)),
      ),
    );
  }
}

class _SupplierEditor extends StatefulWidget {
  final SparePartSupplier? supplier;
  const _SupplierEditor({this.supplier});

  @override
  State<_SupplierEditor> createState() => _SupplierEditorState();
}

class _SupplierEditorState extends State<_SupplierEditor> {
  late final SparePartSupplier _s;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _waCtrl;
  late final TextEditingController _locCtrl;

  @override
  void initState() {
    super.initState();
    _s = widget.supplier != null
        ? SparePartSupplier(
            id: widget.supplier!.id,
            name: widget.supplier!.name,
            whatsapp: widget.supplier!.whatsapp,
            location: widget.supplier!.location,
            recommended: widget.supplier!.recommended)
        : SparePartSupplier();
    _nameCtrl = TextEditingController(text: _s.name);
    _waCtrl = TextEditingController(text: _s.whatsapp);
    _locCtrl = TextEditingController(text: _s.location);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _waCtrl.dispose();
    _locCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.supplier == null
            ? (eng ? 'Add Supplier' : 'Tambah Pembekal')
            : (eng ? 'Edit Supplier' : 'Edit Pembekal')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: eng ? 'Supplier name' : 'Nama pembekal',
              hintText: eng ? 'e.g. Aircon Spares Sdn Bhd' : 'cth. Aircon Spares Sdn Bhd',
              prefixIcon: const Icon(Icons.store_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _waCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: eng ? 'WhatsApp number' : 'Nombor WhatsApp',
              hintText: eng ? 'e.g. 012 345 6789' : 'cth. 012 345 6789',
              prefixIcon: const Icon(Icons.chat_rounded,
                  color: Color(0xFF25D366)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locCtrl,
            decoration: InputDecoration(
              labelText: eng ? 'Location' : 'Lokasi',
              hintText: eng ? 'e.g. Klang, Selangor' : 'cth. Klang, Selangor',
              prefixIcon: const Icon(Icons.location_on_rounded),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _s.recommended,
            onChanged: (v) => setState(() => _s.recommended = v ?? false),
            title: const Text('Recommended / Disyorkan'),
            subtitle: Text(eng
                ? 'Use this supplier by default for quotations'
                : 'Gunakan pembekal ini secara lalai untuk quotation'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              _s.name = _nameCtrl.text.trim();
              _s.whatsapp = _waCtrl.text.trim();
              _s.location = _locCtrl.text.trim();
              if (_s.name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(eng
                      ? 'Supplier name is required'
                      : 'Nama pembekal diperlukan'),
                ));
                return;
              }
              Navigator.of(context).pop(_s);
            },
            icon: const Icon(Icons.check_rounded),
            label: Text(eng ? 'Save Supplier' : 'Simpan Pembekal',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0D7377),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}