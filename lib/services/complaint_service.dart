import 'package:flutter/foundation.dart' show debugPrint;
import '../data/complaint_data.dart';
import 'floor_plan_service.dart';
import 'repo_service.dart';

class ComplaintService {
  static const _fileName = 'complaints.json';
  static final bool _debug = true;

  static final Map<String, String> _evidenceCache = {};

  static void _log(String msg) {
    if (_debug) debugPrint('[Complaint] $msg');
  }

  /// CMMS-style reference number, e.g. JKRBG26002742.
  static String buildNoRuj(int seqId) =>
      'JKRBG${seqId.toString().padLeft(8, '0')}';

  static void _invalidateFloorPlans() => FloorPlanService.invalidate();

  static Future<Map<String, dynamic>> _readStore() async {
    try {
      final data = await RepoService.readFile(_fileName);
      // Old format: plain array → migrate
      if (data is List) {
        return {'nextSeq': data.length + 1, 'tickets': data};
      }
      // New format: map with nextSeq + tickets
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      _log('load error: $e');
    }
    return {'nextSeq': 1, 'tickets': <dynamic>[]};
  }

  static Future<bool> _writeStore(int nextSeq, List<ComplaintTicket> tickets) async {
    try {
      return await RepoService.writeFile(_fileName, {
        'nextSeq': nextSeq,
        'tickets': tickets.map((e) => e.toJson()).toList(),
      });
    } catch (e) {
      _log('save error: $e');
      return false;
    }
  }

  static Future<List<ComplaintTicket>> load() async {
    final store = await _readStore();
    final list = store['tickets'] as List;
    return list.map((e) => ComplaintTicket.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<bool> save(List<ComplaintTicket> tickets) async {
    int nextSeq = 1;
    if (tickets.isNotEmpty) {
      nextSeq = tickets.map((t) => t.seqId).reduce((a, b) => a > b ? a : b) + 1;
    }
    return await _writeStore(nextSeq, tickets);
  }

  static Future<bool> add(ComplaintTicket ticket, {String? evidenceBase64}) async {
    try {
      final store = await _readStore();
      int nextSeq = store['nextSeq'] as int? ?? 1;
      final tickets = (store['tickets'] as List).map((e) => ComplaintTicket.fromJson(e as Map<String, dynamic>)).toList();

      // Fix seqId on existing tickets that lack it (migration)
      bool migrated = false;
      for (int i = 0; i < tickets.length; i++) {
        if (tickets[i].seqId == 0) {
          tickets[i] = ComplaintTicket(
            id: tickets[i].id, seqId: i + 1,
            userId: tickets[i].userId, complainerName: tickets[i].complainerName,
            complainerPhone: tickets[i].complainerPhone, reportedAt: tickets[i].reportedAt,
            floor: tickets[i].floor, issueType: tickets[i].issueType,
            workCategory: tickets[i].workCategory, priority: tickets[i].priority,
            noRuj: tickets[i].noRuj,
            assetName: tickets[i].assetName,
            description: tickets[i].description, status: tickets[i].status,
            evidenceFile: tickets[i].evidenceFile, createdAt: tickets[i].createdAt,
            updatedAt: tickets[i].updatedAt,
          );
          migrated = true;
        }
      }
      if (migrated) nextSeq = tickets.length + 1;

      final ref = ticket.noRuj != null && ticket.noRuj!.trim().isNotEmpty
          ? ticket.noRuj!.trim()
          : buildNoRuj(nextSeq);

      if (evidenceBase64 != null) {
        final path = 'evidence/${ticket.id}.jpg';
        final ok = await RepoService.writeRawFile(path, evidenceBase64);
        if (ok) {
          _evidenceCache[path] = evidenceBase64;
          ticket = ComplaintTicket(
            id: ticket.id, seqId: nextSeq,
            userId: ticket.userId, complainerName: ticket.complainerName,
            complainerPhone: ticket.complainerPhone, reportedAt: ticket.reportedAt,
            floor: ticket.floor, issueType: ticket.issueType,
            workCategory: ticket.workCategory, priority: ticket.priority,
            noRuj: ref,
            assetName: ticket.assetName, description: ticket.description,
            status: ticket.status, evidenceFile: path,
            createdAt: ticket.createdAt,
          );
          _log('evidence saved to $path');
        } else {
          _log('failed to save evidence to $path');
          ticket = ComplaintTicket(
            id: ticket.id, seqId: nextSeq,
            userId: ticket.userId, complainerName: ticket.complainerName,
            complainerPhone: ticket.complainerPhone, reportedAt: ticket.reportedAt,
            floor: ticket.floor, issueType: ticket.issueType,
            workCategory: ticket.workCategory, priority: ticket.priority,
            noRuj: ref,
            assetName: ticket.assetName, description: ticket.description,
            status: ticket.status, createdAt: ticket.createdAt,
          );
        }
      } else {
        ticket = ComplaintTicket(
          id: ticket.id, seqId: nextSeq,
          userId: ticket.userId, complainerName: ticket.complainerName,
          complainerPhone: ticket.complainerPhone, reportedAt: ticket.reportedAt,
          floor: ticket.floor, issueType: ticket.issueType,
          workCategory: ticket.workCategory, priority: ticket.priority,
          noRuj: ref,
          assetName: ticket.assetName, description: ticket.description,
          status: ticket.status, createdAt: ticket.createdAt,
        );
      }

      tickets.add(ticket);
      final ok = await _writeStore(nextSeq + 1, tickets);
      _invalidateFloorPlans();
      _log('added ticket #${ticket.seqId} (${ticket.id}) ruj=${ticket.noRuj} saved=$ok');
      return ok;
    } catch (e) {
      _log('add error: $e');
      return false;
    }
  }

  static Future<String?> getEvidenceBase64(String path) async {
    if (_evidenceCache.containsKey(path)) return _evidenceCache[path];
    final b64 = await RepoService.readRawFile(path);
    if (b64 != null) _evidenceCache[path] = b64;
    return b64;
  }

  static Future<bool> delete(String id) async {
    try {
      final tickets = await load();
      tickets.removeWhere((t) => t.id == id);
      final ok = await save(tickets);
      _invalidateFloorPlans();
      _log('deleted ticket $id saved=$ok');
      return ok;
    } catch (e) {
      _log('delete error: $e');
      return false;
    }
  }

  static Future<bool> update(String id,
      {String? status, String? description, String? assignedAsset, bool clearAssignedAsset = false}) async {
    try {
      final tickets = await load();
      final idx = tickets.indexWhere((t) => t.id == id);
      if (idx == -1) {
        _log('update error: ticket $id not found');
        return false;
      }
      var t = tickets[idx];
      if (status != null) {
        t = t.copyWith(status: status);
      }
      if (description != null) {
        t = t.copyWith(description: description);
      }
      if (assignedAsset != null || clearAssignedAsset) {
        t = t.copyWith(assignedAsset: assignedAsset, clearAssignedAsset: clearAssignedAsset);
      }
      tickets[idx] = t;
      final ok = await save(tickets);
      _invalidateFloorPlans();
      _log('updated ticket $id → ${t.status} assigned=${t.assignedAsset} saved=$ok');
      return ok;
    } catch (e) {
      _log('update error: $e');
      return false;
    }
  }

  static Future<List<ComplaintTicket>> getByUser(String userId) async {
    final tickets = await load();
    return tickets.where((t) => t.userId == userId).toList();
  }

  static Future<List<ComplaintTicket>> getOpen(String floor) async {
    final tickets = await load();
    return tickets.where((t) => t.floor == floor && (t.status == 'open' || t.status == 'in_progress')).toList();
  }
}
