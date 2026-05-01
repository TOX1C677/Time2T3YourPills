import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_screen_layout.dart';
import '../../core/errors/user_error_ru.dart';
import '../../core/models/intake_history_item.dart';
import '../auth/auth_session.dart';
import '../caregiver/caregiver_scope.dart';

/// История приёмов: пациент - свои события; опекун - выбранный пациент из [CaregiverScope].
///
/// [embeddedInShell]: вкладка нижнего меню - без кнопки «назад» (см. план §7.2).
class IntakeHistoryScreen extends StatefulWidget {
  const IntakeHistoryScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  State<IntakeHistoryScreen> createState() => _IntakeHistoryScreenState();
}

class _IntakeHistoryScreenState extends State<IntakeHistoryScreen> {
  /// 0 - 7 дней, 1 - 30 дней, 2 - без ограничения по дате.
  int _filterMode = 0;

  int? get _rangeDays => _filterMode == 0 ? 7 : (_filterMode == 1 ? 30 : null);
  List<IntakeHistoryItem> _items = [];
  String? _error;
  bool _loading = true;

  CaregiverScope? _cgScopeListener;
  String? _lastCaregiverPatientIdForReload;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthSession>();
      if (auth.role == 'caregiver') {
        final cg = context.read<CaregiverScope>();
        if (cg.selectedPatientUserId == null && cg.patients.isNotEmpty) {
          cg.selectPatient(cg.patients.first.patientUserId);
        }
        _cgScopeListener = cg;
        _lastCaregiverPatientIdForReload = cg.selectedPatientUserId;
        cg.addListener(_onCaregiverScopePatientChanged);
      }
      _load();
    });
  }

  @override
  void dispose() {
    _cgScopeListener?.removeListener(_onCaregiverScopePatientChanged);
    super.dispose();
  }

  void _onCaregiverScopePatientChanged() {
    if (!mounted || _cgScopeListener == null) return;
    final auth = context.read<AuthSession>();
    if (auth.role != 'caregiver') return;
    final pid = _cgScopeListener!.selectedPatientUserId;
    if (pid == _lastCaregiverPatientIdForReload) return;
    _lastCaregiverPatientIdForReload = pid;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthSession>();
    final cg = context.read<CaregiverScope>();
    try {
      final qp = <String, dynamic>{};
      if (_rangeDays != null) {
        final to = DateTime.now().toUtc();
        final from = to.subtract(Duration(days: _rangeDays!));
        qp['from'] = from.toIso8601String();
        qp['to'] = to.toIso8601String();
      }
      List<dynamic> raw;
      if (auth.role == 'patient') {
        final res = await auth.dio.get<List<dynamic>>(
          '/v1/patients/me/intake-events',
          queryParameters: qp.isEmpty ? null : qp,
        );
        raw = res.data ?? [];
      } else if (auth.role == 'caregiver') {
        final pid = cg.selectedPatientUserId;
        if (pid == null || pid.isEmpty) {
          if (mounted) {
            setState(() {
              _items = [];
              _loading = false;
            });
          }
          return;
        }
        final res = await auth.dio.get<List<dynamic>>(
          '/v1/caregiver/patients/$pid/intake-events',
          queryParameters: qp.isEmpty ? null : qp,
        );
        raw = res.data ?? [];
      } else {
        raw = [];
      }
      final list = raw.map((e) => IntakeHistoryItem.fromApiMap(Map<String, dynamic>.from(e as Map))).toList();
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _error = dioErrorRu(e);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = userErrorRu(e);
          _loading = false;
        });
      }
    }
  }

  String _fmtDt(DateTime t) {
    final d = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  void _setFilterMode(int next) {
    if (_filterMode == next) return;
    setState(() => _filterMode = next);
    _load();
  }

  /// Три равные колонки + [FittedBox], без переноса «7 дней» / «30 дней» ([SegmentedButton] на узком экране ломает строки).
  Widget _buildRangePicker({
    required ThemeData theme,
    required AppScreenLayout layout,
    required TextStyle segmentStyle,
    required double iconSize,
    required double segmentPaddingH,
    required double segmentPaddingV,
    required double iconSlotW,
  }) {
    final scheme = theme.colorScheme;
    final r = layout.cardRadius;

    Widget cell(int value, String label, IconData iconIdle) {
      final selected = _filterMode == value;
      final fg = selected ? scheme.onSecondaryContainer : scheme.onSurface;
      return Material(
        color: selected ? scheme.secondaryContainer : scheme.surface,
        child: InkWell(
          onTap: () => _setFilterMode(value),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: segmentPaddingH, vertical: segmentPaddingV),
            child: Row(
              children: [
                SizedBox(
                  width: iconSlotW,
                  child: Center(
                    child: Icon(
                      selected ? Icons.check : iconIdle,
                      size: iconSize,
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
                        style: segmentStyle.copyWith(color: fg),
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
      label: 'Период истории',
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
              Expanded(child: cell(0, '7 дней', Icons.view_week_outlined)),
              VerticalDivider(width: 1, thickness: 1, color: scheme.outline),
              Expanded(child: cell(1, '30 дней', Icons.calendar_view_month_outlined)),
              VerticalDivider(width: 1, thickness: 1, color: scheme.outline),
              Expanded(child: cell(2, 'Всё', Icons.filter_list_outlined)),
            ],
          ),
        ),
      ),
    );
  }

  /// Выбор пациента для опекуна (тот же паттерн, что на вкладке «Медикаменты»).
  Widget _caregiverPatientPicker({
    required BuildContext context,
    required ThemeData theme,
    required AppScreenLayout layout,
    required CaregiverScope cg,
  }) {
    final value = cg.selectedPatientUserId != null &&
            cg.patients.any((p) => p.patientUserId == cg.selectedPatientUserId)
        ? cg.selectedPatientUserId!
        : cg.patients.first.patientUserId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Пациент',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(height: layout.spaceS * 0.5),
        DropdownButton<String>(
          isExpanded: true,
          underline: const SizedBox.shrink(),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          value: value,
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
          onChanged: (id) {
            if (id == null) return;
            context.read<CaregiverScope>().selectPatient(id);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final auth = context.watch<AuthSession>();
    final cg = context.watch<CaregiverScope>();
    final theme = Theme.of(context);

    final showCaregiverPatientPicker =
        auth.role == 'caregiver' && auth.isAuthenticated && cg.patients.isNotEmpty;

    String? patientSubtitle;
    if (auth.role == 'caregiver' && !showCaregiverPatientPicker) {
      patientSubtitle = cg.patients.isEmpty
          ? 'Нет привязанных пациентов. В профиле нажмите «Добавить пациента по коду».'
          : 'Выберите пациента на вкладке «Медикаменты».';
    } else if (auth.role == 'patient') {
      patientSubtitle = 'Ваши подтверждённые приёмы с телефона';
    }

    final layoutW = layout.screenWidth;
    const rangeLabelFraction = 0.054;
    const rangeIconFraction = 0.062;
    final rangeLabelPx = layoutW * rangeLabelFraction;
    final segmentBase = theme.textTheme.labelLarge ?? theme.textTheme.bodyMedium ?? const TextStyle();
    final rangeSegmentStyle = segmentBase.copyWith(
      fontSize: rangeLabelPx,
      height: 1.12,
      fontWeight: FontWeight.w500,
    );
    final rangeIconSize = layoutW * rangeIconFraction;
    final segmentPaddingH = layoutW * 0.012;
    final segmentPaddingV = layoutW * 0.032;
    final minIconSlotW = rangeIconSize + 4;
    final maxIconSlotW = layoutW * 0.075;
    // На узком экране min > max ломает [num.clamp] → «Invalid argument(s)».
    final iconSlotUpper = maxIconSlotW >= minIconSlotW ? maxIconSlotW : minIconSlotW;
    final iconSlotW = (rangeIconSize * 1.22).clamp(minIconSlotW, iconSlotUpper);

    return Scaffold(
      appBar: AppBar(
        title: const Text('История приёмов'),
        automaticallyImplyLeading: !widget.embeddedInShell,
        leading: widget.embeddedInShell
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.all(layout.spaceM),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
          if (showCaregiverPatientPicker)
            _caregiverPatientPicker(context: context, theme: theme, layout: layout, cg: cg)
          else if (patientSubtitle != null)
            Text(patientSubtitle, style: theme.textTheme.bodyMedium),
          SizedBox(height: layout.spaceM),
          _buildRangePicker(
            theme: theme,
            layout: layout,
            segmentStyle: rangeSegmentStyle,
            iconSize: rangeIconSize,
            segmentPaddingH: segmentPaddingH,
            segmentPaddingV: segmentPaddingV,
            iconSlotW: iconSlotW,
          ),
          SizedBox(height: layout.spaceL),
          if (_loading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(layout.shortestSide * 0.082),
                child: const CircularProgressIndicator(),
              ),
            ),
          if (_error != null) ...[
            Text(_error!, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error)),
            SizedBox(height: layout.spaceM),
            FilledButton.tonal(onPressed: _load, child: const Text('Повторить')),
          ],
          if (!_loading && _error == null && _items.isEmpty)
            Text(
              auth.role == 'caregiver' && (cg.selectedPatientUserId == null || cg.patients.isEmpty)
                  ? 'Нет выбранного пациента или привязок.'
                  : 'Записей за выбранный период нет.',
              style: theme.textTheme.bodyLarge,
            ),
          if (!_loading && _error == null && _items.isNotEmpty)
            ..._items.map(
              (e) => Card(
                margin: EdgeInsets.only(bottom: layout.spaceS),
                child: ListTile(
                  title: Text(e.medicationNameSnapshot.isNotEmpty ? e.medicationNameSnapshot : 'Препарат', style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    'Доза: ${e.dosageSnapshot}\n'
                    'По плану: ${_fmtDt(e.scheduledAt)}\n'
                    'Записано: ${_fmtDt(e.recordedAt)}\n'
                    'Статус: ${e.statusLabelRu}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  isThreeLine: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
