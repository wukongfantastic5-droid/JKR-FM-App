import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../localization.dart';

/// Parsed content of an asset QR sticker produced by the inventory screen:
///   JKR FM ASSET
///   Floor: L5
///   System: 1.0
///   Type: Lift Motor
///   Qty: 2
class QrScanResult {
  final String floor;
  final String system;
  final String type;
  final int qty;
  final String raw;

  const QrScanResult({
    required this.floor,
    required this.system,
    required this.type,
    required this.qty,
    required this.raw,
  });

  static QrScanResult? parse(String raw) {
    String _val(String label) {
      for (final line in raw.split('\n')) {
        final t = line.trim();
        if (t.startsWith('$label:')) return t.substring(label.length + 1).trim();
      }
      return '';
    }

    final type = _val('Type');
    final floor = _val('Floor');
    final system = _val('System');
    if (type.isEmpty && floor.isEmpty) {
      if (raw.trim().toUpperCase().contains('JKR FM ASSET')) {
        // Sticker present but fields missing — treat the whole text as type.
        return QrScanResult(
            floor: floor, system: system, type: raw.trim(), qty: 0, raw: raw);
      }
      return null;
    }
    return QrScanResult(
      floor: floor,
      system: system,
      type: type,
      qty: int.tryParse(_val('Qty')) ?? 0,
      raw: raw,
    );
  }
}

/// Full-screen camera QR scanner. Pops with a [QrScanResult] when the user
/// taps "Find in Inventory", or null when they close/back out.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  bool _handled = false;
  bool _torch = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _started = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    await _controller.stop();
    if (!mounted) return;
    _showResult(raw);
  }

  void _showResult(String raw) {
    final eng = LanguageProvider.isEnglish(context);
    final result = QrScanResult.parse(raw);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) {
        if (result == null) {
          return Padding(
            padding: EdgeInsets.only(
                left: 20, right: 20, top: 18, bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_2_rounded, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                Text(eng ? 'Unknown QR code' : 'QR tidak dikenali',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SelectableText(raw,
                    style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _rescan();
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: Text(eng ? 'Scan again' : 'Imbas semula'),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('ASSET QR',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(result.type,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _infoRow('Floor', 'Aras', result.floor),
              _infoRow('System', 'Sistem', result.system),
              _infoRow('Qty', 'Kuantiti', '${result.qty}'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _rescan();
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: Text(eng ? 'Scan again' : 'Imbas semula'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0D7377)),
                      onPressed: () => Navigator.of(context).pop(result),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: Text(eng ? 'Find in Inventory' : 'Cari dalam Inventori'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String enLabel, String bmLabel, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text('$enLabel / $bmLabel:',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 12.5),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Future<void> _rescan() async {
    setState(() => _handled = false);
    if (!_started) {
      await _controller.start();
      _started = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(eng ? 'Scan QR Sticker' : 'Imbas Label QR'),
        actions: [
          IconButton(
            icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            onPressed: () async {
              final v = !_torch;
              setState(() => _torch = v);
              await _controller.toggleTorch();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Text(
              eng
                  ? 'Point the camera at an asset QR sticker'
                  : 'Halakan kamera ke label QR aset',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}