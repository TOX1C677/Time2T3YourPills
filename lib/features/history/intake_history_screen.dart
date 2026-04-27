import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_sizes.dart';
import '../../core/errors/user_error_ru.dart';
import '../../core/models/intake_history_item.dart';
import '../auth/auth_session.dart';
import '../caregiver/caregiver_scope.dart';

/// История приёмов: пациент — свои события; опекун — выбранный пациент из [CaregiverScope].
///
/// [embeddedInShell]: вкладка нижнего меню — без кнопки «назад» (см. план §7.2).
class IntakeHistoryScreen extends StatefulWidget {
  const IntakeHistoryScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  State<IntakeHistoryScreen> createState() => _IntakeHistoryScreenState();
}

class _IntakeHistoryScreenState extends State<IntakeHistoryScreen> {
  /// 0 — 7 дней, 1 — 30 дней, 2 — без ограничения по дате.
  int _filterMode = 0;

  int? get _rangeDays => _filterMode == 0 ? 7 : (_filterMode == 1 ? 30 : null);
  List<IntakeHistoryItem> _items = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthSession>();
    final cg = context.watch<CaregiverScope>();
    final theme = Theme.of(context);

    String subtitle;
    if (auth.role == 'caregiver') {
      final sel = cg.selectedPatientUserId;
      String? label;
      for (final p in cg.patients) {
        if (p.patientUserId == sel) {
          label = p.label;
          break;
        }
      }
      subtitle = label != null && label.isNotEmpty ? 'Пациент: $label' : 'Выберите пациента на вкладке «Таблетки»';
    } else {
      subtitle = 'Ваши подтверждённые приёмы с телефона';
    }

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
          padding: const EdgeInsets.all(AppSizes.spaceM),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
          Text(subtitle, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSizes.spaceM),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, label: Text('7 дней')),
              ButtonSegment<int>(value: 1, label: Text('30 дней')),
              ButtonSegment<int>(value: 2, label: Text('Всё')),
            ],
            selected: {_filterMode},
            onSelectionChanged: (s) {
              setState(() => _filterMode = s.first);
              _load();
            },
          ),
          const SizedBox(height: AppSizes.spaceL),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          if (_error != null) ...[
            Text(_error!, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error)),
            const SizedBox(height: AppSizes.spaceM),
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
                margin: const EdgeInsets.only(bottom: AppSizes.spaceS),
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
