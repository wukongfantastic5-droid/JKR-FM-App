import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Slim, always-visible copyright strip shown at the bottom of EVERY page
/// (rendered globally through MaterialApp.builder). It never intercepts taps.
class CopyrightBar extends StatelessWidget {
  const CopyrightBar({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 18,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .scaffoldBackgroundColor
              .withValues(alpha: 0.94),
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
            ),
          ),
        ),
        child: FutureBuilder<String>(
          future: PackageInfo.fromPlatform()
              .then((pi) => pi.version)
              .catchError((_) => '1.0.0'),
          builder: (_, snap) => Text(
            'Developed by Zainal | Version V${snap.data ?? '1.0.0'}',
            style: TextStyle(
              fontSize: 9.5,
              letterSpacing: 0.3,
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}