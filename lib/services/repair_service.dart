import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'repo_service.dart';

/// Single budget line inside the Suggestion & Budget Request document.
class BudgetItem {
  String item;
  int qty;
  double unitPrice;
  BudgetItem({this.item = '', this.qty = 1, this.unitPrice = 0});
  Map<String, dynamic> toJson() => {'item': item, 'qty': qty, 'unitPrice': unitPrice};
  factory BudgetItem.fromJson(Map<String, dynamic> j) => BudgetItem(
        item: j['item'] as String? ?? '',
        qty: j['qty'] as int? ?? 1,
        unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
      );
}

enum RepairStatus {
  draft('draft'),
  submitted('submitted'),
  approved('approved'),
  rejected('rejected'),
  permit('permit'),
  executing('executing'),
  completed('completed');

  final String id;
  const RepairStatus(this.id);
  static RepairStatus fromId(String? id) =>
      RepairStatus.values.firstWhere((s) => s.id == id, orElse: () => RepairStatus.draft);
}

/// One repair workflow case: incident -> PPM report -> suggestion & budget ->
/// submit -> approval -> work permit -> execute -> work result report.
class RepairCase {
  String id; // RG-<ddmmyy>-<seq>
  String createdAt;
  String building;
  String system;
  String problemType;
  String description;
  String priority;
  String source;
  String reportedBy;
  String position;
  bool incidentComplete;
  String contractorName;
  String contractorSystem;
  String contractorPmDate;
  String contractorPmResult;
  bool ppmComplete;
  String suggestion; // our suggestion + contractor suggestion
  List<BudgetItem> budget;
  bool budgetComplete;
  RepairStatus status;
  String submittedAt;
  String decidedAt;
  String permitRequestedAt;
  String executedAt;
  String completedAt;
  List<String> resultNotes;
  List<String> resultPhotos; // base64 images for final work result report
  bool resultComplete;

  RepairCase({
    required this.id,
    required this.createdAt,
    this.building = '',
    this.system = '',
    this.problemType = '',
    this.description = '',
    this.priority = 'Normal',
    this.source = 'JKR',
    this.reportedBy = '',
    this.position = '',
    this.incidentComplete = false,
    this.contractorName = '',
    this.contractorSystem = '',
    this.contractorPmDate = '',
    this.contractorPmResult = '',
    this.ppmComplete = false,
    this.suggestion = '',
    List<BudgetItem>? budget,
    this.budgetComplete = false,
    this.status = RepairStatus.draft,
    this.submittedAt = '',
    this.decidedAt = '',
    this.permitRequestedAt = '',
    this.executedAt = '',
    this.completedAt = '',
    List<String>? resultNotes,
    List<String>? resultPhotos,
    this.resultComplete = false,
  })  : budget = budget ?? [],
        resultNotes = resultNotes ?? [],
        resultPhotos = resultPhotos ?? [];

  double get budgetTotal =>
      budget.fold(0.0, (acc, b) => acc + (b.qty * b.unitPrice));
  double get contingency => budgetTotal == 0 ? 0 : (budgetTotal * 0.10).roundToDouble();
  double get grandTotal => budgetTotal + contingency;
  bool get canSubmit => incidentComplete && ppmComplete && budgetComplete;

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt,
        'building': building,
        'system': system,
        'problemType': problemType,
        'description': description,
        'priority': priority,
        'source': source,
        'reportedBy': reportedBy,
        'position': position,
        'incidentComplete': incidentComplete,
        'contractorName': contractorName,
        'contractorSystem': contractorSystem,
        'contractorPmDate': contractorPmDate,
        'contractorPmResult': contractorPmResult,
        'ppmComplete': ppmComplete,
        'suggestion': suggestion,
        'budget': budget.map((b) => b.toJson()).toList(),
        'budgetComplete': budgetComplete,
        'status': status.id,
        'submittedAt': submittedAt,
        'decidedAt': decidedAt,
        'permitRequestedAt': permitRequestedAt,
        'executedAt': executedAt,
        'completedAt': completedAt,
        'resultNotes': resultNotes,
        'resultPhotos': resultPhotos,
        'resultComplete': resultComplete,
      };

  factory RepairCase.fromJson(Map<String, dynamic> j) => RepairCase(
        id: j['id'] as String? ?? '',
        createdAt: j['createdAt'] as String? ?? '',
        building: j['building'] as String? ?? '',
        system: j['system'] as String? ?? '',
        problemType: j['problemType'] as String? ?? '',
        description: j['description'] as String? ?? '',
        priority: j['priority'] as String? ?? 'Normal',
        source: j['source'] as String? ?? 'JKR',
        reportedBy: j['reportedBy'] as String? ?? '',
        position: j['position'] as String? ?? '',
        incidentComplete: j['incidentComplete'] as bool? ?? false,
        contractorName: j['contractorName'] as String? ?? '',
        contractorSystem: j['contractorSystem'] as String? ?? '',
        contractorPmDate: j['contractorPmDate'] as String? ?? '',
        contractorPmResult: j['contractorPmResult'] as String? ?? '',
        ppmComplete: j['ppmComplete'] as bool? ?? false,
        suggestion: j['suggestion'] as String? ?? '',
        budget: ((j['budget'] as List?) ?? [])
            .cast<Map<String, dynamic>>()
            .map(BudgetItem.fromJson)
            .toList(),
        budgetComplete: j['budgetComplete'] as bool? ?? false,
        status: RepairStatus.fromId(j['status'] as String?),
        submittedAt: j['submittedAt'] as String? ?? '',
        decidedAt: j['decidedAt'] as String? ?? '',
        permitRequestedAt: j['permitRequestedAt'] as String? ?? '',
        executedAt: j['executedAt'] as String? ?? '',
        completedAt: j['completedAt'] as String? ?? '',
        resultNotes: ((j['resultNotes'] as List?) ?? []).cast<String>().toList(),
        resultPhotos: ((j['resultPhotos'] as List?) ?? [])
            .map((e) => e is String ? e : (e.toString()))
            .toList(),
        resultComplete: j['resultComplete'] as bool? ?? false,
      );

  RepairCase copy() => RepairCase(
        id: id,
        createdAt: createdAt,
        building: building,
        system: system,
        problemType: problemType,
        description: description,
        priority: priority,
        source: source,
        reportedBy: reportedBy,
        position: position,
        incidentComplete: incidentComplete,
        contractorName: contractorName,
        contractorSystem: contractorSystem,
        contractorPmDate: contractorPmDate,
        contractorPmResult: contractorPmResult,
        ppmComplete: ppmComplete,
        suggestion: suggestion,
        budget: budget.map((b) => BudgetItem(item: b.item, qty: b.qty, unitPrice: b.unitPrice)).toList(),
        budgetComplete: budgetComplete,
        status: status,
        submittedAt: submittedAt,
        decidedAt: decidedAt,
        permitRequestedAt: permitRequestedAt,
        executedAt: executedAt,
        completedAt: completedAt,
        resultNotes: List.from(resultNotes),
        resultPhotos: List.from(resultPhotos),
        resultComplete: resultComplete,
      );
}

/// Persistence for repair-guide cases + uploaded template sheets.
/// Data -> `Repair_Guide/data.json`, generated docs under
/// `Repair_Guide/Docs/<id>/<id>-<kind>.docx`, template sheets under
/// `Templates/RepairGuide/` in the GitHub repo.
class RepairService {
  static const String dataPath = 'Repair_Guide/data.json';
  static const String docsRoot = 'Repair_Guide/Docs';
  static const String templateRoot = 'Templates/RepairGuide';
  static List<RepairCase> _cases = [];
  static List<String> _templates = [];

  static List<RepairCase> get cases => _cases;
  static List<String> get templates => _templates;

  static Future<void> load() async {
    try {
      final raw = await RepoService.readFile(dataPath);
      if (raw is List) {
        _cases = raw.cast<Map<String, dynamic>>().map(RepairCase.fromJson).toList();
        _cases.sort((a, b) => b.id.compareTo(a.id));
      }
    } catch (e) {
      debugPrint('[RepairService] load error: $e');
    }
    await loadTemplates();
  }

  static Future<bool> persist() async {
    final ok = await RepoService.writeFile(dataPath, _cases.map((c) => c.toJson()).toList());
    if (ok) _cases.sort((a, b) => b.id.compareTo(a.id));
    return ok;
  }

  static String docPath(String caseId, String kind) =>
      '$docsRoot/$caseId/$caseId-$kind.docx';

  static Future<String> nextId() async {
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.year.toString().substring(2)}';
    final prefix = 'RG-$date';
    var seq = 1;
    while (_cases.any((c) => c.id == '$prefix-$seq')) {
      seq++;
    }
    return '$prefix-$seq';
  }

  static String todayStr() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-${n.year}';
  }

  /// Saves a generated docx into the repo; returns its path ('' on failure).
  static Future<String?> saveDoc(String caseId, String kind, Uint8List docx) async {
    final path = docPath(caseId, kind);
    final ok = await RepoService.writeRawFile(path, base64Encode(docx));
    return ok ? path : null;
  }

  // ---------- Templates ----------

  static Future<void> loadTemplates() async {
    _templates = await RepoService.listAllFiles('$templateRoot/');
  }

  static Future<bool> uploadTemplate(String fileName, List<int> bytes) async {
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final ok = await RepoService.writeRawFile('$templateRoot/$safe', base64Encode(bytes));
    if (ok) await loadTemplates();
    return ok;
  }

  static Future<bool> deleteTemplate(String path) async {
    final ok = await RepoService.deleteFile(path);
    if (ok) await loadTemplates();
    return ok;
  }

  static String templateUrl(String path) => RepoService.rawUrl(path);

  // ---------- Workflow helpers ----------

  static String waTextForPermit(RepairCase c) =>
      'Assalamualaikum ${c.contractorName}, kerja pembaikan telah diluluskan '
      '(Ruj: ${c.id} - ${c.system} di ${c.building}). Boleh pihak tuan sediakan '
      'permit kerja (work permit) dan mulakan kerja pembaikan? Terima kasih.';

  static String waTextForExecute(RepairCase c) =>
      'Assalamualaikum ${c.contractorName}, sila uruskan permit kerja dan '
      'jalankan kerja pembaikan bagi rujukan ${c.id} (${c.system} di ${c.building}). '
      'Mohon hantar gambar kemajuan kerja. Terima kasih.';
}