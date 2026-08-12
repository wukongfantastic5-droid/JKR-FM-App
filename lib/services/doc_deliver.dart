import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'repo_service.dart';

/// Shared delivery for generated Word documents.
/// - Desktop: writes into Downloads\FM_Report\<folder>\<file>.
/// - Mobile: database save first, then offer to open the doc in the browser.
class DocDeliver {
  /// Returns the local folder path, or '' when the platform cannot write to
  /// Downloads (mobile/web) or the write failed.
  static Future<String> saveLocal(
    String folder,
    String fileName,
    Uint8List bytes,
  ) async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.windows &&
            defaultTargetPlatform != TargetPlatform.linux &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      return '';
    }
    try {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'];
      if (home == null || home.isEmpty) return '';
      var downloads = Directory('$home\\Downloads');
      if (!downloads.existsSync()) downloads = Directory('$home/Downloads');
      final dir = Directory('${downloads.path}\\FM_Report\\$folder');
      dir.createSync(recursive: true);
      File('${dir.path}\\$fileName').writeAsBytesSync(bytes);
      return dir.path;
    } catch (e) {
      debugPrint('[DocDeliver] local save: $e');
      return '';
    }
  }

  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<bool> isDesktop() async =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// On mobile: prompt to open the saved document in the browser.
  /// Returns true when the user chose to open it.
  static Future<bool> offerOpen(
    BuildContext context, {
    required String repoPath,
    required bool eng,
  }) async {
    if (!isMobile) return false;
    final url = RepoService.rawUrl(repoPath);
    if (url.isEmpty) return false;
    final open = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.description_rounded, size: 36, color: Color(0xFF0D7377)),
        title: Text(eng
            ? 'Document saved in database'
            : 'Dokumen disimpan dalam database'),
        content: Text(eng
            ? 'Open the document in your browser now?'
            : 'Buka dokumen dalam pelayar anda sekarang?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(eng ? 'Later' : 'Nanti'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(eng ? 'Open' : 'Buka'),
          ),
        ],
      ),
    );
    if (open != true) return false;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return true;
  }
}