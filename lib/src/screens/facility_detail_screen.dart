import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/clinic.dart';
import '../providers/providers.dart';
import '../widgets/empty_state.dart';
import '../widgets/layout/responsive_layout.dart';
import '../widgets/loading_state.dart';
import '../widgets/screen_kit.dart';
import '../widgets/status_badge.dart';
import 'patients_screen.dart';
import 'settings_screen.dart';
import 'staff_screen.dart';

/// One facility's staff and patients, with full management, for the Super
/// Admin. Opened from a card on the Rural Health Units page.
class FacilityDetailScreen extends ConsumerStatefulWidget {
  const FacilityDetailScreen({super.key, required this.clinicId});

  final String clinicId;

  @override
  ConsumerState<FacilityDetailScreen> createState() =>
      _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends ConsumerState<FacilityDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clinicsAsync = ref.watch(clinicsProvider);
    final clinics = clinicsAsync.valueOrNull;
    if (clinics == null) {
      return clinicsAsync.hasError
          ? AppErrorState(
              title: 'Facility could not be loaded',
              error: clinicsAsync.error!,
              onRetry: () => ref.invalidate(clinicsProvider),
            )
          : const LoadingState();
    }

    Clinic? clinic;
    for (final candidate in clinics) {
      if (candidate.id == widget.clinicId) clinic = candidate;
    }
    if (clinic == null) {
      return EmptyState(
        icon: Icons.domain_disabled_outlined,
        title: 'Facility not found',
        message: 'It may have been deleted, or it has not synced yet.',
        action: FilledButton.icon(
          onPressed: () => context.go('/rhus'),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Rural Health Units'),
        ),
      );
    }

    final facilityId = clinic.id;
    final staff = (ref.watch(usersProvider).valueOrNull ?? const [])
        .where((user) => user.clinicId == facilityId)
        .toList();
    final staffCount = staff.length;
    final activeStaff = staff.where((user) => user.isActive).length;
    final patients = (ref.watch(patientsProvider).valueOrNull ?? const [])
        .where((patient) => patient.clinicId == facilityId)
        .toList();
    final patientCount = patients.length;
    final now = DateTime.now();
    final newThisMonth = patients.where((patient) {
      final created = patient.createdAt?.toLocal();
      return created != null &&
          created.year == now.year &&
          created.month == now.month;
    }).length;
    final documentCount = (ref.watch(documentsProvider).valueOrNull ?? const [])
        .where((document) => document.clinicId == facilityId)
        .length;
    final certificateCount =
        (ref.watch(issuedCertificatesProvider).valueOrNull ?? const [])
            .where((certificate) => certificate.clinicId == facilityId)
            .length;

    return ResponsiveContentContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.go('/rhus'),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Rural Health Units'),
            ),
          ),
          ScreenHeader(
            icon: Icons.local_hospital_outlined,
            title: clinic.name,
            subtitle: [
              clinic.code,
              if (clinic.address?.isNotEmpty == true) clinic.address!,
            ].join(' · '),
            actions: [
              if (clinic.isActive)
                StatusBadge.active(text: 'Active', showDot: true)
              else
                StatusBadge.inactive(text: 'Inactive', showDot: true),
            ],
          ),
          const SizedBox(height: 10),
          // Compact summary: one or two lines, so the tabs keep their room
          // on phones.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryChip(
                icon: Icons.people_outline,
                label: _count(patientCount, 'patient'),
                detail: '+$newThisMonth this month',
              ),
              _SummaryChip(
                icon: Icons.badge_outlined,
                label: '$activeStaff active staff',
                detail: staffCount > activeStaff
                    ? '${staffCount - activeStaff} inactive'
                    : null,
              ),
              _SummaryChip(
                icon: Icons.folder_outlined,
                label: _count(documentCount, 'document'),
              ),
              _SummaryChip(
                icon: Icons.verified_outlined,
                label: _count(certificateCount, 'certificate'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(
                icon: const Icon(Icons.badge_outlined, size: 18),
                text: 'Staff ($staffCount)',
              ),
              Tab(
                icon: const Icon(Icons.people_outline, size: 18),
                text: 'Patients ($patientCount)',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                StaffManagementPanel(
                  embedded: true,
                  lockedClinicId: clinic.id,
                  onAddUser: () => StaffActions.showForm(
                    context,
                    ref,
                    initialClinicId: widget.clinicId,
                  ),
                  onEditUser: (user) =>
                      StaffActions.showForm(context, ref, existingUser: user),
                  onDeactivateUser: (user) =>
                      StaffActions.confirmDeactivate(context, ref, user),
                  onDeleteUser: (user) =>
                      StaffActions.confirmDelete(context, ref, user),
                ),
                PatientsScreen(clinicId: clinic.id),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label, this.detail});

  final IconData icon;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final t = ScreenTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.raised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: t.muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.text,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: 6),
            Text(detail!, style: TextStyle(fontSize: 12, color: t.muted)),
          ],
        ],
      ),
    );
  }
}

String _count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';
