import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;

import '../localization.dart';
import '../services/repair_docx.dart';
import '../widgets/http_error_banner.dart';
import '../services/repo_service.dart';
import '../services/doc_deliver.dart';
import '../services/spare_part_service.dart';
import '../services/tool_service.dart';
import '../services/status_usage_service.dart';
import '../services/excel_service.dart';
import 'spare_part_screen.dart';

/// Admin "Parts & Tools" screen: two tabs (Spare Part / Tools) with the same
/// add-edit-delete + supplier design. Both are real-time (shared revision
/// notifier, saved to the GitHub database). A Download action produces two
/// Word files — one for parts, one for tools — inside a
/// "Parts and Tools\Parts" and "Parts and Tools\Tools" folder structure.
class PartsToolsScreen extends StatefulWidget {
  const PartsToolsScreen({super.key});

  @override
  State<PartsToolsScreen> createState() => _PartsToolsScreenState();
}

class _PartsToolsScreenState extends State<PartsToolsScreen> {
  bool _downloading = false;
  bool _xlsBusy = false;
  bool _usageBusy = false;
  int _lowParts = 0;
  int _lowTools = 0;

  static const int lowThreshold = 5;

  @override
  void initState() {
    super.initState();
    SparePartService.revision.addListener(_refreshCounts);
    ToolService.revision.addListener(_refreshCounts);
    _refreshCounts();
  }

  @override
  void dispose() {
    SparePartService.revision.removeListener(_refreshCounts);
    ToolService.revision.removeListener(_refreshCounts);
    super.dispose();
  }

  void _refreshCounts() {
    if (!mounted) return;
    setState(() {
      _lowParts =
          SparePartService.entries.where((p) => p.quantity <= lowThreshold).length;
      _lowTools =
          ToolService.entries.where((t) => t.quantity <= lowThreshold).length;
    });
  }

  Widget _tabIcon(IconData icon, int low) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 20),
        if (low > 0)
          Positioned(
            right: -10,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text('$low',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }

  Future<void> _downloadExcel() async {
    final eng = LanguageProvider.isEnglish(context);
    setState(() => _xlsBusy = true);
    try {
      await SparePartService.load();
      await ToolService.load();
      final parts = List.from(SparePartService.entries)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final tools = List.from(ToolService.entries)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final now = DateTime.now();
      final fileDate = '${now.year}${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';
      final bytes = await ExcelService.build([
        ExcelSheet(
          name: 'Spare Parts',
          headers: const ['No', 'Spare Part', 'Quantity', 'Updated'],
          rows: [
            for (var i = 0; i < parts.length; i++)
              ['${i + 1}', parts[i].name, '${parts[i].quantity}', parts[i].updatedAt],
          ],
        ),
        ExcelSheet(
          name: 'Tools',
          headers: const ['No', 'Tools', 'Quantity', 'Updated'],
          rows: [
            for (var i = 0; i < tools.length; i++)
              ['${i + 1}', tools[i].name, '${tools[i].quantity}', tools[i].updatedAt],
          ],
        ),
      ]);
      final fileName = 'Stock_$fileDate.xlsx';
      final local = await DocDeliver.saveLocal('Parts and Tools', fileName, bytes);
      final ok = await RepoService.writeRawFile(
          'Reports/Parts_Tools/$fileName', base64Encode(bytes));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? (local.isNotEmpty
                ? (eng ? 'Saved: $local' : 'Disimpan: $local')
                : (eng
                    ? 'Saved in database (Reports/Parts_Tools)'
                    : 'Disimpan dalam database (Reports/Parts_Tools)'))
            : (eng ? 'Export ok but save failed' : 'Eksport berjaya tetapi simpan gagal')),
      ));
      if (ok) {
        await DocDeliver.offerOpen(
          context,
          repoPath: 'Reports/Parts_Tools/$fileName',
          eng: eng,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng ? 'Export failed: $e' : 'Eksport gagal: $e'),
        backgroundColor: const Color(0xFFEF4444),
      ));
    } finally {
      if (mounted) setState(() => _xlsBusy = false);
    }
  }

  Future<void> _download() async {
    final eng = LanguageProvider.isEnglish(context);
    setState(() => _downloading = true);
    try {
      await SparePartService.load();
      await ToolService.load();
      final parts = List.from(SparePartService.entries)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final tools = List.from(ToolService.entries)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-${now.year}';
      final ref = 'STK-${now.day.toString().padLeft(2, '0')}'
          '${now.month.toString().padLeft(2, '0')}${now.year.toString().substring(2)}';

      final partsDocx = await RepairDocxService.build(
        title: 'SENARAI STOK ALAT GANTI',
        titleEn: 'SPARE PARTS STOCK LIST',
        refNo: ref,
        dateStr: dateStr,
        paragraphs: const ['JADUAL 1: SENARAI ALAT GANTI / TABLE 1: SPARE PARTS'],
        tableHeader: ['No', 'Spare Part', 'Quantity', 'Image'],
        colWidthsCm: const [1.3, 6.6, 1.8, 8.5],
        tableRows: [
          for (var i = 0; i < parts.length; i++)
            [('${i + 1}'), parts[i].name, '${parts[i].quantity}'],
        ],
        tableImages: [
          for (final p in parts)
            p.photoBase64.isNotEmpty ? base64Decode(p.photoBase64) : null,
        ],
      );
      final toolsDocx = await RepairDocxService.build(
        title: 'SENARAI STOK PERKAKAS',
        titleEn: 'TOOLS STOCK LIST',
        refNo: ref,
        dateStr: dateStr,
        paragraphs: const ['JADUAL 2: SENARAI PERKAKAS / TABLE 2: TOOLS'],
        tableHeader: ['No', 'Tools', 'Quantity', 'Image'],
        colWidthsCm: const [1.3, 6.6, 1.8, 8.5],
        tableRows: [
          for (var i = 0; i < tools.length; i++)
            [('${i + 1}'), tools[i].name, '${tools[i].quantity}'],
        ],
        tableImages: [
          for (final t in tools)
            t.photoBase64.isNotEmpty ? base64Decode(t.photoBase64) : null,
        ],
      );

      var savedLocal = false;
      String localPath = '';
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          try {
            var downloads = Directory('$home\\Downloads');
            if (!downloads.existsSync()) downloads = Directory('$home/Downloads');
            final root = Directory('${downloads.path}\\FM_Report\\Parts and Tools');
            final partsDir = Directory('${root.path}\\Parts');
            final toolsDir = Directory('${root.path}\\Tools');
            partsDir.createSync(recursive: true);
            toolsDir.createSync(recursive: true);
            File('${partsDir.path}\\Spare_Parts_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.docx')
                .writeAsBytesSync(partsDocx);
            File('${toolsDir.path}\\Tools_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.docx')
                .writeAsBytesSync(toolsDocx);
            savedLocal = true;
            localPath = root.path;
          } catch (e) {
            debugPrint('[PartsTools] local save: $e');
          }
        }
      }

      final partsPath = await RepoService.writeRawFile(
        'Reports/Parts_Tools/Parts/Spare_Parts_$dateStr.docx',
        base64Encode(partsDocx));
      final toolsPath = await RepoService.writeRawFile(
        'Reports/Parts_Tools/Tools/Tools_$dateStr.docx',
        base64Encode(toolsDocx));
      final savedRepo = partsPath && toolsPath;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(savedRepo
              ? (savedLocal
                  ? (eng
                      ? 'Saved: $localPath\n(Parts + Tools folders)'
                      : 'Disimpan: $localPath\n(folder Parts + Tools)')
                  : (eng
                      ? 'Saved in database (Reports/Parts_Tools)'
                      : 'Disimpan dalam database (Reports/Parts_Tools)'))
              : (eng ? 'Generate ok but save failed' : 'Jana berjaya tetapi simpan gagal')),
        ));
        if (savedRepo) {
          await DocDeliver.offerOpen(
            context,
            repoPath: 'Reports/Parts_Tools/Parts/Spare_Parts_$dateStr.docx',
            eng: eng,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(eng ? 'Download failed: $e' : 'Muat turun gagal: $e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  /// Downloads two Word files — parts usage + tools usage — from
  /// status_usage.json, into a "Status Usage\Parts" / "Status Usage\Tools"
  /// folder/subfolder structure (same pattern as the stock Word download),
  /// and mirrors them into Reports/Status_Usage/ in the database.
  Future<void> _downloadStatusUsage() async {
    if (_usageBusy) return;
    setState(() => _usageBusy = true);
    final eng = LanguageProvider.isEnglish(context);
    try {
      await StatusUsageService.load();
      await SparePartService.load();
      await ToolService.load();
      final now = DateTime.now();
      final dateStr = '${now.year}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';

      final parts = StatusUsageService.ofType('part');
      final tools = StatusUsageService.ofType('tool');

      List<List<String>> rows(List<dynamic> recs) => [
            for (var i = 0; i < recs.length; i++)
              [
                '${i + 1}',
                '${recs[i].itemName}',
                '${recs[i].qtyUsed}',
                '${recs[i].techName}',
                '${recs[i].date}',
                '${recs[i].remark}',
              ],
          ];

      final partsDocx = await RepairDocxService.build(
        title: 'STATUS PENGGUNAAN ALAT GANTI',
        titleEn: 'SPARE PARTS USAGE STATUS',
        refNo: 'JKR/FM/USG/P',
        dateStr: '${now.year}-${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}',
        tableHeader: const ['No', 'Item', 'Qty Used', 'Used By', 'Date', 'Remark'],
        tableRows: rows(parts),
      );
      final toolsDocx = await RepairDocxService.build(
        title: 'STATUS PENGGUNAAN PERKAKAS',
        titleEn: 'TOOLS USAGE STATUS',
        refNo: 'JKR/FM/USG/T',
        dateStr: '${now.year}-${now.month.toString().padLeft(2, '0')}-'
            '${now.day.toString().padLeft(2, '0')}',
        tableHeader: const ['No', 'Item', 'Qty Used', 'Used By', 'Date', 'Remark'],
        tableRows: rows(tools),
      );

      var savedLocal = false;
      String localPath = '';
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.windows ||
              defaultTargetPlatform == TargetPlatform.linux ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        final home = Platform.environment['USERPROFILE'] ??
            Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          try {
            var downloads = Directory('$home\\Downloads');
            if (!downloads.existsSync()) downloads = Directory('$home/Downloads');
            final root =
                Directory('${downloads.path}\\FM_Report\\Status Usage');
            final partsDir = Directory('${root.path}\\Parts');
            final toolsDir = Directory('${root.path}\\Tools');
            partsDir.createSync(recursive: true);
            toolsDir.createSync(recursive: true);
            File('${partsDir.path}\\Status_Usage_$dateStr.docx')
                .writeAsBytesSync(partsDocx);
            File('${toolsDir.path}\\Status_Usage_$dateStr.docx')
                .writeAsBytesSync(toolsDocx);
            savedLocal = true;
            localPath = root.path;
          } catch (e) {
            debugPrint('[PartsTools] usage local save: $e');
          }
        }
      }
      final okRepoP = await RepoService.writeRawFile(
        'Reports/Status_Usage/Parts/Status_Usage_$dateStr.docx',
        base64Encode(partsDocx));
      final okRepoT = await RepoService.writeRawFile(
        'Reports/Status_Usage/Tools/Status_Usage_$dateStr.docx',
        base64Encode(toolsDocx));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(savedLocal
            ? (eng
                ? 'Saved: $localPath\n(Parts + Tools folders)'
                : 'Disimpan: $localPath\n(folder Parts + Tools)')
            : (eng ? 'Saved to database' : 'Disimpan ke pangkalan data')),
      ));
      if (!savedLocal && okRepoP && okRepoT) {
        await DocDeliver.offerOpen(
          context,
          repoPath:
              'Reports/Status_Usage/Parts/Status_Usage_$dateStr.docx',
          eng: eng,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(eng ? 'Download failed: $e' : 'Muat turun gagal: $e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _usageBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(eng ? 'Parts & Tools' : 'Alat Ganti & Perkakas'),
          actions: [
            IconButton(
              icon: _usageBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.receipt_long_rounded),
              tooltip: eng ? 'Download status usage (Word)' : 'Muat turun status kegunaan (Word)',
              onPressed: _usageBusy ? null : _downloadStatusUsage,
            ),
            IconButton(
              icon: _xlsBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.table_chart_rounded),
              tooltip: eng ? 'Export stock to Excel' : 'Eksport stok ke Excel',
              onPressed: _xlsBusy ? null : _downloadExcel,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded),
                tooltip: eng ? 'Download stock list (Word)' : 'Muat turun senarai stok (Word)',
                onPressed: _downloading ? null : _download,
              ),
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                icon: _tabIcon(Icons.build_rounded, _lowParts),
                text: eng ? 'Spare Part' : 'Alat Ganti',
              ),
              Tab(
                icon: _tabIcon(Icons.handyman_rounded, _lowTools),
                text: eng ? 'Tools' : 'Perkakas',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            const HttpErrorBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  SparePartScreen(isAdmin: true, embedded: true),
                  SparePartScreen(isAdmin: true, embedded: true, tools: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}