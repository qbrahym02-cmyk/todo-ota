import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/todo.dart';
import '../services/remote_config_service.dart';

class TodoDraft {
  final String title;
  final String note;
  final Priority priority;
  final String category;
  final DateTime? dueDate;
  TodoDraft(this.title, this.note, this.priority, this.category, this.dueDate);
}

class TodoEditor extends StatefulWidget {
  final RemoteConfig config;
  final Todo? initial;
  const TodoEditor({super.key, required this.config, this.initial});

  @override
  State<TodoEditor> createState() => _TodoEditorState();
}

class _TodoEditorState extends State<TodoEditor> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _note = TextEditingController(text: widget.initial?.note ?? '');
  late Priority _priority = widget.initial?.priority ?? Priority.medium;
  late String _category = widget.initial?.category ?? widget.config.categories.first;
  late DateTime? _due = widget.initial?.dueDate;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      TodoDraft(_title.text.trim(), _note.text.trim(), _priority, _category, _due),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) setState(() => _due = d);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.config;
    final categories = {...cfg.categories, _category}.toList();
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.initial == null ? 'مهمة جديدة' : 'تعديل المهمة',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _title,
                autofocus: widget.initial == null,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'عنوان المهمة',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'اكتب عنوان المهمة' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (cfg.featurePriorities) ...[
                const SizedBox(height: 16),
                const Text('الأولوية'),
                const SizedBox(height: 6),
                SegmentedButton<Priority>(
                  segments: [
                    for (final p in Priority.values.reversed)
                      ButtonSegment(value: p, label: Text(p.label)),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (s) => setState(() => _priority = s.first),
                ),
              ],
              if (cfg.featureCategories) ...[
                const SizedBox(height: 16),
                const Text('التصنيف'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in categories)
                      ChoiceChip(
                        label: Text(c),
                        selected: _category == c,
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
                ),
              ],
              if (cfg.featureDueDates) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.event),
                        label: Text(_due == null
                            ? 'إضافة موعد نهائي'
                            : DateFormat('EEEE d MMMM y', 'ar').format(_due!)),
                      ),
                    ),
                    if (_due != null)
                      IconButton(
                        onPressed: () => setState(() => _due = null),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: Text(widget.initial == null ? 'إضافة' : 'حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
