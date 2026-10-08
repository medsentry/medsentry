import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

/// Dashboard statistics model
class DashboardStats {
  final int totalPatients;
  final int newPatientsToday;
  final int documentsToday;
  final DateTime timestamp;

  DashboardStats({
    required this.totalPatients,
    required this.newPatientsToday,
    required this.documentsToday,
    required this.timestamp,
  });

  /// Empty stats for initial state
  factory DashboardStats.empty() => DashboardStats(
    totalPatients: 0,
    newPatientsToday: 0,
    documentsToday: 0,
    timestamp: DateTime.now(),
  );
}

/// Provider for dashboard statistics
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  ref.keepAlive();
  ref.watch(databaseChangesProvider);
  final db = ref.watch(databaseProvider);

  final results = await Future.wait<int>([
    db.getPatientCount(),
    db.getTodayPatientCount(),
    db.getTodayDocumentCount(),
  ]);

  return DashboardStats(
    totalPatients: results[0],
    newPatientsToday: results[1],
    documentsToday: results[2],
    timestamp: DateTime.now(),
  );
});

// NOTE: dashboardStatsStreamProvider removed — it contained an infinite polling
// loop that caused a memory leak. dashboardStatsProvider already reacts to
// databaseChangesProvider, which emits after every local write and after every
// successful cloud sync. No separate stream provider is needed.
