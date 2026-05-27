import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around [Dio] for talking to the FastAPI backend.
///
/// Responsibilities kept deliberately small: base URL, timeouts tuned for slow
/// 2G/3G, and attaching the current Supabase JWT to every request. Feature
/// repositories talk to this; the sync engine is its main caller.
class ApiClient {
  ApiClient({required String baseUrl, SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client,
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            // Generous timeouts: a slow connection is normal, not a failure.
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            contentType: 'application/json',
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _supabase.auth.currentSession?.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final SupabaseClient _supabase;

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _dio.get<T>(path, queryParameters: query);
}
