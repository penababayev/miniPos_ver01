import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/data/local/isar_service.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarService.instance.init(); // ✅ Isar hazır
  runApp(const ProviderScope(child: MiniPOSApp()));
}
