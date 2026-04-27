import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme/app_sizes.dart';
import '../../core/models/medication.dart';
import '../../core/models/reminder_mode.dart';
import 'medications_controller.dart';

class AddMedicationRouteScreen extends StatefulWidget {
  const AddMedicationRouteScreen({super.key});

  @override
  State<AddMedicationRouteScreen> createState() => _AddMedicationRouteScreenState();
}

class _AddMedicationRouteScreenState extends State<AddMedicationRouteScreen> {
  final _name = TextEditingController();
  final _dosage = TextEditingController();
  final _interval = TextEditingController(text: '60');

  ReminderMode _mode = ReminderMode.fixedInterval;

  /// Времена по графику (после подтверждения с колеса).
  final List<TimeOfDay> _scheduleTimes = [];

  /// Черновик на колесе Cupertino.
  TimeOfDay _draftTime = const TimeOfDay(hour: 8, minute: 0);

  /// Показываем колесо выбора (первый раз — сразу; дальше — по кнопке «Добавить ещё»).
  bool _showSchedulePicker = true;

  /// Чтобы [CupertinoDatePicker] заново подхватывал [initialDateTime] при повторном открытии.
  int _pickerSession = 0;

  DateTime get _draftAsDateTime => DateTime(2024, 1, 1, _draftTime.hour, _draftTime.minute);

  static String _formatHm(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _commitDraftScheduleTime() {
    final duplicate = _scheduleTimes.any((t) => t.hour == _draftTime.hour && t.minute == _draftTime.minute);
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Это время уже добавлено')),
      );
      return;
    }
    setState(() {
      _scheduleTimes.add(_draftTime);
      _scheduleTimes.sort((a, b) => a.hour * 60 + a.minute - b.hour * 60 - b.minute);
      _showSchedulePicker = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _dosage.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final dosage = _dosage.text.trim();
    if (name.isEmpty || dosage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните название и дозу')),
      );
      return;
    }

    int? intervalMinutes;
    List<String> slots = const [];
    if (_mode == ReminderMode.fixedInterval) {
      intervalMinutes = int.tryParse(_interval.text.trim());
      if (intervalMinutes == null || intervalMinutes <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Интервал в минутах должен быть числом > 0')),
        );
        return;
      }
    } else {
      slots = _scheduleTimes.map(_formatHm).toList();
      if (slots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите хотя бы одно время приёма по графику')),
        );
        return;
      }
    }

    final med = Medication(
      id: const Uuid().v4(),
      name: name,
      dosage: dosage,
      reminderMode: _mode,
      intervalMinutes: intervalMinutes,
      slotTimes: slots,
    );

    await context.read<MedicationsController>().upsert(med);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Новый препарат')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.spaceM),
        children: [
          Text(
            'Выберите способ напоминания: равномерный интервал или фиксированные времена.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSizes.spaceL),
          SegmentedButton<ReminderMode>(
            segments: const [
              ButtonSegment(value: ReminderMode.fixedInterval, label: Text('Интервал'), icon: Icon(Icons.schedule)),
              ButtonSegment(value: ReminderMode.scheduledSlots, label: Text('График'), icon: Icon(Icons.event_note)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) {
              setState(() {
                final next = s.first;
                if (_mode == ReminderMode.scheduledSlots && next == ReminderMode.fixedInterval) {
                  _scheduleTimes.clear();
                  _showSchedulePicker = true;
                  _draftTime = const TimeOfDay(hour: 8, minute: 0);
                }
                _mode = next;
                if (_mode == ReminderMode.scheduledSlots && _scheduleTimes.isEmpty) {
                  _showSchedulePicker = true;
                  _draftTime = const TimeOfDay(hour: 8, minute: 0);
                  _pickerSession++;
                }
              });
            },
          ),
          const SizedBox(height: AppSizes.spaceL),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSizes.spaceM),
          TextField(
            controller: _dosage,
            decoration: const InputDecoration(labelText: 'Доза', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSizes.spaceL),
          if (_mode == ReminderMode.fixedInterval) ...[
            TextField(
              controller: _interval,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Интервал (минуты)',
                border: OutlineInputBorder(),
              ),
            ),
          ] else ...[
            Text(
              'Выберите время приёма колесом. После сохранения оно появится в поле ниже — можно добавить несколько времён.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSizes.spaceM),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Выбранные времена',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.spaceS),
                child: _scheduleTimes.isEmpty
                    ? Text(
                        '— пока нет —',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Wrap(
                        spacing: AppSizes.spaceS,
                        runSpacing: AppSizes.spaceS,
                        children: [
                          for (final entry in _scheduleTimes.asMap().entries)
                            InputChip(
                              label: Text(_formatHm(entry.value)),
                              onDeleted: () {
                                final index = entry.key;
                                setState(() {
                                  _scheduleTimes.removeAt(index);
                                  if (_scheduleTimes.isEmpty) {
                                    _showSchedulePicker = true;
                                    _draftTime = const TimeOfDay(hour: 8, minute: 0);
                                    _pickerSession++;
                                  }
                                });
                              },
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: AppSizes.spaceL),
            if (_showSchedulePicker) ...[
              Text('Выбор времени', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppSizes.spaceS),
              SizedBox(
                key: ValueKey<int>(_pickerSession),
                height: 300,
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: theme.brightness,
                    textTheme: CupertinoTextThemeData(
                      dateTimePickerTextStyle: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 34,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    use24hFormat: true,
                    itemExtent: 52,
                    initialDateTime: _draftAsDateTime,
                    onDateTimeChanged: (d) {
                      setState(() {
                        _draftTime = TimeOfDay(hour: d.hour, minute: d.minute);
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.spaceM),
              if (_scheduleTimes.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _showSchedulePicker = false),
                        child: const Text('Отмена'),
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceM),
                    Expanded(
                      child: FilledButton(
                        onPressed: _commitDraftScheduleTime,
                        child: const Text('Сохранить это время'),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _commitDraftScheduleTime,
                    child: const Text('Сохранить это время'),
                  ),
                ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _pickerSession++;
                    _showSchedulePicker = true;
                    final base = _scheduleTimes.isNotEmpty ? _scheduleTimes.last : const TimeOfDay(hour: 8, minute: 0);
                    _draftTime = base;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Добавить ещё время'),
              ),
            ],
          ],
          const SizedBox(height: AppSizes.spaceXl),
          FilledButton(onPressed: _save, child: const Text('Сохранить')),
        ],
      ),
    );
  }
}
