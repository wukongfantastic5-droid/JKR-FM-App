import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/form_ocr_service.dart';

class FormScanOutcome {
  final FormOcrResult result;
  final String evidenceBase64;
  const FormScanOutcome(this.result, this.evidenceBase64);
}

/// Shows the camera/gallery picker, takes a photo, and runs OCR on it.
/// Returns null if the user cancels.
Future<FormScanOutcome?> pickAndScanForm(BuildContext context, {required bool eng}) async {
  final src = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(eng ? 'Scan Form' : 'Imbas Borang', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF0D7377)),
            title: Text(eng ? 'Take Photo' : 'Ambil Gambar'),
            subtitle: Text(eng ? 'Use camera' : 'Guna kamera'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF0D7377)),
            title: Text(eng ? 'Choose from Gallery' : 'Pilih dari Galeri'),
            subtitle: Text(eng ? 'Browse photos' : 'Cari gambar'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (src == null) return null;
  final file = await ImagePicker().pickImage(source: src, maxWidth: 1600, maxHeight: 1600, imageQuality: 90);
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final b64 = base64Encode(bytes);
  final result = await FormOcrService.scan(file.path);
  return FormScanOutcome(result, b64);
}
