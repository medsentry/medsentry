import 'package:flutter/material.dart'
    show BuildContext, Icons, Navigator, ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shad;

import '../models/patient.dart';
import '../providers/providers.dart';

/// Modern keyboard-first Command Palette (Ctrl+K) for MedSentry RHU.
/// Enables rapid clinical navigation, patient lookups, and operational actions.
Future<void> showMedsentryCommandPalette(
  BuildContext context,
  WidgetRef ref,
) async {
  final user = ref.read(currentUserProvider);

  await shad.showCommandDialog<void>(
    context: context,
    constraints: const shad.BoxConstraints(maxWidth: 580, maxHeight: 420),
    builder: (ctx, query) async* {
      final cleanQuery = (query ?? '').trim().toLowerCase();

      final List<shad.Widget> items = [];

      // 1. Matched or Top Clinical Patients
      if (cleanQuery.isNotEmpty && user?.canAccessPatientRecords == true) {
        final allPatientsAsync = ref.read(patientsProvider);
        final patients = allPatientsAsync.valueOrNull ?? <Patient>[];
        final matchedPatients = patients.where((p) {
          final nameMatch = p.fullName.toLowerCase().contains(cleanQuery);
          final idMatch = p.id.toLowerCase().contains(cleanQuery);
          final barangayMatch =
              (p.barangay ?? '').toLowerCase().contains(cleanQuery);
          final contactMatch = (p.contactNumber ?? '').contains(cleanQuery);
          return nameMatch || idMatch || barangayMatch || contactMatch;
        }).take(5).toList();

        if (matchedPatients.isNotEmpty) {
          items.add(
            shad.CommandCategory(
              title: const shad.Text('PATIENTS'),
              children: matchedPatients.map((patient) {
                final genderChar = (patient.gender != null &&
                        patient.gender!.isNotEmpty)
                    ? patient.gender![0].toUpperCase()
                    : 'U';
                final ageLabel = patient.age != null ? '${patient.age}y' : '';
                final subtitle = [genderChar, ageLabel].where((s) => s.isNotEmpty).join(', ');

                return shad.CommandItem(
                  leading: const shad.Icon(Icons.person_outline, size: 18),
                  title: shad.Text('${patient.fullName} ($subtitle)'),
                  trailing: shad.Text(patient.barangay ?? 'No Barangay'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.push('/patients/${patient.id}');
                  },
                );
              }).toList(),
            ),
          );
        }
      }

      // 2. Navigation items
      final navPages = [
        (
          label: 'Dashboard Overview',
          path: '/dashboard',
          icon: Icons.dashboard_outlined,
          allowed: true,
        ),
        (
          label: 'Patients Directory',
          path: '/patients',
          icon: Icons.people_outline,
          allowed: user?.canAccessPatientRecords == true,
        ),
        (
          label: 'Clinical Documents & Records',
          path: '/documents',
          icon: Icons.folder_outlined,
          allowed: user?.canManageDocuments == true,
        ),
        (
          label: 'Medical Certificates Issuance',
          path: '/certificates',
          icon: Icons.description_outlined,
          allowed: user?.canConsult == true || user?.isAdmin == true,
        ),
        (
          label: 'Reports & Analytics',
          path: '/reports',
          icon: Icons.assessment_outlined,
          allowed: user?.canGenerateReports == true,
        ),
        (
          label: 'Cloud & LAN Sync',
          path: '/sync',
          icon: Icons.cloud_sync_outlined,
          allowed: user?.canManageSystemData == true,
        ),
        (
          label: 'Audit Logs & Compliance',
          path: '/audit-logs',
          icon: Icons.history_outlined,
          allowed: user?.canViewAuditLogs == true,
        ),
        (
          label: 'Settings & Administration',
          path: '/settings',
          icon: Icons.settings_outlined,
          allowed: true,
        ),
        (
          label: 'My User Profile',
          path: '/profile',
          icon: Icons.account_circle_outlined,
          allowed: true,
        ),
      ];

      final filteredNav = navPages.where((p) {
        if (!p.allowed) return false;
        if (cleanQuery.isEmpty) return true;
        return p.label.toLowerCase().contains(cleanQuery) ||
            p.path.toLowerCase().contains(cleanQuery);
      }).toList();

      if (filteredNav.isNotEmpty) {
        items.add(
          shad.CommandCategory(
            title: const shad.Text('NAVIGATION'),
            children: filteredNav.map((page) {
              return shad.CommandItem(
                leading: shad.Icon(page.icon, size: 18),
                title: shad.Text(page.label),
                trailing: shad.Text(page.path),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.go(page.path);
                },
              );
            }).toList(),
          ),
        );
      }

      // 3. Quick Actions
      final actions = [
        if (user?.canRegisterPatients == true)
          (
            title: 'New Patient Registration',
            subtitle: 'Open registration form',
            icon: Icons.person_add_outlined,
            execute: () {
              Navigator.of(ctx).pop();
              context.go('/patients');
            },
          ),
        (
          title: 'Switch Theme (Dark / Light)',
          subtitle: 'Toggle theme display',
          icon: Icons.brightness_6_outlined,
          execute: () {
            Navigator.of(ctx).pop();
            final currentMode = ref.read(themeModeProvider);
            ref
                .read(themeModeProvider.notifier)
                .setThemeMode(
                  currentMode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                );
          },
        ),
      ];

      final filteredActions = actions.where((a) {
        if (cleanQuery.isEmpty) return true;
        return a.title.toLowerCase().contains(cleanQuery) ||
            a.subtitle.toLowerCase().contains(cleanQuery);
      }).toList();

      if (filteredActions.isNotEmpty) {
        items.add(
          shad.CommandCategory(
            title: const shad.Text('ACTIONS'),
            children: filteredActions.map((action) {
              return shad.CommandItem(
                leading: shad.Icon(action.icon, size: 18),
                title: shad.Text(action.title),
                trailing: shad.Text(action.subtitle),
                onTap: action.execute,
              );
            }).toList(),
          ),
        );
      }

      yield items;
    },
  );
}
