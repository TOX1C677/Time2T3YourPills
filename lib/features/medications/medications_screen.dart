import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_sizes.dart';
import '../../core/models/reminder_mode.dart';
import '../auth/auth_session.dart';
import '../caregiver/caregiver_scope.dart';
import 'medications_controller.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final meds = context.watch<MedicationsController>();
    final auth = context.watch<AuthSession>();
    final cg = context.watch<CaregiverScope>();
    final theme = Theme.of(context);
    final bottomFabPad = 128.0 + MediaQuery.viewPaddingOf(context).bottom;

    final caregiverNoPatients =
        auth.isAuthenticated && auth.role == 'caregiver' && cg.patients.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Таблетки'),
        actions: [
          if (auth.isAuthenticated && auth.role == 'caregiver' && cg.patients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: cg.selectedPatientUserId != null &&
                            cg.patients.any((p) => p.patientUserId == cg.selectedPatientUserId)
                        ? cg.selectedPatientUserId
                        : cg.patients.first.patientUserId,
                    items: [
                      for (final p in cg.patients)
                        DropdownMenuItem<String>(
                          value: p.patientUserId,
                          child: Text(p.label, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (id) async {
                      if (id == null) return;
                      context.read<CaregiverScope>().selectPatient(id);
                      await context.read<MedicationsController>().refreshFromServer();
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
      body: caregiverNoPatients
          ? Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(AppSizes.spaceM, AppSizes.spaceM, AppSizes.spaceM, bottomFabPad),
                child: Text(
                  'Нет привязанных пациентов. В профиле нажмите «Добавить пациента по коду».',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : meds.items.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(AppSizes.spaceM, AppSizes.spaceM, AppSizes.spaceM, bottomFabPad),
                child: Text(
                  'Пока нет препаратов. Добавьте первый.',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Theme(
              data: theme.copyWith(
                cardTheme: theme.cardTheme.copyWith(
                  margin: const EdgeInsets.symmetric(horizontal: 0, vertical: AppSizes.spaceS),
                ),
              ),
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(0, AppSizes.spaceM, 0, bottomFabPad),
                itemCount: meds.items.length,
                separatorBuilder: (context, _) => const SizedBox(height: AppSizes.spaceS),
                itemBuilder: (context, index) {
                  final m = meds.items[index];
                  final modeLabel = m.reminderMode == ReminderMode.fixedInterval
                      ? 'Равномерный интервал'
                      : 'По графику';
                  return Dismissible(
                    key: ValueKey<String>(m.id),
                    direction: DismissDirection.endToStart,
                    background: SizedBox(
                      width: double.infinity,
                      child: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceL),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                        ),
                        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError, size: 40),
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction != DismissDirection.endToStart) return false;
                      return true;
                    },
                    onDismissed: (_) async {
                      await context.read<MedicationsController>().removeById(m.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Удалено: ${m.name}')),
                      );
                    },
                    child: SizedBox(
                      width: double.infinity,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.spaceM),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(m.name, style: theme.textTheme.titleLarge),
                              const SizedBox(height: AppSizes.spaceXs),
                              Text('Доза: ${m.dosage}', style: theme.textTheme.bodyLarge),
                              const SizedBox(height: AppSizes.spaceXs),
                              Text(modeLabel, style: theme.textTheme.bodyMedium),
                              if (m.reminderMode == ReminderMode.fixedInterval && m.intervalMinutes != null)
                                Text('Каждые ${m.intervalMinutes} мин.', style: theme.textTheme.bodyMedium),
                              if (m.reminderMode == ReminderMode.scheduledSlots && m.slotTimes.isNotEmpty)
                                Text('Слоты: ${m.slotTimes.join(', ')}', style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: caregiverNoPatients
          ? null
          : Padding(
        padding: EdgeInsets.fromLTRB(
          AppSizes.spaceM,
          0,
          AppSizes.spaceM,
          AppSizes.spaceM + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width - AppSizes.spaceM * 2,
          height: 96,
          child: FilledButton(
            onPressed: () async {
              if (auth.isAuthenticated &&
                  auth.role == 'caregiver' &&
                  cg.selectedPatientUserId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Сначала выберите пациента в списке сверху')),
                );
                return;
              }
              await context.push('/medications/add');
              if (!context.mounted) return;
              await context.read<MedicationsController>().load();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 44),
                const SizedBox(width: AppSizes.spaceM),
                Text(
                  'Добавить',
                  style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
