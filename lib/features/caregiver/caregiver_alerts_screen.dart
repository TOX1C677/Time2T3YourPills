import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_screen_layout.dart';
import '../../core/errors/user_error_ru.dart';
import '../../core/models/missed_intake_alert.dart';
import '../auth/auth_session.dart';
import 'caregiver_scope.dart';

/// Список пропусков по привязанным пациентам (только роль опекуна).
class CaregiverAlertsScreen extends StatefulWidget {
  const CaregiverAlertsScreen({super.key});

  @override
  State<CaregiverAlertsScreen> createState() => _CaregiverAlertsScreenState();
}

class _CaregiverAlertsScreenState extends State<CaregiverAlertsScreen> {
  List<MissedIntakeAlert> _items = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final auth = context.read<AuthSession>();
    if (auth.role != 'caregiver') {
      if (mounted) {
        setState(() {
          _items = [];
          _loading = false;
        });
      }
      return;
    }
    try {
      final res = await auth.dio.get<List<dynamic>>('/v1/caregiver/alerts');
      final raw = res.data ?? [];
      final list = raw.map((e) => MissedIntakeAlert.fromApiMap(Map<String, dynamic>.from(e as Map))).toList();
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
        context.read<CaregiverScope>().markAlertsListViewed(list.length);
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

  String _fmt(DateTime d) {
    final local = d.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = context.layout;
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            'Пропуски приёмов',
            maxLines: 1,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 26),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(layout.spaceM),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: theme.textTheme.bodyLarge))
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          'Пока нет зафиксированных пропусков.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => SizedBox(height: layout.spaceS),
                        itemBuilder: (context, i) {
                          final a = _items[i];
                          return Card(
                            child: ListTile(
                              title: Text(a.medicationName, style: theme.textTheme.titleSmall),
                              subtitle: Text(
                                '${a.patientDisplayName}\nОжидалось: ${_fmt(a.dueAt)}\n'
                                'Зафиксировано: ${_fmt(a.detectedAt)}',
                                style: theme.textTheme.bodyMedium,
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
