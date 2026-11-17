import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'application/providers.dart';
// Entrypoint del motor en segundo plano (@pragma vm:entry-point). Debe estar
// en el grafo de imports para que se compile en release.
// ignore: unused_import
import 'background.dart';
import 'infrastructure/db/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await AppDatabase.open();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const FinaidApp(),
    ),
  );
}
