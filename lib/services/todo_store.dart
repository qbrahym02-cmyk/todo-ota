import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/todo.dart';

/// يخزّن المهام محلياً على الجهاز. التحديثات عن بعد لا تمس بيانات المستخدم.
class TodoStore extends ChangeNotifier {
  static const _key = 'todos_v1';
  final _uuid = const Uuid();
  final List<Todo> _items = [];
  SharedPreferences? _prefs;

  List<Todo> get items => List.unmodifiable(_items);
  int get total => _items.length;
  int get completed => _items.where((t) => t.done).length;
  int get overdue => _items.where((t) => t.isOverdue).length;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _items
          ..clear()
          ..addAll(list.map(Todo.fromJson));
      } catch (_) {/* بيانات تالفة: نبدأ من جديد */}
    }
    notifyListeners();
  }

  Future<void> _save() async {
    await _prefs?.setString(
        _key, jsonEncode(_items.map((t) => t.toJson()).toList()));
  }

  Future<void> add({
    required String title,
    String note = '',
    Priority priority = Priority.medium,
    String category = 'عام',
    DateTime? dueDate,
  }) async {
    _items.insert(
      0,
      Todo(
        id: _uuid.v4(),
        title: title,
        note: note,
        priority: priority,
        category: category,
        dueDate: dueDate,
      ),
    );
    notifyListeners();
    await _save();
  }

  Future<void> update(Todo todo) async {
    final i = _items.indexWhere((t) => t.id == todo.id);
    if (i != -1) _items[i] = todo;
    notifyListeners();
    await _save();
  }

  Future<void> toggle(Todo todo) async {
    todo.done = !todo.done;
    notifyListeners();
    await _save();
  }

  /// يرجع موقع العنصر المحذوف لإمكانية التراجع.
  Future<int> remove(Todo todo) async {
    final i = _items.indexWhere((t) => t.id == todo.id);
    if (i != -1) _items.removeAt(i);
    notifyListeners();
    await _save();
    return i;
  }

  Future<void> restore(Todo todo, int index) async {
    _items.insert(index.clamp(0, _items.length), todo);
    notifyListeners();
    await _save();
  }

  Future<int> clearCompleted() async {
    final n = completed;
    _items.removeWhere((t) => t.done);
    notifyListeners();
    await _save();
    return n;
  }
}
