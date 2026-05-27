import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/di/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();

  // Supabase only needs the network for auth; cached sessions let the app open
  // straight to data while offline. See ARCHITECTURE.md §7.
  await Supabase.initialize(
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
      ],
      child: const BhukuApp(),
    ),
  );
}

class BhukuApp extends StatelessWidget {
  const BhukuApp({super.key});

  // Brand colours — kept minimal until the design system feature lands.
  static const _seed = Color(0xFF0245AA);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bhuku',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _seed),
        useMaterial3: true,
      ),
      home: const _FoundationsPlaceholder(),
    );
  }
}

/// Temporary landing screen. Replaced by auth + dashboard in later steps.
class _FoundationsPlaceholder extends StatelessWidget {
  const _FoundationsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bhuku')),
      body: const Center(
        child: Text('Foundations ready. Features come next.'),
      ),
    );
  }
}
