import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/db/database.dart';
import 'data/repository/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = await AppDatabase.create();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: const BibleApp(),
    ),
  );
}
