import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../db/database.dart';
import '../network/api_client.dart';

/// Composition root.
///
/// All shared singletons are wired here as Riverpod providers so features
/// depend on abstractions, not on construction details. Keeping the graph in
/// one place makes it trivial to override dependencies in tests (e.g. swap in
/// an in-memory database).

/// App configuration (overridden in `main` once env is read).
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);

/// The Supabase client. Assumes `Supabase.initialize` ran in `main`.
final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// The single local database. Disposed with the container.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// HTTP client to the backend, with the auth interceptor attached.
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return ApiClient(
    baseUrl: config.apiBaseUrl,
    supabase: ref.watch(supabaseProvider),
  );
});
