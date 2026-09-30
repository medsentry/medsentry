import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  static SupabaseClient get client => _client;

  /// Test connection by checking if Supabase is initialized.
  static Future<bool> testConnection() async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final user = client.auth.currentUser;

      if (session != null || user != null) {
        debugPrint('Supabase connected (authenticated user: ${user?.email})');
      } else {
        debugPrint('Supabase connected (no active session)');
      }
      return true;
    } catch (e) {
      debugPrint('Supabase connection test failed: $e');
      return false;
    }
  }

  /// Get all records from a Supabase table.
  static Future<List<Map<String, dynamic>>> getFromTable(
    String tableName,
  ) async {
    try {
      final response = await _client.from(tableName).select();

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching from $tableName: $e');
      return [];
    }
  }

  /// Insert a record into a Supabase table.
  static Future<bool> insertIntoTable(
    String tableName,
    Map<String, dynamic> data,
  ) async {
    try {
      await _client.from(tableName).insert(data);
      return true;
    } catch (e) {
      debugPrint('Error inserting into $tableName: $e');
      return false;
    }
  }

  /// Sign in with email and password.
  static Future<bool> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response.user != null;
    } catch (e) {
      debugPrint('Sign in error: $e');
      return false;
    }
  }

  /// Sign out.
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
