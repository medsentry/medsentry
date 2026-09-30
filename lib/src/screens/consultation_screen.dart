import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/patient.dart';
import '../models/queue.dart';
import '../providers/providers.dart';
import '../widgets/loading_state.dart';

class ConsultationScreen extends ConsumerStatefulWidget {
  final String queueId;

  const ConsultationScreen({super.key, required this.queueId});

  @override
  ConsumerState<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends ConsumerState<ConsultationScreen> {
  final _subjectiveController = TextEditingController();
  final _objectiveController = TextEditingController();
  final _assessmentController = TextEditingController();
  final _planController = TextEditingController();
  final _icdSearchController = TextEditingController();

  String _selectedIcd10Code = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _subjectiveController.dispose();
    _objectiveController.dispose();
    _assessmentController.dispose();
    _planController.dispose();
    _icdSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queueItemAsync = ref.watch(queueItemProvider(widget.queueId));

    return queueItemAsync.when(
      data: (queueItem) {
        final patientId = queueItem?.patientId ?? widget.queueId;
        final patientAsync = ref.watch(patientProvider(patientId));

        return patientAsync.when(
          data: (patient) {
            if (patient == null) {
              return const Center(child: Text('Patient not found'));
            }

            return _buildConsultationForm(context, patient, queueItem);
          },
          loading: () => const LoadingState(),
          error: (error, stack) => Center(child: Text('Error: $error')),
        );
      },
      loading: () => const LoadingState(),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildConsultationForm(
    BuildContext context,
    Patient patient,
    QueueItem? queueItem,
  ) {
    final canConsult = ref.watch(currentUserProvider)?.canConsult ?? false;

    return Column(
      children: [
        _buildStickyActionHeader(context, patient, queueItem, canConsult),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PatientSummaryCard(patient: patient, queueItem: queueItem),
                if (!canConsult) ...[
                  const SizedBox(height: 12),
                  const _PermissionBanner(
                    message: 'Only staff can save SOAP consultations.',
                  ),
                ],
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  'Subjective',
                  'Chief complaint, symptoms, history of present illness...',
                  _subjectiveController,
                  Icons.chat_bubble_outline,
                ),
                const SizedBox(height: 12),
                _buildSection(
                  context,
                  'Objective',
                  'Vitals, physical exam findings, observations...',
                  _objectiveController,
                  Icons.visibility_outlined,
                ),
                const SizedBox(height: 12),
                _buildSection(
                  context,
                  'Assessment',
                  'Clinical diagnosis and differential impressions...',
                  _assessmentController,
                  Icons.assignment_turned_in_outlined,
                ),
                const SizedBox(height: 12),
                _buildSection(
                  context,
                  'Plan',
                  'Treatment plan, diagnostics, referrals, follow-up...',
                  _planController,
                  Icons.fact_check_outlined,
                ),
                const SizedBox(height: 12),
                _buildIcd10Selector(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyActionHeader(
    BuildContext context,
    Patient patient,
    QueueItem? queueItem,
    bool canConsult,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
            blurStyle: BlurStyle.outer,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _isLoading ? null : () => context.pop(),
              ),
              const SizedBox(width: 8),
              Text(
                'SOAP Consultation',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () => context.pop(),
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isLoading || !canConsult
                    ? null
                    : () => _saveConsultation(patient, queueItem),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('Save Consultation'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String hint,
    TextEditingController controller,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcd10Selector(BuildContext context) {
    final query = _icdSearchController.text.trim().toLowerCase();
    final codes = _icd10Codes.where((code) {
      if (query.isEmpty) return true;
      return code.code.toLowerCase().contains(query) ||
          code.description.toLowerCase().contains(query);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.manage_search_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'ICD-10 Diagnosis',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _icdSearchController,
              decoration: const InputDecoration(
                hintText: 'Search code or diagnosis',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _selectedIcd10Code.isEmpty
                  ? null
                  : _selectedIcd10Code,
              hint: const Text('Select diagnosis code'),
              items: codes.map((code) {
                return DropdownMenuItem(
                  value: code.code,
                  child: Text('${code.code} - ${code.description}'),
                );
              }).toList(),
              onChanged: (value) {
                final selected = _icd10Codes.firstWhere(
                  (code) => code.code == value,
                  orElse: () => const _Icd10Code('', ''),
                );
                setState(() {
                  _selectedIcd10Code = selected.code;
                });
              },
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConsultation(Patient patient, QueueItem? queueItem) async {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null || !currentUser.canConsult) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only staff can save consultations.')),
      );
      return;
    }

    if (_subjectiveController.text.trim().isEmpty &&
        _objectiveController.text.trim().isEmpty &&
        _assessmentController.text.trim().isEmpty &&
        _planController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one SOAP note field.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final createdBy = currentUser.id;
      final repository = ref.read(consultationRepositoryProvider);

      await repository.createConsultation(
        patientId: patient.id,
        queueId: queueItem?.id,
        subjective: _subjectiveController.text.trim(),
        objective: _objectiveController.text.trim(),
        assessment: _assessmentController.text.trim(),
        plan: _planController.text.trim(),
        icd10Code: _selectedIcd10Code,
        createdBy: createdBy,
      );

      if (queueItem != null) {
        final updatedQueue = queueItem.copyWith(
          status: QueueStatus.completed,
          endTime: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await ref.read(queueRepositoryProvider).updateQueueItem(updatedQueue);
        ref.invalidate(queueProvider);
        ref.invalidate(queueItemProvider(queueItem.id));
        ref.invalidate(patientQueueHistoryProvider(patient.id));
      }

      ref.invalidate(patientConsultationsProvider(patient.id));
      ref.invalidate(patientProvider(patient.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Consultation saved successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving consultation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _PermissionBanner extends StatelessWidget {
  final String message;

  const _PermissionBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientSummaryCard extends StatelessWidget {
  final Patient patient;
  final QueueItem? queueItem;

  const _PatientSummaryCard({required this.patient, required this.queueItem});

  @override
  Widget build(BuildContext context) {
    final queue = queueItem;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              patient.firstName.isNotEmpty ? patient.firstName[0] : '?',
              style: const TextStyle(fontSize: 22, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('PHN: ${patient.philHealthNumber ?? 'N/A'}'),
                  Text(
                    '${patient.age ?? 'N/A'} years old - ${patient.gender?.toUpperCase() ?? 'UNKNOWN'}',
                  ),
                  if (queue != null)
                    Text(
                      'Queue: ${queue.purpose ?? 'General Consultation'} - ${queue.priorityDisplay}',
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Icd10Code {
  final String code;
  final String description;

  const _Icd10Code(this.code, this.description);
}

const _icd10Codes = [
  _Icd10Code('I10', 'Essential hypertension'),
  _Icd10Code('E11.9', 'Type 2 diabetes mellitus without complications'),
  _Icd10Code('J06.9', 'Acute upper respiratory infection, unspecified'),
  _Icd10Code('K29.7', 'Gastritis, unspecified'),
  _Icd10Code('M79.1', 'Myalgia'),
  _Icd10Code('R50.9', 'Fever, unspecified'),
  _Icd10Code('R05', 'Cough'),
  _Icd10Code('A09', 'Infectious gastroenteritis and colitis, unspecified'),
  _Icd10Code('N39.0', 'Urinary tract infection, site not specified'),
  _Icd10Code('Z00.0', 'General medical examination'),
  _Icd10Code('Z34.9', 'Supervision of normal pregnancy, unspecified'),
  _Icd10Code('Z23', 'Encounter for immunization'),
];
