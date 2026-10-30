import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/todo.dart';
import '../services/remote_config_service.dart';
import '../services/todo_store.dart';
import '../services/update_service.dart';
import '../widgets/todo_editor.dart';
import '../widgets/update_banner.dart';

enum Filter { all, active, done }

class HomeScreen extends StatefulWidget {
  final TodoStore store;
  final RemoteConfigService remote;
  final UpdateService updater;

  const HomeScreen({
    super.key,
    required this.store,
    required this.remote,
    required this.updater,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Filter _filter = Filter.all;
  String? _category;
  String _query = '';
  bool _shownMandatory = false;

  TodoStore get store => widget.store;
  RemoteConfig get cfg => widget.remote.config;

  @override
  void initState() {
    super.initState();
    widget.updater.addListener(_onUpdaterChanged);
  }

  @override
  void dispose() {
    widget.updater.removeListener(_onUpdaterChanged);
    super.dispose();
  }

  void _onUpdaterChanged() {
    final u = widget.updater;
    if (u.status == UpdateStatus.available && u.isMandatory && !_shownMandatory) {
      _shownMandatory = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showUpdateDialog());
    }
    if (u.status == UpdateStatus.error && u.error != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(u.error!)));
    }
  }

  List<Todo> get _visible {
    final q = _query.trim().toLowerCase();
    final list = store.items.where((t) {
      if (_filter == Filter.active && t.done) return false;
      if (_filter == Filter.done && !t.done) return false;
      if (_category != null && t.category != _category) return false;
      if (q.isNotEmpty &&
          !t.title.toLowerCase().contains(q) &&
          !t.note.toLowerCase().contains(q)) {
        return false;
      }
      return true;
    }).toList();
    // غير المكتملة أولاً، ثم حسب الأولوية، ثم الأقرب موعداً
    list.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      if (cfg.featurePriorities && a.priority != b.priority) {
        return b.priority.index.compareTo(a.priority.index);
      }
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      if (a.dueDate != null) return -1;
      if (b.dueDate != null) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Future<void> _refresh() async {
    await Future.wait([widget.remote.refresh(), widget.updater.check()]);
  }

  Future<void> _openEditor([Todo? todo]) async {
    final result = await showModalBottomSheet<TodoDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => TodoEditor(config: cfg, initial: todo),
    );
    if (result == null) return;
    if (todo == null) {
      await store.add(
        title: result.title,
        note: result.note,
        priority: result.priority,
        category: result.category,
        dueDate: result.dueDate,
      );
    } else {
      todo
        ..title = result.title
        ..note = result.note
        ..priority = result.priority
        ..category = result.category
        ..dueDate = result.dueDate;
      await store.update(todo);
    }
  }

  Future<void> _delete(Todo t) async {
    final index = await store.remove(t);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('تم حذف "${t.title}"'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () => store.restore(t, index),
        ),
      ));
  }

  void _showUpdateDialog() {
    final u = widget.updater;
    final info = u.available;
    if (info == null) return;
    showDialog(
      context: context,
      barrierDismissible: !u.isMandatory,
      builder: (ctx) => PopScope(
        canPop: !u.isMandatory,
        child: ListenableBuilder(
          listenable: u,
          builder: (ctx, _) => AlertDialog(
            icon: const Icon(Icons.system_update_rounded, size: 40),
            title: Text('إصدار جديد ${info.version}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('النسخة الحالية: ${u.currentVersion} (${u.currentBuild})'),
                const SizedBox(height: 8),
                if (info.notes.isNotEmpty) ...[
                  const Text('ما الجديد:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(info.notes),
                ],
                if (u.status == UpdateStatus.downloading) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: u.progress),
                  const SizedBox(height: 4),
                  Text('جارٍ التحميل ${(u.progress * 100).toStringAsFixed(0)}%'),
                ],
                if (u.status == UpdateStatus.installing)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('اتبع شاشة التثبيت لإكمال التحديث'),
                  ),
              ],
            ),
            actions: [
              if (!u.isMandatory)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('لاحقاً'),
                ),
              FilledButton.icon(
                onPressed: u.status == UpdateStatus.downloading
                    ? null
                    : () => u.install(),
                icon: const Icon(Icons.download_rounded),
                label: Text(u.isWeb ? 'تحديث الآن' : 'تحميل وتثبيت'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout() {
    final u = widget.updater;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(cfg.appTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإصدار: ${u.currentVersion} (build ${u.currentBuild})'),
            Text('نسخة الإعدادات عن بعد: ${cfg.configVersion}'),
            if (widget.remote.lastFetched != null)
              Text('آخر مزامنة: ${DateFormat('HH:mm:ss').format(widget.remote.lastFetched!)}'),
            const SizedBox(height: 12),
            Text(
              u.isWeb
                  ? 'نسخة الويب تتحدث تلقائياً عند كل نشر.'
                  : 'التحديثات تصل من داخل التطبيق مباشرة.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, widget.remote, widget.updater]),
      builder: (context, _) {
        if (cfg.maintenanceEnabled) return _Maintenance(message: cfg.maintenanceMessage, onRetry: _refresh);
        final scheme = Theme.of(context).colorScheme;
        final visible = _visible;
        final u = widget.updater;

        return Scaffold(
          appBar: AppBar(
            title: Text(cfg.appTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (u.status == UpdateStatus.available)
                IconButton(
                  tooltip: 'تحديث متاح',
                  onPressed: _showUpdateDialog,
                  icon: Badge(
                    backgroundColor: scheme.error,
                    child: const Icon(Icons.system_update_rounded),
                  ),
                ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  switch (v) {
                    case 'clear':
                      final n = await store.clearCompleted();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('تم حذف $n مهمة مكتملة')));
                      }
                    case 'check':
                      await _refresh();
                      if (!context.mounted) return;
                      if (u.status == UpdateStatus.available) {
                        _showUpdateDialog();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('أنت تستخدم أحدث إصدار ✓')));
                      }
                    case 'about':
                      _showAbout();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'check', child: ListTile(leading: Icon(Icons.refresh), title: Text('البحث عن تحديثات'))),
                  PopupMenuItem(value: 'clear', child: ListTile(leading: Icon(Icons.cleaning_services_outlined), title: Text('حذف المكتملة'))),
                  PopupMenuItem(value: 'about', child: ListTile(leading: Icon(Icons.info_outline), title: Text('حول التطبيق'))),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add),
            label: const Text('مهمة جديدة'),
          ),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (u.status == UpdateStatus.available)
                  SliverToBoxAdapter(
                    child: UpdateBanner(
                      version: u.available!.version,
                      isWeb: u.isWeb,
                      onTap: _showUpdateDialog,
                    ),
                  ),
                if (cfg.announcementEnabled && cfg.announcementText.isNotEmpty)
                  SliverToBoxAdapter(child: _Announcement(cfg: cfg)),
                if (cfg.featureStats && store.total > 0)
                  SliverToBoxAdapter(child: _StatsCard(store: store)),
                SliverToBoxAdapter(child: _buildFilters(scheme)),
                if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      text: store.total == 0 ? cfg.emptyStateText : 'لا توجد نتائج مطابقة',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    sliver: SliverList.builder(
                      itemCount: visible.length,
                      itemBuilder: (_, i) => _TodoTile(
                        key: ValueKey(visible[i].id),
                        todo: visible[i],
                        cfg: cfg,
                        onToggle: () => store.toggle(visible[i]),
                        onTap: () => _openEditor(visible[i]),
                        onDelete: () => _delete(visible[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilters(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'ابحث في المهام...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                SegmentedButton<Filter>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: Filter.all, label: Text('الكل')),
                    ButtonSegment(value: Filter.active, label: Text('النشطة')),
                    ButtonSegment(value: Filter.done, label: Text('المكتملة')),
                  ],
                  selected: {_filter},
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
                if (cfg.featureCategories) ...[
                  const SizedBox(width: 8),
                  for (final c in cfg.categories)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: FilterChip(
                        label: Text(c),
                        selected: _category == c,
                        onSelected: (s) => setState(() => _category = s ? c : null),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoTile extends StatelessWidget {
  final Todo todo;
  final RemoteConfig cfg;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TodoTile({
    super.key,
    required this.todo,
    required this.cfg,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  Color _priorityColor(ColorScheme s) => switch (todo.priority) {
        Priority.high => Colors.red.shade400,
        Priority.medium => Colors.orange.shade400,
        Priority.low => Colors.green.shade400,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Dismissible(
      key: ValueKey('d-${todo.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        elevation: 0,
        color: todo.done ? scheme.surfaceContainerLow : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (cfg.featurePriorities)
                  Container(width: 5, color: todo.done ? Colors.transparent : _priorityColor(scheme)),
                Checkbox(
                  value: todo.done,
                  onChanged: (_) => onToggle(),
                  shape: const CircleBorder(),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          todo.title,
                          style: text.titleMedium?.copyWith(
                            decoration: todo.done ? TextDecoration.lineThrough : null,
                            color: todo.done ? scheme.outline : null,
                          ),
                        ),
                        if (todo.note.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(todo.note,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall?.copyWith(color: scheme.outline)),
                          ),
                        if ((cfg.featureCategories) || (cfg.featureDueDates && todo.dueDate != null))
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (cfg.featureCategories)
                                  _Pill(icon: Icons.label_outline, text: todo.category, color: scheme.primary),
                                if (cfg.featureDueDates && todo.dueDate != null)
                                  _Pill(
                                    icon: todo.isOverdue ? Icons.warning_amber_rounded : Icons.event,
                                    text: DateFormat('d MMM', 'ar').format(todo.dueDate!),
                                    color: todo.isOverdue ? scheme.error : scheme.tertiary,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Pill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ]),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final TodoStore store;
  const _StatsCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = store.total == 0 ? 0.0 : store.completed / store.total;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, scheme.tertiary],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: ratio,
                strokeWidth: 6,
                backgroundColor: Colors.white24,
                color: Colors.white,
              ),
              Text('${(ratio * 100).round()}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أنجزت ${store.completed} من ${store.total}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  store.overdue > 0 ? '⚠️ ${store.overdue} مهمة متأخرة' : 'استمر، أداء رائع! 💪',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Announcement extends StatelessWidget {
  final RemoteConfig cfg;
  const _Announcement({required this.cfg});

  @override
  Widget build(BuildContext context) {
    final url = cfg.announcementUrl;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: cfg.announcementColor.withValues(alpha: 0.15),
        border: Border.all(color: cfg.announcementColor.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(Icons.campaign_rounded, color: cfg.announcementColor),
        title: Text(cfg.announcementText),
        trailing: url == null ? null : const Icon(Icons.open_in_new, size: 18),
        onTap: url == null ? null : () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist_rtl_rounded, size: 80, color: scheme.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: scheme.outline, fontSize: 16)),
        ],
      ),
    );
  }
}

class _Maintenance extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _Maintenance({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.construction_rounded, size: 72),
            const SizedBox(height: 16),
            Text(message.isEmpty ? 'التطبيق تحت الصيانة، نعود قريباً' : message,
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
          ]),
        ),
      ),
    );
  }
}
