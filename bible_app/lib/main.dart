import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db/database.dart';
import 'data/repository/providers.dart';
import 'services/prefs_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final results = await Future.wait([
    AppDatabase.create(),
    PrefsService.load(),
  ]);

  final db = results[0] as AppDatabase;

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const BibleApp(),
    ),
  );
}
