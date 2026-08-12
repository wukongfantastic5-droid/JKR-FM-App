import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/technician_data.dart';
import '../localization.dart';
import '../services/repo_service.dart';
import '../services/tech_service.dart';

class TechAccountScreen extends StatefulWidget {
  final Technician? existing;

  const TechAccountScreen({super.key, this.existing});

  @override
  State<TechAccountScreen> createState() => _TechAccountScreenState();
}

class _TechAccountScreenState extends State<TechAccountScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final ImagePicker _picker = ImagePicker();
  String? _photoB64;
  String? _photoPath;
  bool _loading = false;
  String _techId = 'A';

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    RepoService.ensureEnv();
    final t = widget.existing;
    if (t != null) {
      _techId = t.id;
      _nameCtrl.text = t.name;
      _emailCtrl.text = t.email;
      _passCtrl.text = t.password;
      _ageCtrl.text = t.age > 0 ? '${t.age}' : '';
      _phoneCtrl.text = t.phone;
      _icCtrl.text = t.icNumber;
      _photoPath = t.photoPath;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _icCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _photoB64 = base64Encode(bytes));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo error: $e')));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final eng = LanguageProvider.isEnglish(context);
    try {
      await TechService.loadTechStatus();

      String? photoPath = _photoPath;
      if (_photoB64 != null) {
        final path = 'tech_photos/$_techId.jpg';
        final ok = await RepoService.writeRawFile(path, _photoB64!);
        if (!ok) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(eng ? 'Photo upload to GitHub failed' : 'Muat naik foto ke GitHub gagal'),
            ));
          }
          setState(() => _loading = false);
          return;
        }
        photoPath = path;
      }

      final now = DateTime.now().toIso8601String();
      final tech = Technician(
        id: _techId,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        age: int.tryParse(_ageCtrl.text.trim()) ?? 0,
        phone: _phoneCtrl.text.trim(),
        icNumber: _icCtrl.text.trim(),
        photoPath: photoPath ?? '',
        createdAt: _isEdit && widget.existing!.createdAt.isNotEmpty
            ? widget.existing!.createdAt
            : now,
        updatedAt: now,
      );
      await TechService.saveTechAccount(tech);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(eng
            ? 'Technician ${_isEdit ? 'updated' : 'saved'} in GitHub database'
            : 'Teknisi ${_isEdit ? 'dikemas kini' : 'disimpan'} dalam pangkalan data GitHub'),
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eng = LanguageProvider.isEnglish(context);
    final usedIds = TechService.technicians.map((t) => t.id).toSet();
    final ids = ['A', 'B', 'C', 'D', 'E'];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit
            ? (eng ? 'Edit Technician' : 'Edit Teknisi')
            : (eng ? 'Add Technician' : 'Tambah Teknisi')),
      ),
      body: AbsorbPointer(
        absorbing: _loading,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundColor: const Color(0xFF0D7377).withValues(alpha: 0.15),
                      backgroundImage: _photoB64 != null
                          ? MemoryImage(base64Decode(_photoB64!))
                          : (_photoPath != null && _photoPath!.isNotEmpty
                              ? NetworkImage(TechService.photoUrl(widget.existing!))
                              : null),
                      child: (_photoB64 == null && (_photoPath == null || _photoPath!.isEmpty))
                          ? Text(_techId, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF0D7377)))
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D7377),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.photo_camera_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                _photoB64 != null || (_photoPath != null && _photoPath!.isNotEmpty)
                    ? (eng ? 'Tap to change photo' : 'Tekan untuk tukar foto')
                    : (eng ? 'Tap to pick photo from gallery' : 'Tekan untuk pilih foto dari galeri'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  if (!_isEdit)
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Technician ID',
                        prefixIcon: Icon(Icons.tag_rounded),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: ids.contains(_techId) ? _techId : ids.first,
                          isDense: true,
                          isExpanded: true,
                          items: ids.map((id) {
                            final taken = usedIds.contains(id);
                            return DropdownMenuItem(
                              value: id,
                              enabled: !taken,
                              child: Text(taken ? '$id (${eng ? 'taken' : 'digunakan'})' : id),
                            );
                          }).toList(),
                          onChanged: _loading ? null : (v) => setState(() => _techId = v!),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_rounded),
                    ),
                    validator: (v) => v?.contains('@') == true ? null : 'Valid email required',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password (min 6)',
                      prefixIcon: Icon(Icons.lock_rounded),
                    ),
                    validator: (v) => (v?.length ?? 0) >= 6 ? null : 'Minimum 6 characters',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      prefixIcon: Icon(Icons.cake_rounded),
                    ),
                    validator: (v) => (int.tryParse(v?.trim() ?? '') ?? 0) > 0 ? null : 'Valid age required',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    validator: (v) => (v?.trim().length ?? 0) >= 8 ? null : 'Valid phone required',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _icCtrl,
                    decoration: const InputDecoration(
                      labelText: 'ID Number',
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _save,
                      icon: _loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _isEdit ? (eng ? 'Update Profile' : 'Kemas Kini Profil') : (eng ? 'Save Account' : 'Simpan Akaun'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
