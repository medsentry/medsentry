import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/patient.dart';
import '../models/queue.dart';
import '../models/user.dart';
import '../providers/providers.dart';
import '../services/triage_service.dart';
import '../utils/context_extensions.dart';
import '../utils/date_time_format.dart';
import '../widgets/app_form_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/status_badge.dart';
import '../widgets/layout/responsive_layout.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  String _searchQuery = '';
  QueueStatus? _statusFilter;
  Priority? _priorityFilter;

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(queueProvider);
    final currentUser = ref.watch(currentUserProvider);
    final canConsult = currentUser?.canConsult ?? false;
    final canRecordVitals = currentUser?.canRecordVitals ?? false;
    final canManageQueue = currentUser?.canManageQueue ?? false;

    return queueAsync.when(
      skipLoadingOnReload: true,
      data: (items) {
        final sortedItems = List<QueueItem>.from(items)
          ..sort((a, b) {
            final priorityDiff = b.priority.index.compareTo(a.priority.index);
            if (priorityDiff != 0) return priorityDiff;
            return a.arrivalTime.compareTo(b.arrivalTime);
          });

        final filteredItems = sortedItems.where((item) {
          final matchesSearch =
              _searchQuery.isEmpty ||
              (item.patientName ?? '').toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              (item.purpose ?? '').toLowerCase().contains(
                _searchQuery.toLowerCase(),
              );

          final matchesStatus =
              _statusFilter == null || item.status == _statusFilter;
          final matchesPriority =
              _priorityFilter == null || item.priority == _priorityFilter;

          return matchesSearch && matchesStatus && matchesPriority;
        }).toList();

        final waitingCount = items
            .where((i) => i.status == QueueStatus.waiting)
            .length;
        final urgentCount = items
            .where(
              (i) =>
                  i.priority == Priority.emergency ||
                  i.priority == Priority.high,
            )
            .length;
        final avgWait = items.isEmpty
            ? 0
            : items
                      .map(
                        (i) =>
                            DateTime.now().difference(i.arrivalTime).inMinutes,
                      )
                      .reduce((a, b) => a + b) ~/
                  items.length;

        if (items.isEmpty) {
          return _buildEmptyState(context, currentUser);
        }

        return ResponsiveContentContainer(
          child: Column(
            children: [
            _QueueDashboardHeader(
              totalCount: items.length,
              waitingCount: waitingCount,
              urgentCount: urgentCount,
              avgWaitMinutes: avgWait,
              onAddToQueue: canManageQueue
                  ? () => _showAddToQueueDialog(context, ref)
                  : null,
            ),
            _QueueFiltersBar(
              searchQuery: _searchQuery,
              statusFilter: _statusFilter,
              priorityFilter: _priorityFilter,
              onSearchChanged: (value) =>
                  setState(() => _searchQuery = value.trim()),
              onStatusChanged: (value) => setState(() => _statusFilter = value),
              onPriorityChanged: (value) =>
                  setState(() => _priorityFilter = value),
              onClearFilters: () => setState(() {
                _searchQuery = '';
                _statusFilter = null;
                _priorityFilter = null;
              }),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filteredItems.isEmpty
                  ? _buildNoMatchState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = filteredItems[index];
                        final waitTime = DateTime.now().difference(
                          item.arrivalTime,
                        );
                        final waitMinutes = waitTime.inMinutes;

                        return _QueueProfessionalCard(
                          queueItem: item,
                          waitMinutes: waitMinutes,
                          onTap: canConsult
                              ? () => context.push('/queue/${item.id}/soap')
                              : null,
                          onRemove: canManageQueue
                              ? () => _showRemoveDialog(context, ref, item)
                              : null,
                          onVitalsTap: canRecordVitals
                              ? () => _showVitalsDialog(context, ref, item)
                              : null,
                          onStatusTap: canManageQueue
                              ? () => _showStatusDialog(context, ref, item)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        ),
      );
      },
      loading: () => const LoadingState(),
      error: (error, stack) => _buildErrorState(context, error),
    );
  }

  Widget _buildEmptyState(BuildContext context, User? currentUser) {
    final canManageQueue = currentUser?.canManageQueue == true;
    final canRegisterPatients = currentUser?.canRegisterPatients == true;

    return EmptyState(
      icon: Icons.queue_outlined,
      title: 'Queue is currently empty',
      message:
          'Patients added from registration will appear here for triage and consultation.',
      action: canManageQueue
          ? FilledButton.icon(
              onPressed: () => _showAddToQueueDialog(context, ref),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Add Patient to Queue'),
            )
          : (canRegisterPatients
                ? ElevatedButton.icon(
                    onPressed: () => context.go('/patients'),
                    icon: const Icon(Icons.person_search_outlined),
                    label: const Text('Register or Search Patient'),
                  )
                : null),
    );
  }

  Widget _buildNoMatchState(BuildContext context) {
    return Center(
      child: Text(
        'No queue items match the current filters.',
        style: TextStyle(color: Theme.of(context).hintColor),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
        ),
        child: Text('Unable to load queue: $error'),
      ),
    );
  }

  void _showRemoveDialog(BuildContext context, WidgetRef ref, QueueItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Queue'),
        content: Text(
          'Remove ${item.patientName ?? 'Unknown Patient'} from the queue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Use the repository directly instead of notifier
              final repository = ref.read(queueRepositoryProvider);
              await repository.removeFromQueue(item.id);
              // Invalidate the provider to refresh the list
              ref.invalidate(queueProvider);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showVitalsDialog(BuildContext context, WidgetRef ref, QueueItem item) {
    if (!(ref.read(currentUserProvider)?.canRecordVitals ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only staff can record vitals.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _VitalsDialog(
        queueItem: item,
        onSave: (updatedItem) async {
          await ref.read(queueRepositoryProvider).updateQueueItem(updatedItem);
          ref.invalidate(queueProvider);
          ref.invalidate(patientQueueHistoryProvider(updatedItem.patientId));
        },
      ),
    );
  }

  void _showStatusDialog(BuildContext context, WidgetRef ref, QueueItem item) {
    if (!(ref.read(currentUserProvider)?.canManageQueue ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only queue managers can update status.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _QueueStatusDialog(
        queueItem: item,
        onSave: (updatedItem) async {
          await ref.read(queueRepositoryProvider).updateQueueItem(updatedItem);
          ref.invalidate(queueProvider);
          ref.invalidate(patientQueueHistoryProvider(updatedItem.patientId));
        },
      ),
    );
  }

  void _showAddToQueueDialog(BuildContext context, WidgetRef ref) {
    if (!(ref.read(currentUserProvider)?.canManageQueue ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only staff and administrators can add patients to the queue.',
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _AddToQueueModal(
        onSaved: () {
          ref.invalidate(queueProvider);
        },
      ),
    );
  }
}

class _AddToQueueModal extends ConsumerStatefulWidget {
  final VoidCallback onSaved;

  const _AddToQueueModal({required this.onSaved});

  @override
  ConsumerState<_AddToQueueModal> createState() => _AddToQueueModalState();
}

class _AddToQueueModalState extends ConsumerState<_AddToQueueModal> {
  final _formKey = GlobalKey<FormState>();
  Patient? _selectedPatient;
  final _purposeController = TextEditingController(
    text: 'General Consultation',
  );
  final _complaintController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _purposeController.dispose();
    _complaintController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please search and select a patient first.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final patient = _selectedPatient!;
      final purpose = _purposeController.text.trim().isEmpty
          ? 'General Consultation'
          : _purposeController.text.trim();

      await ref
          .read(queueRepositoryProvider)
          .addToQueue(patient.id, patient.fullName, purpose);

      widget.onSaved();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${patient.fullName} added to triage queue.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add to queue: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientsAsync = ref.watch(patientsProvider);
    final patients = patientsAsync.valueOrNull ?? [];

    return AppFormDialog(
      icon: Icons.person_add_outlined,
      title: 'Add Patient to Queue',
      subtitle: 'Search registered patient and assign intake triage purpose',
      maxWidth: 580,
      isLoading: _isSaving,
      loadingText: 'Adding patient to queue...',
      content: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppFormSection(
              icon: Icons.person_search_outlined,
              title: 'Patient Selection',
              subtitle: 'Search by full name, PhilHealth, contact, or barangay',
              child: AppSearchableDropdown<Patient>(
                label: 'Registered Patient',
                hint: 'Search patient...',
                required: true,
                value: _selectedPatient,
                items: patients,
                itemLabel: (p) => '${p.fullName} (${p.id})',
                itemSubtitle: (p) =>
                    'Age: ${p.age ?? 'N/A'} • ${p.gender ?? ''} • Brgy. ${p.barangay ?? 'N/A'}',
                itemLeading: (p) => CircleAvatar(
                  radius: 18,
                  child: Text(p.initials, style: const TextStyle(fontSize: 12)),
                ),
                searchMatcher: (p, q) {
                  final haystack = [
                    p.fullName,
                    p.id,
                    p.contactNumber ?? '',
                    p.barangay ?? '',
                    p.philHealthNumber ?? '',
                  ].join(' ').toLowerCase();
                  return haystack.contains(q);
                },
                onChanged: (p) => setState(() => _selectedPatient = p),
              ),
            ),
            const SizedBox(height: 16),
            AppFormSection(
              icon: Icons.receipt_long_outlined,
              title: 'Visit Details',
              subtitle: 'Specify primary purpose of visit',
              child: Column(
                children: [
                  AppTextField(
                    controller: _purposeController,
                    label: 'Purpose of Visit',
                    required: true,
                    icon: Icons.medical_services_outlined,
                    hint: 'e.g. General Consultation, Prenatal, Immunization',
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: _complaintController,
                    label: 'Chief Complaint (Optional)',
                    icon: Icons.chat_bubble_outline,
                    hint: 'Brief patient-reported primary symptom',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _submit,
          icon: const Icon(Icons.check),
          label: const Text('Add to Queue'),
        ),
      ],
    );
  }
}

class _QueueStatusDialog extends StatefulWidget {
  final QueueItem queueItem;
  final Future<void> Function(QueueItem updatedItem) onSave;

  const _QueueStatusDialog({required this.queueItem, required this.onSave});

  @override
  State<_QueueStatusDialog> createState() => _QueueStatusDialogState();
}

class _QueueStatusDialogState extends State<_QueueStatusDialog> {
  late QueueStatus _status;
  late final TextEditingController _roomController;
  late final TextEditingController _purposeController;
  late final TextEditingController _complaintController;
  late final TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.queueItem;
    _status = item.status;
    _roomController = TextEditingController(text: item.roomNumber ?? '');
    _purposeController = TextEditingController(text: item.purpose ?? '');
    _complaintController = TextEditingController(text: item.complaint ?? '');
    _notesController = TextEditingController(text: item.notes ?? '');
  }

  @override
  void dispose() {
    _roomController.dispose();
    _purposeController.dispose();
    _complaintController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Update Queue - ${widget.queueItem.patientName ?? 'Patient'}',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<QueueStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Queue status',
                  border: OutlineInputBorder(),
                ),
                items: QueueStatus.values
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(_queueStatusLabel(status)),
                      ),
                    )
                    .toList(),
                onChanged: (status) =>
                    setState(() => _status = status ?? QueueStatus.waiting),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _roomController,
                      decoration: const InputDecoration(
                        labelText: 'Room / Station',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _purposeController,
                      decoration: const InputDecoration(
                        labelText: 'Purpose',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _complaintController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Chief complaint',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Queue notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _QueueStatusAutomationNote(status: _status),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final updated = _buildUpdatedQueueItem(widget.queueItem);

    try {
      await widget.onSave(updated);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Queue updated to ${updated.statusDisplay}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  QueueItem _buildUpdatedQueueItem(QueueItem item) {
    final now = DateTime.now();
    final shouldStart =
        _status == QueueStatus.inProgress && item.startTime == null;
    final shouldEnd =
        (_status == QueueStatus.completed ||
            _status == QueueStatus.cancelled) &&
        item.endTime == null;

    return QueueItem(
      id: item.id,
      patientId: item.patientId,
      patientName: item.patientName,
      isSenior: item.isSenior,
      isPregnant: item.isPregnant,
      isPwd: item.isPwd,
      isInfant: item.isInfant,
      arrivalTime: item.arrivalTime,
      startTime: shouldStart ? now : item.startTime,
      endTime: shouldEnd ? now : item.endTime,
      status: _status,
      nurseId: item.nurseId,
      doctorId: item.doctorId,
      complaint: _emptyToNull(_complaintController.text),
      notes: _emptyToNull(_notesController.text),
      purpose: _emptyToNull(_purposeController.text),
      temperature: item.temperature,
      bloodPressureSystolic: item.bloodPressureSystolic,
      bloodPressureDiastolic: item.bloodPressureDiastolic,
      heartRate: item.heartRate,
      respiratoryRate: item.respiratoryRate,
      oxygenSaturation: item.oxygenSaturation,
      weight: item.weight,
      height: item.height,
      redFlags: item.redFlags,
      painScale: item.painScale,
      isEssentiallyNormal: item.isEssentiallyNormal,
      priority: item.priority,
      roomNumber: _emptyToNull(_roomController.text),
      bmi: item.bmi,
      createdAt: item.createdAt,
      updatedAt: now,
      syncStatus: item.syncStatus == 0 ? 2 : item.syncStatus,
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _QueueStatusAutomationNote extends StatelessWidget {
  final QueueStatus status;

  const _QueueStatusAutomationNote({required this.status});

  @override
  Widget build(BuildContext context) {
    final message = switch (status) {
      QueueStatus.waiting => 'Patient remains in the waiting queue.',
      QueueStatus.inProgress => 'Start time is set automatically when needed.',
      QueueStatus.completed => 'End time is set automatically when completed.',
      QueueStatus.cancelled => 'End time is set automatically when cancelled.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class _VitalsDialog extends StatefulWidget {
  final QueueItem queueItem;
  final Future<void> Function(QueueItem updatedItem) onSave;

  const _VitalsDialog({required this.queueItem, required this.onSave});

  @override
  State<_VitalsDialog> createState() => _VitalsDialogState();
}

class _VitalsDialogState extends State<_VitalsDialog> {
  late final TextEditingController _temperatureController;
  late final TextEditingController _systolicController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _heartRateController;
  late final TextEditingController _respiratoryRateController;
  late final TextEditingController _oxygenController;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final TextEditingController _notesController;

  final Set<RedFlag> _selectedRedFlags = {};
  int _painScale = 0;
  bool _isEssentiallyNormal = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.queueItem;
    _temperatureController = TextEditingController(
      text: _formatNumber(item.temperature),
    );
    _systolicController = TextEditingController(
      text: _formatNumber(item.bloodPressureSystolic),
    );
    _diastolicController = TextEditingController(
      text: _formatNumber(item.bloodPressureDiastolic),
    );
    _heartRateController = TextEditingController(
      text: _formatNumber(item.heartRate),
    );
    _respiratoryRateController = TextEditingController(
      text: _formatNumber(item.respiratoryRate),
    );
    _oxygenController = TextEditingController(
      text: _formatNumber(item.oxygenSaturation),
    );
    _weightController = TextEditingController(text: _formatNumber(item.weight));
    _heightController = TextEditingController(text: _formatNumber(item.height));
    _notesController = TextEditingController(text: item.notes ?? '');
    _selectedRedFlags.addAll(item.redFlags);
    _painScale = item.painScale ?? 0;
    _isEssentiallyNormal = item.isEssentiallyNormal;
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _oxygenController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calculated = _calculatePreview();

    return AppFormDialog(
      icon: Icons.monitor_heart_outlined,
      title: 'Record Patient Vitals',
      subtitle:
          '${widget.queueItem.patientName ?? 'Patient'} • Queue ID: ${widget.queueItem.id}',
      maxWidth: 820,
      isLoading: _isSaving,
      loadingText: 'Saving patient vitals & updating priority...',
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppFormSection(
              icon: Icons.speed_outlined,
              title: 'Vital Signs Measurements',
              subtitle:
                  'Input current measurements with live physiological range checks',
              child: _buildVitalsGrid(),
            ),
            const SizedBox(height: 16),
            AppFormSection(
              icon: Icons.healing_outlined,
              title: 'Pain Assessment & Stability',
              subtitle:
                  'Self-reported pain intensity scale and clinical observation',
              child: _buildPainAndNormalControls(),
            ),
            const SizedBox(height: 16),
            AppFormSection(
              icon: Icons.warning_amber_rounded,
              title: 'Emergency Red Flag Screening',
              subtitle:
                  'Check all present high-risk indicators to escalate triage priority',
              child: _buildRedFlags(),
            ),
            const SizedBox(height: 16),
            AppFormSection(
              icon: Icons.note_alt_outlined,
              title: 'Triage Intake Notes & Classification',
              subtitle: 'Calculated BMI and priority categorization',
              child: Column(
                children: [
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nurse / Triage Notes',
                      hintText: 'Brief intake notes or chief complaint details',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TriagePreview(
                    priority: calculated.priority,
                    bmi: calculated.bmi,
                    bmiCategory: calculated.bmiCategory,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.favorite_outline),
          label: const Text('Save Vitals'),
        ),
      ],
    );
  }

  Widget _buildVitalsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 620 ? 3 : 2;
        final width = (constraints.maxWidth - (12 * (columns - 1))) / columns;
        final fields = [
          _VitalsField(
            label: 'Temperature',
            suffix: '°C',
            controller: _temperatureController,
            contextualWarning: (v) {
              final val = double.tryParse(v ?? '');
              return ClinicalRanges.evaluateTemp(val);
            },
          ),
          _VitalsField(
            label: 'BP Systolic',
            suffix: 'mmHg',
            controller: _systolicController,
            contextualWarning: (v) {
              final sys = double.tryParse(v ?? '');
              final dia = double.tryParse(_diastolicController.text);
              return ClinicalRanges.evaluateBP(sys, dia);
            },
          ),
          _VitalsField(
            label: 'BP Diastolic',
            suffix: 'mmHg',
            controller: _diastolicController,
          ),
          _VitalsField(
            label: 'Heart Rate',
            suffix: 'bpm',
            controller: _heartRateController,
            contextualWarning: (v) {
              final val = double.tryParse(v ?? '');
              return ClinicalRanges.evaluateHR(val);
            },
          ),
          _VitalsField(
            label: 'Resp. Rate',
            suffix: 'cpm',
            controller: _respiratoryRateController,
            contextualWarning: (v) {
              final val = double.tryParse(v ?? '');
              return ClinicalRanges.evaluateRR(val);
            },
          ),
          _VitalsField(
            label: 'Oxygen Sat.',
            suffix: '%',
            controller: _oxygenController,
            contextualWarning: (v) {
              final val = double.tryParse(v ?? '');
              return ClinicalRanges.evaluateSpO2(val);
            },
          ),
          _VitalsField(
            label: 'Weight',
            suffix: 'kg',
            controller: _weightController,
          ),
          _VitalsField(
            label: 'Height',
            suffix: 'cm',
            controller: _heightController,
          ),
        ];

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: fields
              .map((field) => SizedBox(width: width, child: field))
              .toList(),
        );
      },
    );
  }

  Widget _buildPainAndNormalControls() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pain Scale: $_painScale/10',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Slider(
                    value: _painScale.toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    label: '$_painScale',
                    onChanged: (value) =>
                        setState(() => _painScale = value.round()),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: SwitchListTile(
              title: const Text('Essentially Normal'),
              subtitle: const Text('No abnormal assessment findings noted'),
              value: _isEssentiallyNormal,
              onChanged: (value) =>
                  setState(() => _isEssentiallyNormal = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRedFlags() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Red Flags',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: RedFlag.values.map((flag) {
                final selected = _selectedRedFlags.contains(flag);
                return FilterChip(
                  label: Text(flag.displayName),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedRedFlags.add(flag);
                      } else {
                        _selectedRedFlags.remove(flag);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final validationError = _validateVitals();
    if (validationError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(validationError)));
      return;
    }

    setState(() => _isSaving = true);
    final calculated = _calculatePreview();

    final updated = widget.queueItem.copyWith(
      temperature: _parseDouble(_temperatureController.text),
      bloodPressureSystolic: _parseDouble(_systolicController.text),
      bloodPressureDiastolic: _parseDouble(_diastolicController.text),
      heartRate: _parseDouble(_heartRateController.text),
      respiratoryRate: _parseDouble(_respiratoryRateController.text),
      oxygenSaturation: _parseDouble(_oxygenController.text),
      weight: _parseDouble(_weightController.text),
      height: _parseDouble(_heightController.text),
      redFlags: _selectedRedFlags.toList(),
      painScale: _painScale,
      isEssentiallyNormal: _isEssentiallyNormal,
      priority: calculated.priority,
      bmi: calculated.bmi,
      status: widget.queueItem.status == QueueStatus.waiting
          ? QueueStatus.inProgress
          : widget.queueItem.status,
      startTime:
          widget.queueItem.status == QueueStatus.waiting &&
              widget.queueItem.startTime == null
          ? DateTime.now()
          : widget.queueItem.startTime,
      notes: _notesController.text.trim().isEmpty
          ? widget.queueItem.notes
          : _notesController.text.trim(),
      updatedAt: DateTime.now(),
      syncStatus: widget.queueItem.syncStatus == 0
          ? 2
          : widget.queueItem.syncStatus,
    );

    try {
      await widget.onSave(updated);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vitals saved. Priority: ${updated.priorityDisplay.toUpperCase()}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _validateVitals() {
    final checks = <_VitalRangeCheck>[
      _VitalRangeCheck(
        label: 'Temperature',
        value: _temperatureController.text,
        min: 30,
        max: 45,
        unit: 'C',
      ),
      _VitalRangeCheck(
        label: 'Systolic BP',
        value: _systolicController.text,
        min: 50,
        max: 260,
        unit: 'mmHg',
      ),
      _VitalRangeCheck(
        label: 'Diastolic BP',
        value: _diastolicController.text,
        min: 30,
        max: 160,
        unit: 'mmHg',
      ),
      _VitalRangeCheck(
        label: 'Heart rate',
        value: _heartRateController.text,
        min: 20,
        max: 220,
        unit: 'bpm',
      ),
      _VitalRangeCheck(
        label: 'Respiratory rate',
        value: _respiratoryRateController.text,
        min: 5,
        max: 80,
        unit: '/min',
      ),
      _VitalRangeCheck(
        label: 'Oxygen saturation',
        value: _oxygenController.text,
        min: 0,
        max: 100,
        unit: '%',
      ),
      _VitalRangeCheck(
        label: 'Weight',
        value: _weightController.text,
        min: 0.5,
        max: 500,
        unit: 'kg',
      ),
      _VitalRangeCheck(
        label: 'Height',
        value: _heightController.text,
        min: 30,
        max: 250,
        unit: 'cm',
      ),
    ];

    for (final check in checks) {
      final rawValue = check.value.trim();
      if (rawValue.isEmpty) continue;

      final parsed = double.tryParse(rawValue);
      if (parsed == null) {
        return '${check.label} must be a valid number.';
      }
      if (parsed < check.min || parsed > check.max) {
        return '${check.label} must be between ${check.minText} and ${check.maxText} ${check.unit}.';
      }
    }

    final systolic = _parseDouble(_systolicController.text);
    final diastolic = _parseDouble(_diastolicController.text);
    if (systolic != null && diastolic != null && systolic <= diastolic) {
      return 'Systolic BP must be higher than diastolic BP.';
    }

    return null;
  }

  _TriageCalculation _calculatePreview() {
    final height = _parseDouble(_heightController.text);
    final weight = _parseDouble(_weightController.text);
    final bmi = TriageService.calculateBMI(height, weight);
    final priority = TriageService.calculatePriority(
      redFlags: _selectedRedFlags.toList(),
      temperature: _parseDouble(_temperatureController.text),
      systolicBP: _parseDouble(_systolicController.text),
      diastolicBP: _parseDouble(_diastolicController.text),
      heartRate: _parseDouble(_heartRateController.text),
      respiratoryRate: _parseDouble(_respiratoryRateController.text),
      oxygenSaturation: _parseDouble(_oxygenController.text),
      painScale: _painScale,
      isSenior: widget.queueItem.isSenior,
      isPregnant: widget.queueItem.isPregnant,
      isInfant: widget.queueItem.isInfant,
      isEssentiallyNormal: _isEssentiallyNormal,
    );

    return _TriageCalculation(
      priority: priority,
      bmi: bmi,
      bmiCategory: TriageService.getBMICategory(bmi),
    );
  }

  double? _parseDouble(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  String _formatNumber(double? value) {
    if (value == null) return '';
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }
}

class _VitalRangeCheck {
  final String label;
  final String value;
  final double min;
  final double max;
  final String unit;

  const _VitalRangeCheck({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
  });

  String get minText => _formatLimit(min);
  String get maxText => _formatLimit(max);

  String _formatLimit(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }
}

class _VitalsField extends StatelessWidget {
  final String label;
  final String suffix;
  final TextEditingController controller;
  final String? Function(String?)? contextualWarning;

  const _VitalsField({
    required this.label,
    required this.suffix,
    required this.controller,
    this.contextualWarning,
  });

  @override
  Widget build(BuildContext context) {
    final warning = contextualWarning?.call(controller.text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            border: const OutlineInputBorder(),
          ),
        ),
        if (warning != null && warning.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            warning,
            style: TextStyle(
              fontSize: 10,
              color: Colors.amber.shade900,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _TriageCalculation {
  final Priority priority;
  final double? bmi;
  final BMICategory bmiCategory;

  const _TriageCalculation({
    required this.priority,
    required this.bmi,
    required this.bmiCategory,
  });
}

class _TriagePreview extends StatelessWidget {
  final Priority priority;
  final double? bmi;
  final BMICategory bmiCategory;

  const _TriagePreview({
    required this.priority,
    required this.bmi,
    required this.bmiCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: priority.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: priority.color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety_outlined, color: priority.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calculated Priority: ${priority.displayName.toUpperCase()}',
                  style: TextStyle(
                    color: priority.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(TriageService.getTriageRecommendation(priority)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            bmi == null
                ? 'BMI: N/A'
                : 'BMI: ${bmi!.toStringAsFixed(1)} (${bmiCategory.displayName})',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

extension _PriorityDisplay on Priority {
  String get displayName {
    switch (this) {
      case Priority.low:
        return 'Low';
      case Priority.normal:
        return 'Normal';
      case Priority.high:
        return 'High';
      case Priority.emergency:
        return 'Emergency';
    }
  }

  Color get color {
    switch (this) {
      case Priority.low:
        return Colors.grey;
      case Priority.normal:
        return Colors.blue;
      case Priority.high:
        return Colors.orange;
      case Priority.emergency:
        return Colors.red;
    }
  }
}

class _QueueDashboardHeader extends StatelessWidget {
  final int totalCount;
  final int waitingCount;
  final int urgentCount;
  final int avgWaitMinutes;
  final VoidCallback? onAddToQueue;

  const _QueueDashboardHeader({
    required this.totalCount,
    required this.waitingCount,
    required this.urgentCount,
    required this.avgWaitMinutes,
    this.onAddToQueue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 900;
          final chips = [
            _MetricChip(
              label: 'Total',
              value: '$totalCount',
              color: context.semanticColors.info,
            ),
            _MetricChip(
              label: 'Waiting',
              value: '$waitingCount',
              color: context.semanticColors.warning,
            ),
            _MetricChip(
              label: 'Urgent',
              value: '$urgentCount',
              color: context.semanticColors.critical,
            ),
            _MetricChip(
              label: 'Avg Wait',
              value: '${avgWaitMinutes}m',
              color: context.semanticColors.normal,
            ),
          ];

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Triage Queue',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Prioritized patient intake and triage flow',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onAddToQueue != null)
                      FilledButton.icon(
                        onPressed: onAddToQueue,
                        icon: const Icon(
                          Icons.person_add_alt_1_outlined,
                          size: 18,
                        ),
                        label: const Text('Add to Queue'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: chips,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Triage Queue',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Prioritized patient flow for staff intake and consultation',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips,
              ),
              if (onAddToQueue != null) ...[
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onAddToQueue,
                  icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                  label: const Text('Add to Queue'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: TextStyle(color: color.withValues(alpha: 0.9), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _QueueFiltersBar extends StatelessWidget {
  final String searchQuery;
  final QueueStatus? statusFilter;
  final Priority? priorityFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<QueueStatus?> onStatusChanged;
  final ValueChanged<Priority?> onPriorityChanged;
  final VoidCallback onClearFilters;

  const _QueueFiltersBar({
    required this.searchQuery,
    required this.statusFilter,
    required this.priorityFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onPriorityChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search patient or purpose',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: onSearchChanged,
            ),
          ),
          DropdownButton<QueueStatus?>(
            value: statusFilter,
            hint: const Text('Status'),
            onChanged: onStatusChanged,
            items: [
              const DropdownMenuItem<QueueStatus?>(
                value: null,
                child: Text('All Status'),
              ),
              ...QueueStatus.values.map(
                (status) => DropdownMenuItem<QueueStatus?>(
                  value: status,
                  child: Text(_statusLabel(status)),
                ),
              ),
            ],
          ),
          DropdownButton<Priority?>(
            value: priorityFilter,
            hint: const Text('Priority'),
            onChanged: onPriorityChanged,
            items: [
              const DropdownMenuItem<Priority?>(
                value: null,
                child: Text('All Priority'),
              ),
              ...Priority.values.map(
                (priority) => DropdownMenuItem<Priority?>(
                  value: priority,
                  child: Text(priority.name.toUpperCase()),
                ),
              ),
            ],
          ),
          if (searchQuery.isNotEmpty ||
              statusFilter != null ||
              priorityFilter != null)
            TextButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.clear),
              label: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  static String _statusLabel(QueueStatus status) {
    return _queueStatusLabel(status);
  }
}

String _queueStatusLabel(QueueStatus status) {
  switch (status) {
    case QueueStatus.waiting:
      return 'Waiting';
    case QueueStatus.inProgress:
      return 'In Progress';
    case QueueStatus.completed:
      return 'Completed';
    case QueueStatus.cancelled:
      return 'Cancelled';
  }
}

class _QueueProfessionalCard extends StatelessWidget {
  final QueueItem queueItem;
  final int waitMinutes;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onVitalsTap;
  final VoidCallback? onStatusTap;

  const _QueueProfessionalCard({
    required this.queueItem,
    required this.waitMinutes,
    required this.onTap,
    required this.onRemove,
    required this.onVitalsTap,
    required this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final waitColor = _getWaitTimeColor(context, waitMinutes);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: waitColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${waitMinutes}m',
                    style: TextStyle(
                      color: waitColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      queueItem.patientName ?? 'Unknown Patient',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Arrived ${_formatTime(queueItem.arrivalTime)} • ${queueItem.purpose ?? 'General Consultation'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        StatusBadge.fromPriority(queueItem.priority),
                        StatusBadge.fromQueueStatus(queueItem.status),
                        StatusBadge(
                          text: queueItem.vitalsTaken
                              ? 'Vitals Complete'
                              : 'Vitals Pending',
                          status: queueItem.vitalsTaken
                              ? BadgeStatus.normal
                              : BadgeStatus.warning,
                          icon: queueItem.vitalsTaken
                              ? Icons.favorite
                              : Icons.favorite_outline,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (context.isMobile)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Actions',
                  onSelected: (action) {
                    switch (action) {
                      case 'vitals':
                        onVitalsTap?.call();
                        break;
                      case 'status':
                        onStatusTap?.call();
                        break;
                      case 'soap':
                        onTap?.call();
                        break;
                      case 'remove':
                        onRemove?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (onVitalsTap != null)
                      const PopupMenuItem(
                        value: 'vitals',
                        child: ListTile(
                          leading: Icon(Icons.favorite_outline),
                          title: Text('Record Vitals'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (onStatusTap != null)
                      const PopupMenuItem(
                        value: 'status',
                        child: ListTile(
                          leading: Icon(Icons.manage_history_outlined),
                          title: Text('Update Status'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (onTap != null)
                      const PopupMenuItem(
                        value: 'soap',
                        child: ListTile(
                          leading: Icon(Icons.arrow_forward),
                          title: Text('Open SOAP'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (onRemove != null)
                      PopupMenuItem(
                        value: 'remove',
                        child: ListTile(
                          leading: Icon(
                            Icons.remove_circle_outline,
                            color: colorScheme.error,
                          ),
                          title: Text(
                            'Remove from Queue',
                            style: TextStyle(color: colorScheme.error),
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                )
              else
                Column(
                  children: [
                    if (onVitalsTap != null)
                      IconButton(
                        tooltip: 'Record Vitals',
                        icon: const Icon(Icons.favorite_outline),
                        onPressed: onVitalsTap,
                      ),
                    if (onStatusTap != null)
                      IconButton(
                        tooltip: 'Update Status',
                        icon: const Icon(Icons.manage_history_outlined),
                        onPressed: onStatusTap,
                      ),
                    if (onTap != null)
                      IconButton(
                        tooltip: 'Open SOAP',
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: onTap,
                      ),
                    if (onRemove != null)
                      IconButton(
                        tooltip: 'Remove from queue',
                        icon: const Icon(Icons.remove_circle_outline),
                        color: colorScheme.error,
                        onPressed: onRemove,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _getWaitTimeColor(BuildContext context, int minutes) {
    final colors = context.semanticColors;
    if (minutes < 30) return colors.normal;
    if (minutes < 60) return colors.warning;
    return colors.critical;
  }

  static String _formatTime(DateTime time) {
    return formatTime12h(time);
  }
}
