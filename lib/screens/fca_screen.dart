import 'package:flutter/material.dart';
import '../localization.dart';
import '../services/repo_service.dart';
import '../services/auth_service.dart';
import '../services/performance.dart';
import '../data/fca_data.dart';
import '../widgets/fade_route.dart';

class FcaScreen extends StatefulWidget {
  const FcaScreen({super.key});

  @override
  State<FcaScreen> createState() => _FcaScreenState();
}

class _FcaScreenState extends State<FcaScreen> with SingleTickerProviderStateMixin {
  List<FcaItem> _allItems = [];
  List<FcaItem> _filtered = [];
  final Map<String, List<Map<String, dynamic>>> _assetCache = {};
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  final _searchDebouncer = Debouncer(delay: const Duration(milliseconds: 200));
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  String? _floorFilter;
  String? _statusFilter;
  String? _priorityFilter;
  bool _jkrOnly = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _loadData();
  }

  @override
  void dispose() {
    _searchDebouncer.cancel();
    _searchCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final raw = await RepoService.readFile('fca.json');
    var assetRaw = await RepoService.readFile('me_assets_deep.json');
    assetRaw ??= await RepoService.readFile('me_assets_grouped.json');
    if (mounted) {
      setState(() {
        if (raw is List) {
          _allItems = raw.map((f) => FcaItem.fromJson(f as Map<String, dynamic>)).toList();
        }
        if (assetRaw is Map) {
          _assetCache.clear();
          for (final entry in assetRaw.entries) {
            if (entry.value is List) {
              _assetCache[entry.key] = (entry.value as List).cast<Map<String, dynamic>>();
            }
          }
        }
        _applyFilters();
        _loading = false;
      });
      _animCtrl.forward(from: 0);
    }
  }

  void _applyFilters() {
    var items = List<FcaItem>.from(_allItems);
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isNotEmpty) {
      items = items.where((i) =>
        i.kerosakan.toLowerCase().contains(q) ||
        i.ruang.toLowerCase().contains(q) ||
        i.aras.toLowerCase().contains(q) ||
        i.bil.toString().contains(q)
      ).toList();
    }
    if (_floorFilter != null) items = items.where((i) => i.aras == _floorFilter).toList();
    if (_statusFilter != null) items = items.where((i) => i.status == _statusFilter).toList();
    if (_priorityFilter != null) items = items.where((i) => i.priority == _priorityFilter).toList();
    if (_jkrOnly) items = items.where((i) => i.jkrRequest.isNotEmpty).toList();
    setState(() => _filtered = items);
  }

  int get _openCount => _allItems.where((i) => i.status == 'open').length;
  int get _progressCount => _allItems.where((i) => i.status == 'in_progress').length;
  int get _closedCount => _allItems.where((i) => i.status == 'closed').length;

  Color _statusColor(String s) => switch (s) {
    'open' => const Color(0xFFEF4444),
    'in_progress' => const Color(0xFFF59E0B),
    'closed' => const Color(0xFF22C55E),
    _ => Colors.grey,
  };

  Color _priorityColor(String p) => switch (p) {
    'high' => const Color(0xFFDC2626),
    'medium' => const Color(0xFFF59E0B),
    'low' => const Color(0xFF3B82F6),
    _ => Colors.grey,
  };

  Future<void> _showImageFullscreen(String imageFile) async {
    if (imageFile.isEmpty) return;
    final url = 'https://raw.githubusercontent.com/wukongfantastic5-droid/Database-JKR/main/fca_images/$imageFile';
    Navigator.of(context).push(FadeRoute(page: Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: Text(imageFile, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 6.0,
        child: Center(
          child: Image.network(url, fit: BoxFit.contain,
            loadingBuilder: (ctx, child, p) {
              if (p == null) return child;
              return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
            },
            errorBuilder: (ctx, e, s) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
          ),
        ),
      ),
    )));
  }

  Future<void> _showEditDialog(FcaItem item) async {
    final eng = LanguageProvider.isEnglish(context);
    final statusCtrl = TextEditingController(text: item.status);
    final priorityCtrl = TextEditingController(text: item.priority);
    final ruangCtrl = TextEditingController(text: item.ruang);
    final jkrCtrl = TextEditingController(text: item.jkrRequest);
    final solutionCtrl = TextEditingController(text: item.solution);
    final byMainCat = _getAssetsByMainCat(item);
    final presentCats = List<String>.from(_mainCatOrder);

    String? selectedInstance = item.instanceName.isEmpty ? null : item.instanceName;
    String? selectedAssetType;
    String? selectedMainCat;
    if (selectedInstance != null) {
      for (final mc in byMainCat.entries) {
        for (final at in mc.value.entries) {
          if (at.value.contains(selectedInstance)) {
            selectedMainCat = mc.key;
            selectedAssetType = at.key;
            break;
          }
        }
        if (selectedMainCat != null) break;
      }
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) {
          return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D7377).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: Color(0xFF0D7377), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(children: [
                        Text('${eng ? 'Item' : 'Item'} #${item.bil}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        if (item.displayAssetType.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D7377).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(item.displayAssetType, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF0D7377))),
                          ),
                        ],
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.kerosakan, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                TextField(
                  controller: ruangCtrl,
                  decoration: _inputDec(eng ? 'Room / Ruang' : 'Room / Ruang', Icons.location_on_rounded),
                ),
                const SizedBox(height: 12),
                // Status
                DropdownButtonFormField<String>(
                  initialValue: statusCtrl.text,
                  decoration: _inputDec(eng ? 'Status' : 'Status', Icons.flag_rounded),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('🟢 Open')),
                    DropdownMenuItem(value: 'in_progress', child: Text('🟡 In Progress')),
                    DropdownMenuItem(value: 'closed', child: Text('🔴 Closed')),
                  ],
                  onChanged: (v) => statusCtrl.text = v ?? 'open',
                ),
                const SizedBox(height: 12),
                // Priority
                DropdownButtonFormField<String>(
                  initialValue: priorityCtrl.text,
                  decoration: _inputDec(eng ? 'Priority' : 'Keutamaan', Icons.priority_high_rounded),
                  items: const [
                    DropdownMenuItem(value: 'high', child: Text('🔴 High')),
                    DropdownMenuItem(value: 'medium', child: Text('🟡 Medium')),
                    DropdownMenuItem(value: 'low', child: Text('🔵 Low')),
                  ],
                  onChanged: (v) => priorityCtrl.text = v ?? 'medium',
                ),
                const SizedBox(height: 12),
                // 3-level selector: Main Category → Asset Type → Specific Asset
                if (presentCats.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey('mainCat_$selectedMainCat'),
                    initialValue: selectedMainCat,
                    isExpanded: true,
                    decoration: _inputDec(
                      eng ? 'Main Category' : 'Kategori Utama',
                      Icons.dashboard_rounded,
                    ),
                    items: [
                      DropdownMenuItem(value: null, child: Text(eng ? '(Select category)' : '(Pilih kategori)', style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
                      ...presentCats.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))),
                    ],
                    onChanged: (v) {
                      setDState(() {
                        selectedMainCat = v;
                        selectedAssetType = null;
                        selectedInstance = null;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  // Asset type dropdown
                  if (selectedMainCat != null && (byMainCat[selectedMainCat]?.keys.toList() ?? []).isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey('type_$selectedAssetType'),
                      initialValue: selectedAssetType,
                      isExpanded: true,
                      decoration: _inputDec(
                        eng ? 'Asset Type' : 'Jenis Aset',
                        Icons.category_rounded,
                      ),
                      items: [
                        DropdownMenuItem(value: null, child: Text(eng ? '(Select type)' : '(Pilih jenis)', style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
                        ...(byMainCat[selectedMainCat]?.keys.toList() ?? []).map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) {
                        setDState(() {
                          selectedAssetType = v;
                          selectedInstance = null;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    // Specific asset dropdown
                    if (selectedAssetType != null) ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey(selectedInstance),
                        initialValue: selectedInstance,
                        isExpanded: true,
                        decoration: _inputDec(
                          eng ? 'Specific Asset' : 'Aset Spesifik',
                          Icons.precision_manufacturing_rounded,
                        ),
                        selectedItemBuilder: (ctx) => [
                          Container(alignment: Alignment.centerLeft, child: Text(eng ? '(Not specified)' : '(Tidak ditetapkan)', style: TextStyle(color: Colors.grey.shade500, fontSize: 13), overflow: TextOverflow.ellipsis)),
                          ...(byMainCat[selectedMainCat]?[selectedAssetType] ?? []).map((inst) => Container(
                            alignment: Alignment.centerLeft,
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width - 80),
                            child: Text(inst, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                          )),
                        ],
                        items: [
                          DropdownMenuItem(value: null, child: Text(eng ? '(Not specified)' : '(Tidak ditetapkan)', style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
                          ...(byMainCat[selectedMainCat]?[selectedAssetType] ?? [])
                            .map((inst) => DropdownMenuItem(
                            value: inst,
                            child: Container(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(ctx).size.width - 80),
                              child: Text(inst, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            ),
                          )),
                        ],
                        onChanged: (v) {
                          setDState(() => selectedInstance = v);
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                ],
                // JKR
                TextField(
                  controller: jkrCtrl,
                  decoration: _inputDec(eng ? 'JKR Request Ref' : 'Rujukan JKR', Icons.description_rounded),
                ),
                const SizedBox(height: 12),
                // Solution
                TextField(
                  controller: solutionCtrl,
                  maxLines: 3,
                  decoration: _inputDec(eng ? 'Solution / Notes' : 'Penyelesaian / Catatan', Icons.lightbulb_outline_rounded),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(eng ? 'Cancel' : 'Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop({
                          'status': statusCtrl.text,
                          'priority': priorityCtrl.text,
                          'ruang': ruangCtrl.text,
                          'jkrRequest': jkrCtrl.text,
                          'solution': solutionCtrl.text,
                          'instanceName': selectedInstance ?? '',
                          'assetType': selectedAssetType ?? '',
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D7377),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(eng ? 'Save Changes' : 'Simpan', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
        },
      ),
    );

    if (result != null) {
      item.status = result['status'] ?? item.status;
      item.priority = result['priority'] ?? item.priority;
      item.jkrRequest = result['jkrRequest'] ?? item.jkrRequest;
      item.solution = result['solution'] ?? item.solution;
      if (result.containsKey('instanceName')) {
        item.instanceName = result['instanceName'] ?? '';
      }
      if (result.containsKey('assetType')) {
        item.assetType = result['assetType'] ?? '';
      }
      if (result.containsKey('ruang')) {
        item.ruang = result['ruang'] ?? item.ruang;
      }
      final ok = await RepoService.updateFcaItem(item);
      if (ok && item.status == 'closed' && item.solution.isNotEmpty) {
        final uid = AuthService.currentUser?.uid ?? 'ai';
        await RepoService.saveSolution(item.kerosakan, item.solution, uid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(ok ? 'Item updated!' : 'Failed to save'),
            ],
          ),
          backgroundColor: ok ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      _loadData();
    }
  }

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    isDense: true,
  );

  Future<void> _markAsSolved(FcaItem item) async {
    final eng = LanguageProvider.isEnglish(context);
    final solutionCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(eng ? 'Mark as Solved' : 'Tanda Selesai',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Item #${item.bil}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(height: 2),
                    Text(item.kerosakan, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: solutionCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: eng ? 'Solution / How it was fixed' : 'Penyelesaian / Cara baiki',
                  hintText: eng ? 'e.g. Replaced DDC controller...' : 'cth: Ganti controller DDC...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(eng ? 'Cancel' : 'Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(solutionCtrl.text.trim()),
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: Text(eng ? 'Save to Solutions' : 'Simpan ke Solutions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7377),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      final uid = AuthService.currentUser?.uid ?? 'ai';
      await RepoService.saveSolution(item.kerosakan, result, uid);
      await RepoService.saveFcaSolution(item, result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Solved! Solution saved to repository.'),
            ],
          ),
          backgroundColor: const Color(0xFF22C55E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
      _loadData();
    }
  }

  void _showFilterSheet() {
    final eng = LanguageProvider.isEnglish(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(eng ? 'Filters' : 'Tapis', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              Text('Floor / Aras', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: [
                  _filterChip('All', _floorFilter == null, () => setSheetState(() => _floorFilter = null)),
                  ..._floors.map((f) => _filterChip(f, _floorFilter == f, () => setSheetState(() => _floorFilter = f))),
                ],
              ),
              const SizedBox(height: 16),
              Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: [
                  _filterChip('All', _statusFilter == null, () => setSheetState(() => _statusFilter = null)),
                  _filterChip('🟢 Open', _statusFilter == 'open', () => setSheetState(() => _statusFilter = 'open')),
                  _filterChip('🟡 In Progress', _statusFilter == 'in_progress', () => setSheetState(() => _statusFilter = 'in_progress')),
                  _filterChip('🔴 Closed', _statusFilter == 'closed', () => setSheetState(() => _statusFilter = 'closed')),
                ],
              ),
              const SizedBox(height: 16),
              Text('Priority', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: [
                  _filterChip('All', _priorityFilter == null, () => setSheetState(() => _priorityFilter = null)),
                  _filterChip('🔴 High', _priorityFilter == 'high', () => setSheetState(() => _priorityFilter = 'high')),
                  _filterChip('🟡 Medium', _priorityFilter == 'medium', () => setSheetState(() => _priorityFilter = 'medium')),
                  _filterChip('🔵 Low', _priorityFilter == 'low', () => setSheetState(() => _priorityFilter = 'low')),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('JKR Request Only', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                  const Spacer(),
                  Switch(
                    value: _jkrOnly,
                    activeTrackColor: const Color(0xFF0D7377).withValues(alpha: 0.3),
                    activeThumbColor: const Color(0xFF0D7377),
                    onChanged: (v) => setSheetState(() => _jkrOnly = v),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheetState(() {
                          _floorFilter = null;
                          _statusFilter = null;
                          _priorityFilter = null;
                          _jkrOnly = false;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(eng ? 'Clear All' : 'Kosongkan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _applyFilters();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D7377),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(eng ? 'Apply' : 'Guna', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0D7377) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0xFF0D7377) : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Set<String> get _floors => _allItems.map((i) => i.aras).where((a) => a.isNotEmpty).toSet();

  // 9 main category mapping (same as engineering_demo_screen)
  static const Map<String, String> _assetToMainCat = {
    'AHU': 'ACMV', 'FCU': 'ACMV', 'VRF': 'ACMV', 'VAV': 'ACMV',
    'VSD': 'ACMV', 'PAC': 'ACMV', 'ACSU': 'ACMV', 'CHWP': 'ACMV',
    'HEAT EXCHANGER': 'ACMV', 'HEAT RECOVERY WHEEL': 'ACMV',
    'COOLING TOWER': 'ACMV', 'AIR COOLED CHILLER': 'ACMV',
    'CHILLER': 'ACMV', 'CHILLER PUMP': 'ACMV', 'WATER CHILLER': 'ACMV',
    'WATER COOLED CHILLER': 'ACMV',
    'AIR CURTAIN': 'ACMV', 'FAN': 'ACMV', 'AIR FILTER': 'ACMV',
    'EL': 'ACMV', 'REFRIGERANT LEAK DETECTOR': 'ACMV',
    'FIRE FIGHTING': 'FIRE FIGHTING', 'FM 200': 'FIRE FIGHTING',
    'VESDA': 'FIRE FIGHTING', 'SPRINKLER PUMP': 'FIRE FIGHTING',
    'SPRINKLER CONTROL PANEL': 'FIRE FIGHTING',
    'HOSE REEL PUMP': 'FIRE FIGHTING',
    'HOSE REEL PUMP CONTROL PANEL': 'FIRE FIGHTING',
    'HYDRANT PILLAR': 'FIRE FIGHTING',
    'WET RISER PUMP': 'FIRE FIGHTING',
    'WET RISER CONTROL PANEL': 'FIRE FIGHTING',
    'WET CHEMICAL SYSTEM': 'FIRE FIGHTING',
    'LIFT': 'LIFT', 'LIFT HIGHZONE': 'LIFT', 'LIFT LOWZONE': 'LIFT',
    'GONDOLA': 'GONDOLA',
    'WATER PUMP': 'Cold Water Supply',
    'COLD WATER PUMP': 'Cold Water Supply',
    'DOMESTIC COLD WATER BOOSTER PUMP': 'Cold Water Supply',
    'WATER TANK': 'Cold Water Supply',
    'WATER FILTER': 'Cold Water Supply',
    'WATER TREATMENT': 'Cold Water Supply',
    'KITCHEN EXHAUST HOOD': 'Kitchen Equipment',
    'ROLLER SHUTTER': 'OTHER MECHANICAL',
    'BLIND SPOT MIRROR': 'OTHER MECHANICAL',
    'TANDAS': 'OTHER MECHANICAL',
    'PANIC BUTTON': 'OTHER MECHANICAL',
    'INSTANT WATER HEATER': 'OTHER MECHANICAL',
    'AUDIO VISUAL': 'OTHER MECHANICAL',
    'VISUAL PROJECTION': 'OTHER MECHANICAL',
    'SMATV': 'OTHER MECHANICAL', 'PABX': 'OTHER MECHANICAL',
    'BOOM GATE': 'OTHER MECHANICAL', 'EXIT SIGN': 'OTHER MECHANICAL',
    'LIGHTING': 'OTHER MECHANICAL',
    'GRID CONNECTED PHOTOVOLTAIC(PV)': 'OTHER MECHANICAL',
    'SOLAR INVERTER': 'OTHER MECHANICAL',
    'METERING (VOLT & AMPS)': 'OTHER MECHANICAL',
    'CAP BANK': 'OTHER MECHANICAL',
    'DB': 'OTHER MECHANICAL', 'MSB': 'OTHER MECHANICAL',
    'SSB': 'OTHER MECHANICAL', 'RMU': 'OTHER MECHANICAL',
    'TX': 'OTHER MECHANICAL', 'UPS': 'OTHER MECHANICAL',
    'ACB': 'OTHER MECHANICAL', 'S/S/O': 'OTHER MECHANICAL',
    'LV ROOM': 'OTHER MECHANICAL',
    'SWITCH ROOM HV': 'OTHER MECHANICAL',
    'SYSTEM': 'OTHER MECHANICAL',
  };

  static const List<String> _mainCatOrder = [
    'ACMV', 'FIRE FIGHTING', 'LIFT', 'GONDOLA',
    'Cold Water Supply', 'Inspection Above Ceiling',
    'Kitchen Equipment', 'IRRIGATION SYSTEM', 'OTHER MECHANICAL',
  ];

  /// Building-view band label → JSON floor key in me_assets_deep.json:
  /// B1→LB1, B2→LB2, P→LP1 (parking podium), M→LM, G→LG, 36→L36, …
  static String _dataFloorKey(String floor) {
    switch (floor.toUpperCase()) {
      case 'B1': return 'LB1';
      case 'B2': return 'LB2';
      case 'P': return 'LP1';
      case 'M': return 'LM';
      case 'G': return 'LG';
      default:
        return floor.startsWith('L') ? floor : 'L$floor';
    }
  }

  /// System name ("1.0 ACMV") → main category label ("ACMV").
  static String _systemToMainCat(String sys) {
    final m = RegExp(r'^(\d+)\.').firstMatch(sys);
    final n = m != null ? int.parse(m.group(1)!) : 9;
    switch (n) {
      case 1: return 'ACMV';
      case 2: return 'FIRE FIGHTING';
      case 3: return 'LIFT';
      case 4: return 'GONDOLA';
      case 5: return 'Cold Water Supply';
      case 6: return 'Inspection Above Ceiling';
      case 7: return 'Kitchen Equipment';
      case 8: return 'IRRIGATION SYSTEM';
      default: return 'OTHER MECHANICAL';
    }
  }

  /// Returns mainCat → { assetType → [specific assets...] } for the item's
  /// floor, built from the deep structure {system, type, code, qty}.
  /// Falls back to the legacy grouped format when the floor has no deep data.
  Map<String, Map<String, List<String>>> _getAssetsByMainCat(FcaItem item) {
    final floorKey = _dataFloorKey(item.aras);
    final assets = _assetCache[floorKey];
    if (assets == null || assets.isEmpty) return {};
    final result = <String, Map<String, List<String>>>{};

    final isDeep = assets.first.containsKey('system');
    if (isDeep) {
      // Group by (system, type); specific assets = unit codes, or "TYPE n"
      // when a row carries no code.
      final byCatType = <String, Map<String, List<String>>>{};
      for (final a in assets) {
        final sys = a['system'] as String? ?? '9.0 Other Mechanical Equipment System';
        final type = a['type'] as String? ?? 'OTHER';
        final code = a['code'] as String?;
        final qty = (a['qty'] as num?)?.toInt() ?? 1;
        final mc = _systemToMainCat(sys);
        final typeMap = byCatType.putIfAbsent(mc, () => {});
        final list = typeMap.putIfAbsent(type, () => []);
        if (code != null && code.isNotEmpty) {
          list.add(code);
        } else if (qty > 1) {
          for (int i = 1; i <= qty; i++) list.add('$type $i');
        } else {
          list.add(type);
        }
      }
      // Deduplicate + sort within each type group.
      byCatType.forEach((mc, typeMap) {
        final out = <String, List<String>>{};
        typeMap.forEach((type, list) {
          out[type] = list.toSet().toList()..sort();
        });
        result[mc] = out;
      });
      return result;
    }

    // Legacy grouped format {type, qty, items[]}.
    for (final a in assets) {
      final type = a['type'] as String? ?? '';
      final mc = _assetToMainCat[type] ?? 'OTHER MECHANICAL';
      final items = a['items'] as List?;
      final list = <String>[];
      if (items != null) {
        list.addAll(items.cast<String>());
      } else {
        final qty = a['qty'] as int? ?? 1;
        for (int i = 1; i <= qty; i++) list.add('$type $i');
      }
      result.putIfAbsent(mc, () => {}).putIfAbsent(type, () => list);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : const Color(0xFFF8FAFB),
      appBar: AppBar(
        title: Text(eng ? 'FCA Mechanical' : 'FCA Mekanikal', style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterSheet,
            tooltip: eng ? 'Filters' : 'Tapis',
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Stats header
                  SliverToBoxAdapter(
                    child: _buildStatsHeader(eng, isDark),
                  ),
                  // Search
                  SliverToBoxAdapter(
                    child: _buildSearchBar(eng),
                  ),
                  // Active filter badges
                  if (_floorFilter != null || _statusFilter != null || _priorityFilter != null || _jkrOnly)
                    SliverToBoxAdapter(
                      child: _buildActiveFilters(eng),
                    ),
                  // Results count
                  SliverToBoxAdapter(
                    child: _buildResultCount(eng),
                  ),
                  // Empty state
                  if (_filtered.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(eng),
                    )
                  else
                    // Items list
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => FadeTransition(
                            opacity: _fadeAnim,
                            child: _buildItemCard(_filtered[i], isDark),
                          ),
                          childCount: _filtered.length,
                        ),
                      ),
                    ),
                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsHeader(bool eng, bool isDark) {
    final total = _allItems.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D7377), Color(0xFF0A5C5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0D7377).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(eng ? 'Total Items' : 'Jumlah Item',
                style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
              Text('$total', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statChip('Open', _openCount, const Color(0xFFF87171), Icons.error_outline_rounded),
              const SizedBox(width: 8),
              _statChip('Progress', _progressCount, const Color(0xFFFBBF24), Icons.sync_problem_rounded),
              const SizedBox(width: 8),
              _statChip('Closed', _closedCount, const Color(0xFF4ADE80), Icons.check_circle_outline_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text('$count', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool eng) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: eng ? 'Search damage, room, floor...' : 'Cari kerosakan, ruang, aras...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF0D7377)),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () { _searchCtrl.clear(); _applyFilters(); })
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (_) => _searchDebouncer.call(_applyFilters),
        ),
      ),
    );
  }

  Widget _buildActiveFilters(bool eng) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 6, runSpacing: 4,
        children: [
          if (_floorFilter != null)
            _activeBadge('${eng ? 'Floor' : 'Aras'}: $_floorFilter', () { setState(() => _floorFilter = null); _applyFilters(); }),
          if (_statusFilter != null)
            _activeBadge('Status: ${_statusFilter!.replaceAll('_', ' ')}', () { setState(() => _statusFilter = null); _applyFilters(); }),
          if (_priorityFilter != null)
            _activeBadge('Priority: $_priorityFilter', () { setState(() => _priorityFilter = null); _applyFilters(); }),
          if (_jkrOnly)
            _activeBadge('JKR Only', () { setState(() => _jkrOnly = false); _applyFilters(); }),
        ],
      ),
    );
  }

  Widget _activeBadge(String text, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0D7377).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0D7377).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF0D7377))),
          const SizedBox(width: 4),
          GestureDetector(onTap: onRemove, child: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF0D7377))),
        ],
      ),
    );
  }

  Widget _buildResultCount(bool eng) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Text(
            '${_filtered.length} ${_filtered.length == 1 ? (eng ? 'item' : 'item') : (eng ? 'items' : 'item')}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('${_allItems.length} total', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool eng) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(eng ? 'No matching items' : 'Tiada item sepadan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
            const SizedBox(height: 4),
            Text(eng ? 'Try different search or filters' : 'Cuba carian atau tapis lain',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(FcaItem item, bool isDark) {
    final eng = LanguageProvider.isEnglish(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showEditDialog(item),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top color bar
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: _statusColor(item.status),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: GestureDetector(
                          onTap: () => _showImageFullscreen(item.imageFile),
                          child: SizedBox(
                            width: 80,
                            height: 60,
                            child: item.imageFile.isNotEmpty
                                ? Image.network(item.imageUrl, fit: BoxFit.cover,
                                    loadingBuilder: (ctx, child, p) {
                                      if (p == null) return child;
                                      return Container(
                                        color: Colors.grey.shade100,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 16, height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D7377)),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (ctx, e, s) => Container(
                                      color: Colors.grey.shade100,
                                      child: const Icon(Icons.broken_image_rounded, size: 24, color: Colors.grey),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey.shade100,
                                    child: const Icon(Icons.image_not_supported_rounded, size: 20, color: Colors.grey),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badge row
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              children: [
                                _badge(item.statusLabel, _statusColor(item.status), Colors.white),
                                _badge(item.priorityLabel, _priorityColor(item.priority).withValues(alpha: 0.12), _priorityColor(item.priority)),
                                if (item.displayAssetType.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0D7377).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(item.displayAssetType, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: const Color(0xFF0D7377))),
                                  ),
                                Text('#${item.bil}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade400)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Description
                            Text(item.kerosakan,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            // Location
                            Row(
                              children: [
                                Icon(Icons.location_on_rounded, size: 13, color: Colors.grey.shade400),
                                const SizedBox(width: 3),
                                Text(item.aras, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
                                Text(' · ', style: TextStyle(color: Colors.grey.shade300)),
                                Flexible(child: Text(item.ruang, style: TextStyle(fontSize: 12, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            if (item.jkrRequest.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.description_rounded, size: 12, color: Colors.blue.shade400),
                                  const SizedBox(width: 3),
                                  Flexible(child: Text('JKR: ${item.jkrRequest}', style: TextStyle(fontSize: 11, color: Colors.blue.shade500), overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ],
                            if (item.solution.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF22C55E)),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(item.solution,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF22C55E)),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Action column
                      if (item.status != 'closed')
                        Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
                                onPressed: () => _markAsSolved(item),
                                color: const Color(0xFF22C55E),
                                visualDensity: VisualDensity.compact,
                                tooltip: eng ? 'Mark solved' : 'Tanda selesai',
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: textColor == Colors.white ? 1.0 : 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: textColor == Colors.white ? Colors.white : bg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
