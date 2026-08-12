import 'package:flutter/material.dart';
import '../data/pronunciation_data.dart';

class PronunciationScreen extends StatefulWidget {
  final List<PronunciationCorrection> corrections;
  final ValueChanged<List<PronunciationCorrection>> onChanged;

  const PronunciationScreen({
    super.key,
    required this.corrections,
    required this.onChanged,
  });

  @override
  State<PronunciationScreen> createState() => _PronunciationScreenState();
}

class _PronunciationScreenState extends State<PronunciationScreen> {
  late List<PronunciationCorrection> _corrections;

  @override
  void initState() {
    super.initState();
    _corrections = widget.corrections.isEmpty
        ? defaultPronunciationCorrections()
        : List.from(widget.corrections);
  }

  void _add() {
    final wrongCtrl = TextEditingController();
    final correctCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Correction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wrongCtrl,
              decoration: const InputDecoration(labelText: 'STT hears (wrong)', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: correctCtrl,
              decoration: const InputDecoration(labelText: 'Correct to', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (wrongCtrl.text.isEmpty || correctCtrl.text.isEmpty) return;
              setState(() => _corrections.add(PronunciationCorrection(
                wrong: wrongCtrl.text.trim().toLowerCase(),
                correct: correctCtrl.text.trim(),
              )));
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _edit(int index) {
    final e = _corrections[index];
    final wrongCtrl = TextEditingController(text: e.wrong);
    final correctCtrl = TextEditingController(text: e.correct);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Correction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wrongCtrl,
              decoration: const InputDecoration(labelText: 'STT hears (wrong)', isDense: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: correctCtrl,
              decoration: const InputDecoration(labelText: 'Correct to', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (wrongCtrl.text.isEmpty || correctCtrl.text.isEmpty) return;
              setState(() => _corrections[index] = PronunciationCorrection(
                wrong: wrongCtrl.text.trim().toLowerCase(),
                correct: correctCtrl.text.trim(),
              ));
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final builtIn = defaultPronunciationCorrections().length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pronunciation Fix'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            tooltip: 'Save & Apply',
            onPressed: () {
              widget.onChanged(List.from(_corrections));
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
                    'Fix misheard words. If STT hears "chila" instead of "chiller", add it here.',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade700, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _corrections.isEmpty
                ? Center(
                    child: Text('No corrections yet. Tap + to add.',
                      style: TextStyle(color: Colors.grey.shade500)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _corrections.length + 1,
                    itemBuilder: (ctx, i) {
                      if (i == _corrections.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          child: Center(
                            child: Text('${_corrections.length} correction(s) · $builtIn built-in',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          ),
                        );
                      }
                      final e = _corrections[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          title: Text('"${e.wrong}" → "${e.correct}"',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          subtitle: Text(
                            'STT hears "${e.wrong}" → corrects to "${e.correct}"',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, size: 18),
                                onPressed: () => _edit(i),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                                onPressed: () => setState(() => _corrections.removeAt(i)),
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
