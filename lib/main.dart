import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/app.dart';
import 'src/data/local/isar_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isar = await IsarService().open();
  runApp(ProviderScope(
    overrides: [isarProvider.overrideWithValue(isar)],
    child: const MiniPOSApp(),
  ));
}
