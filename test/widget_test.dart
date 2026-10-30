import 'package:flutter_test/flutter_test.dart';
import 'package:todo_ota/models/todo.dart';
import 'package:todo_ota/services/remote_config_service.dart';

void main() {
  test('Todo JSON round-trip', () {
    final t = Todo(id: '1', title: 'اختبار', priority: Priority.high, dueDate: DateTime(2030));
    final r = Todo.fromJson(t.toJson());
    expect(r.title, 'اختبار');
    expect(r.priority, Priority.high);
    expect(r.dueDate, DateTime(2030));
  });

  test('RemoteConfig parses and falls back to defaults', () {
    final c = RemoteConfig.fromJson({'app_title': 'X', 'primary_color': '#FF0000', 'features': {'stats': false}});
    expect(c.appTitle, 'X');
    expect(c.featureStats, false);
    expect(c.featurePriorities, true);
    expect(c.categories, isNotEmpty);
  });
}
