import 'package:flutter/material.dart';
import '../data/slang_data.dart';

class SlangScreen extends StatefulWidget {
  final List<SlangEntry> entries;
  final ValueChanged<List<SlangEntry>> onChanged;

  const SlangScreen({
    super.key,
    required this.entries,
    required this.onChanged,
  });

  @override
  State<SlangScreen> createState() => _SlangScreenState();
}

class _SlangScreenState extends State<SlangScreen> {
  late List<SlangEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.entries.isEmpty ? defaultSlangEntries() : List.from(widget.entries);
  }

  void _add() {
    showDialog(
      context: context,
      builder: (ctx) => _SlangDialog(
        onSave: (e) => setState(() => _entries.add(e)),
      ),
    );
  }

  void _edit(int index) {
    showDialog(
      context: context,
      builder: (ctx) => _SlangDialog(
        entry: _entries[index],
        onSave: (e) => setState(() => _entries[index] = e),
      ),
    );
  }

  void _delete(int index) {
    setState(() => _entries.removeAt(index));
  }

  String _buildRulesText() {
    return _entries.map((e) => '"${e.standard}" → "${e.kelantan}"').join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slang Dictionary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Save & Apply',
            onPressed: () {
              widget.onChanged(List.from(_entries));
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Add word pairs below. AI will use these when replying in Kelantan.',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade700, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Text('No slang entries yet. Tap + to add.',
                      style: TextStyle(color: Colors.grey.shade500)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _entries.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == _entries.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          child: Center(
                            child: Text('${_entries.length} word(s) · ${_buildRulesText().split('\n').length} rules',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ),
                        );
                      }
                      final e = _entries[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          title: Text('${e.standard} → ${e.kelantan}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: e.phonetic.isNotEmpty
                              ? Text('TTS: ${e.phonetic}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                onPressed: () => _edit(i),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                                onPressed: () => _delete(i),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _SlangDialog extends StatefulWidget {
  final SlangEntry? entry;
  final ValueChanged<SlangEntry> onSave;

  const _SlangDialog({this.entry, required this.onSave});

  @override
  State<_SlangDialog> createState() => _SlangDialogState();
}

class _SlangDialogState extends State<_SlangDialog> {
  late TextEditingController _stdCtrl;
  late TextEditingController _kelCtrl;
  late TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _stdCtrl = TextEditingController(text: widget.entry?.standard ?? '');
    _kelCtrl = TextEditingController(text: widget.entry?.kelantan ?? '');
    _phoneCtrl = TextEditingController(text: widget.entry?.phonetic ?? '');
  }

  @override
  void dispose() {
    _stdCtrl.dispose();
    _kelCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.entry == null ? 'Add Slang' : 'Edit Slang'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _stdCtrl, decoration: const InputDecoration(labelText: 'Standard Malay', isDense: true)),
          const SizedBox(height: 8),
          TextField(controller: _kelCtrl, decoration: const InputDecoration(labelText: 'Kelantan', isDense: true)),
          const SizedBox(height: 8),
          TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'TTS Pronunciation (optional)', isDense: true)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_stdCtrl.text.isEmpty || _kelCtrl.text.isEmpty) return;
            widget.onSave(SlangEntry(
              standard: _stdCtrl.text.trim(),
              kelantan: _kelCtrl.text.trim(),
              phonetic: _phoneCtrl.text.trim(),
            ));
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
