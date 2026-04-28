import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_screen_layout.dart';
import '../../core/models/reminder_mode.dart';
import '../auth/auth_session.dart';
import '../caregiver/caregiver_scope.dart';
import 'medications_controller.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final meds = context.watch<MedicationsController>();
    final auth = context.watch<AuthSession>();
    final cg = context.watch<CaregiverScope>();
    final theme = Theme.of(context);
    final bottomFabPad = layout.bottomFabClearance(MediaQuery.viewPaddingOf(context).bottom);

    final caregiverNoPatients =
        auth.isAuthenticated && auth.role == 'caregiver' && cg.patients.isEmpty;

    final showPatientPicker =
        auth.isAuthenticated && auth.role == 'caregiver' && cg.patients.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        // Без слова «Таблетки»: для опекуна вся ширина под выбор пациента (имя + фамилия).
        titleSpacing: showPatientPicker ? 0 : null,
        centerTitle: false,
        title: showPatientPicker
            ? Padding(
                padding: EdgeInsetsDirectional.only(start: layout.spaceM, end: layout.spaceS),
                child: DropdownButton<String>(
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  value: cg.selectedPatientUserId != null &&
                          cg.patients.any((p) => p.patientUserId == cg.selectedPatientUserId)
                      ? cg.selectedPatientUserId
                      : cg.patients.first.patientUserId,
                  selectedItemBuilder: (context) => [
                    for (final p in cg.patients)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          p.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
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
              )
            : const SizedBox.shrink(),
      ),
      body: caregiverNoPatients
          ? Center(
              child: Padding(
                padding: EdgeInsets.fromLTRB(layout.spaceM, layout.spaceM, layout.spaceM, bottomFabPad),
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
                padding: EdgeInsets.fromLTRB(layout.spaceM, layout.spaceM, layout.spaceM, bottomFabPad),
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
                  margin: EdgeInsets.symmetric(vertical: layout.spaceS),
                ),
              ),
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(0, layout.spaceM, 0, bottomFabPad),
                itemCount: meds.items.length,
                separatorBuilder: (context, _) => SizedBox(height: layout.spaceS),
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
                        padding: EdgeInsets.symmetric(horizontal: layout.spaceL),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(layout.cardRadius),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: theme.colorScheme.onError,
                          size: layout.shortestSide * 0.103,
                        ),
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      if (direction != DismissDirection.endToStart) return false;
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) {
                          final scheme = Theme.of(ctx).colorScheme;
                          final dialogTheme = Theme.of(ctx).textTheme;
                          return AlertDialog(
                            // Чуть шире окно диалога → шире блоки кнопок (по умолчанию ~40 dp с каждой стороны).
                            insetPadding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
                            title: Text(
                              'Удалить препарат?',
                              style: dialogTheme.titleLarge?.copyWith(
                                fontSize: 31,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            content: Text(
                              '«${m.name}» будет удалён из списка.',
                              style: dialogTheme.bodyLarge?.copyWith(
                                fontSize: 26,
                                height: 1.62,
                              ),
                            ),
                            actions: [
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: scheme.secondaryContainer,
                                        foregroundColor: scheme.onSecondaryContainer,
                                        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 17),
                                        minimumSize: const Size(0, 84),
                                        textStyle: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: const Text('Отмена'),
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: scheme.error,
                                        foregroundColor: scheme.onError,
                                        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 17),
                                        minimumSize: const Size(0, 84),
                                        textStyle: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: const Text('Удалить'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      );
                      return ok ?? false;
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
                          padding: EdgeInsets.all(layout.spaceM),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(m.name, style: theme.textTheme.titleLarge),
                              SizedBox(height: layout.spaceXs),
                              Text('Доза: ${m.dosage}', style: theme.textTheme.bodyLarge),
                              SizedBox(height: layout.spaceXs),
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
          layout.spaceM,
          0,
          layout.spaceM,
          layout.spaceM + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: SizedBox(
          width: layout.wideButtonWidth(),
          height: layout.minTouch + layout.spaceS,
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
                Icon(Icons.add, size: layout.shortestSide * 0.113),
                SizedBox(width: layout.spaceM),
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
