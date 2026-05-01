import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../app/theme/app_screen_layout.dart';
import '../../core/models/medication.dart';
import '../../core/models/reminder_mode.dart';
import 'medications_controller.dart';

class AddMedicationRouteScreen extends StatefulWidget {
  const AddMedicationRouteScreen({super.key, this.editingMedicationId});

  /// Если задан — режим редактирования существующего препарата (тот же `id` при сохранении).
  final String? editingMedicationId;

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

  /// Локальное время первого приёма (интервал и график).
  TimeOfDay _firstIntakeTime = const TimeOfDay(hour: 8, minute: 0);

  /// Для режима редактирования: ждём подгрузку полей из списка.
  bool _editHydrated = true;

  @override
  void initState() {
    super.initState();
    if (widget.editingMedicationId != null) {
      _editHydrated = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _tryLoadForEdit(widget.editingMedicationId!);
      });
    }
  }

  void _tryLoadForEdit(String id) {
    final meds = context.read<MedicationsController>().items;
    Medication? found;
    for (final x in meds) {
      if (x.id == id) {
        found = x;
        break;
      }
    }
    if (!mounted) return;
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Препарат не найден. Обновите список.')),
      );
      context.pop();
      return;
    }
    _applyMedication(found);
    setState(() => _editHydrated = true);
  }

  void _applyMedication(Medication m) {
    _name.text = m.name;
    _dosage.text = m.dosage;
    _mode = m.reminderMode;
    if (m.reminderMode == ReminderMode.fixedInterval) {
      _interval.text = '${m.intervalMinutes ?? 60}';
      _scheduleTimes.clear();
      _showSchedulePicker = true;
    } else {
      _scheduleTimes.clear();
      for (final slot in m.slotTimes) {
        final t = _parseHm(slot);
        if (t != null) {
          _scheduleTimes.add(t);
        }
      }
      _scheduleTimes.sort((a, b) => a.hour * 60 + a.minute - b.hour * 60 - b.minute);
      _showSchedulePicker = _scheduleTimes.isEmpty;
      if (_scheduleTimes.isNotEmpty) {
        _draftTime = _scheduleTimes.last;
      }
    }
    final first = _parseHm(m.firstIntakeHm);
    if (first != null) {
      _firstIntakeTime = first;
    }
  }

  static TimeOfDay? _parseHm(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    final parts = s.trim().split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  DateTime get _draftAsDateTime => DateTime(2024, 1, 1, _draftTime.hour, _draftTime.minute);

  DateTime get _firstIntakeAsDateTime => DateTime(2024, 1, 1, _firstIntakeTime.hour, _firstIntakeTime.minute);

  /// Колесо времени как у графика приёма (Cupertino).
  Widget _buildCupertinoTimePicker({
    Key? key,
    required ThemeData theme,
    required AppScreenLayout layout,
    required DateTime initialDateTime,
    required ValueChanged<DateTime> onChanged,
  }) {
    return SizedBox(
      key: key,
      height: 300,
      child: CupertinoTheme(
        data: CupertinoThemeData(
          brightness: theme.brightness,
          textTheme: CupertinoTextThemeData(
            dateTimePickerTextStyle: GoogleFonts.notoSans(
              color: theme.colorScheme.onSurface,
              fontSize: layout.shortestSide * 0.0872,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.time,
          use24hFormat: true,
          itemExtent: 52,
          initialDateTime: initialDateTime,
          onDateTimeChanged: onChanged,
        ),
      ),
    );
  }

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
      id: widget.editingMedicationId ?? const Uuid().v4(),
      name: name,
      dosage: dosage,
      reminderMode: _mode,
      intervalMinutes: intervalMinutes,
      slotTimes: slots,
      firstIntakeHm: _formatHm(_firstIntakeTime),
    );

    await context.read<MedicationsController>().upsert(med);
    if (mounted) context.pop();
  }

  void _setReminderMode(ReminderMode next) {
    if (_mode == next) return;
    setState(() {
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
  }

  /// Две равные половины + [FittedBox], чтобы «Интервал» не переносился (в отличие от [SegmentedButton]).
  Widget _buildReminderModePicker({
    required ThemeData theme,
    required AppScreenLayout layout,
    required TextStyle modeSegmentStyle,
    required double modeIconSize,
    required double segmentPaddingH,
    required double segmentPaddingV,
    required double modeIconSlotW,
  }) {
    final scheme = theme.colorScheme;
    final r = layout.cardRadius;

    Widget cell(ReminderMode value, String label, IconData iconIdle) {
      final selected = _mode == value;
      final fg = selected ? scheme.onSecondaryContainer : scheme.onSurface;
      return Material(
        color: selected ? scheme.secondaryContainer : scheme.surface,
        child: InkWell(
          onTap: () => _setReminderMode(value),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: segmentPaddingH, vertical: segmentPaddingV),
            child: Row(
              children: [
                SizedBox(
                  width: modeIconSlotW,
                  child: Center(
                    child: Icon(
                      selected ? Icons.check : iconIdle,
                      size: modeIconSize,
                      color: fg,
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: modeSegmentStyle.copyWith(color: fg),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Semantics(
      label: 'Способ напоминания',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: scheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cell(ReminderMode.fixedInterval, 'Интервал', Icons.schedule)),
              VerticalDivider(width: 1, thickness: 1, color: scheme.outline),
              Expanded(child: cell(ReminderMode.scheduledSlots, 'График', Icons.event_note)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = context.layout;
    final layoutW = layout.screenWidth;
    const modeLabelFraction = 0.064; // подписи «Интервал» / «График»
    const modeIconFraction = 0.07;
    final modeLabelPx = layoutW * modeLabelFraction;
    final segmentBase = theme.textTheme.labelLarge ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final modeSegmentStyle = segmentBase.copyWith(
      fontSize: modeLabelPx,
      height: 1.15,
      fontWeight: FontWeight.w500,
    );
    final modeIconSize = layoutW * modeIconFraction;
    final segmentPaddingH = layoutW * 0.018;
    final segmentPaddingV = layoutW * 0.038;
    final minModeIconSlotW = modeIconSize + 6;
    final maxModeIconSlotW = layoutW * 0.09;
    final modeIconSlotUpper = maxModeIconSlotW >= minModeIconSlotW ? maxModeIconSlotW : minModeIconSlotW;
    final modeIconSlotW = (modeIconSize * 1.28).clamp(minModeIconSlotW, modeIconSlotUpper);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingMedicationId != null ? 'Изменить препарат' : 'Новый препарат'),
      ),
      body: !_editHydrated
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: EdgeInsets.all(layout.spaceM),
        children: [
          Text(
            'Выберите способ напоминания: равномерный интервал или фиксированные времена.',
            style: theme.textTheme.bodyMedium,
          ),
          SizedBox(height: layout.spaceL),
          _buildReminderModePicker(
            theme: theme,
            layout: layout,
            modeSegmentStyle: modeSegmentStyle,
            modeIconSize: modeIconSize,
            segmentPaddingH: segmentPaddingH,
            segmentPaddingV: segmentPaddingV,
            modeIconSlotW: modeIconSlotW,
          ),
          SizedBox(height: layout.spaceM),
          Text('Время первого приёма', style: theme.textTheme.titleSmall),
          SizedBox(height: layout.spaceS),
          _buildCupertinoTimePicker(
            theme: theme,
            layout: layout,
            initialDateTime: _firstIntakeAsDateTime,
            onChanged: (d) {
              setState(() {
                _firstIntakeTime = TimeOfDay(hour: d.hour, minute: d.minute);
              });
            },
          ),
          SizedBox(height: layout.spaceL),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Название', border: OutlineInputBorder()),
          ),
          SizedBox(height: layout.spaceM),
          TextField(
            controller: _dosage,
            decoration: const InputDecoration(labelText: 'Доза', border: OutlineInputBorder()),
          ),
          SizedBox(height: layout.spaceL),
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
            SizedBox(height: layout.spaceM),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Выбранные времена',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: layout.spaceS),
                child: _scheduleTimes.isEmpty
                    ? Text(
                        '— пока нет —',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : Wrap(
                        spacing: layout.spaceS,
                        runSpacing: layout.spaceS,
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
            SizedBox(height: layout.spaceL),
            if (_showSchedulePicker) ...[
              Text('Выбор времени', style: theme.textTheme.titleSmall),
              SizedBox(height: layout.spaceS),
              _buildCupertinoTimePicker(
                key: ValueKey<int>(_pickerSession),
                theme: theme,
                layout: layout,
                initialDateTime: _draftAsDateTime,
                onChanged: (d) {
                  setState(() {
                    _draftTime = TimeOfDay(hour: d.hour, minute: d.minute);
                  });
                },
              ),
              SizedBox(height: layout.spaceM),
              if (_scheduleTimes.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(() => _showSchedulePicker = false),
                        child: const Text('Отмена'),
                      ),
                    ),
                    SizedBox(width: layout.spaceM),
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
          SizedBox(height: layout.spaceXl),
          FilledButton(onPressed: _save, child: const Text('Сохранить')),
        ],
      ),
    );
  }
}
