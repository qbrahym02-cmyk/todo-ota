enum Priority { low, medium, high }

extension PriorityX on Priority {
  String get label => switch (this) {
        Priority.low => 'منخفضة',
        Priority.medium => 'متوسطة',
        Priority.high => 'عالية',
      };
}

class Todo {
  final String id;
  String title;
  String note;
  bool done;
  Priority priority;
  String category;
  DateTime? dueDate;
  final DateTime createdAt;

  Todo({
    required this.id,
    required this.title,
    this.note = '',
    this.done = false,
    this.priority = Priority.medium,
    this.category = 'عام',
    this.dueDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isOverdue {
    if (done || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dueDate!.isBefore(today);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'done': done,
        'priority': priority.name,
        'category': category,
        'dueDate': dueDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        note: j['note'] as String? ?? '',
        done: j['done'] as bool? ?? false,
        priority: Priority.values.firstWhere(
          (p) => p.name == j['priority'],
          orElse: () => Priority.medium,
        ),
        category: j['category'] as String? ?? 'عام',
        dueDate: j['dueDate'] == null ? null : DateTime.tryParse(j['dueDate']),
        createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
      );
}
