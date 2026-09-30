import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/queue.dart';
import 'providers.dart';

/// Dashboard statistics model
class DashboardStats {
  final int totalPatients;
  final int newPatientsToday;
  final int activeQueueCount;
  final int consultationsToday;
  final int documentsToday;
  final int longWaitCount;
  final List<QueueItem> longWaitItems;
  final DateTime timestamp;

  DashboardStats({
    required this.totalPatients,
    required this.newPatientsToday,
    required this.activeQueueCount,
    required this.consultationsToday,
    required this.documentsToday,
    required this.longWaitCount,
    required this.longWaitItems,
    required this.timestamp,
  });

  /// Empty stats for initial state
  factory DashboardStats.empty() => DashboardStats(
    totalPatients: 0,
    newPatientsToday: 0,
    activeQueueCount: 0,
    consultationsToday: 0,
    documentsToday: 0,
    longWaitCount: 0,
    longWaitItems: [],
    timestamp: DateTime.now(),
  );
}

/// Provider for dashboard statistics
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  ref.keepAlive();
  final db = ref.watch(databaseProvider);

  // Fetch all stats in parallel
  final results = await Future.wait([
    db.getPatientCount(),
    db.getTodayPatientCount(),
    db.getActiveQueueCount(),
    db.getTodayConsultationCount(),
    db.getTodayDocumentCount(),
    db.getLongWaitQueueCount(60), // 60 minutes threshold
    db.getLongWaitQueueItems(60),
  ]);

  return DashboardStats(
    totalPatients: results[0] as int,
    newPatientsToday: results[1] as int,
    activeQueueCount: results[2] as int,
    consultationsToday: results[3] as int,
    documentsToday: results[4] as int,
    longWaitCount: results[5] as int,
    longWaitItems: results[6] as List<QueueItem>,
    timestamp: DateTime.now(),
  );
});

/// Stream provider for real-time dashboard updates
final dashboardStatsStreamProvider = StreamProvider<DashboardStats>((
  ref,
) async* {
  // Initial fetch
  final stats = await ref.read(dashboardStatsProvider.future);
  yield stats;

  // Poll every 30 seconds for updates
  while (true) {
    await Future.delayed(const Duration(seconds: 30));
    final db = ref.read(databaseProvider);

    final results = await Future.wait([
      db.getPatientCount(),
      db.getTodayPatientCount(),
      db.getActiveQueueCount(),
      db.getTodayConsultationCount(),
      db.getTodayDocumentCount(),
      db.getLongWaitQueueCount(60),
      db.getLongWaitQueueItems(60),
    ]);

    yield DashboardStats(
      totalPatients: results[0] as int,
      newPatientsToday: results[1] as int,
      activeQueueCount: results[2] as int,
      consultationsToday: results[3] as int,
      documentsToday: results[4] as int,
      longWaitCount: results[5] as int,
      longWaitItems: results[6] as List<QueueItem>,
      timestamp: DateTime.now(),
    );
  }
});
