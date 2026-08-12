import 'package:flutter/material.dart';

import '../localization.dart';
import '../services/repo_service.dart';
import '../screens/system_check_screen.dart';

/// Red banner that surfaces RepoService.lastHttpError on any screen.
/// Dismiss clears the error; new errors re-appear after a build.
class HttpErrorBanner extends StatefulWidget {
  const HttpErrorBanner({super.key});

  @override
  State<HttpErrorBanner> createState() => _HttpErrorBannerState();
}

class _HttpErrorBannerState extends State<HttpErrorBanner> {
  String _seen = '';
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final e = RepoService.lastHttpError;
    if (e.isEmpty) {
      _seen = '';
      _hidden = false;
      return const SizedBox.shrink();
    }
    if (e != _seen) {
      _seen = e;
      _hidden = false;
    }
    if (_hidden) return const SizedBox.shrink();
    final eng = LanguageProvider.isEnglish(context);
    return Material(
      color: const Color(0xFFC62828),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${eng ? 'Sync issue' : 'Masalah sinkronisasi'}: $e',
                style: const TextStyle(color: Colors.white, fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.troubleshoot_rounded, size: 18, color: Colors.white),
              tooltip: eng ? 'System check' : 'Penyemakan sistem',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SystemCheckScreen()),
              ),
            ),
            TextButton(
              onPressed: () {
                RepoService.lastHttpError = '';
                setState(() => _hidden = true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}