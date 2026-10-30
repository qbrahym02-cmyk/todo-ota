import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/home_screen.dart';
import 'services/remote_config_service.dart';
import 'services/todo_store.dart';
import 'services/update_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  final store = TodoStore();
  final remote = RemoteConfigService();
  final updater = UpdateService();

  await store.load();
  // لا ننتظر الشبكة لكي يفتح التطبيق فوراً
  remote.init();
  updater.init();

  runApp(TodoApp(store: store, remote: remote, updater: updater));
}

class TodoApp extends StatelessWidget {
  final TodoStore store;
  final RemoteConfigService remote;
  final UpdateService updater;

  const TodoApp({
    super.key,
    required this.store,
    required this.remote,
    required this.updater,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: remote,
      builder: (context, _) {
        final cfg = remote.config;
        ThemeData theme(Brightness b) => ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: cfg.primaryColor,
                brightness: b,
              ),
              fontFamily: 'Roboto',
            );
        return MaterialApp(
          title: cfg.appTitle,
          debugShowCheckedModeBanner: false,
          theme: theme(Brightness.light),
          darkTheme: theme(Brightness.dark),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HomeScreen(store: store, remote: remote, updater: updater),
        );
      },
    );
  }
}
