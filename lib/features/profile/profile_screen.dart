import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/services/app_services.dart';
import '../../app/theme/app_sizes.dart';
import '../../core/errors/user_error_ru.dart';
import '../auth/auth_session.dart';
import '../caregiver/caregiver_scope.dart';
import '../medications/medications_controller.dart';
import '../../core/models/patient_profile.dart';
import 'patient_controller.dart';
import 'ui_preferences_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _surname = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;
      final c = context.read<PatientController>();
      await c.load();
      final p = c.profile;
      if (!mounted) return;
      if (p != null) {
        _name.text = p.name;
        _surname.text = p.surname;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final surname = _surname.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Имя не может быть пустым')),
      );
      return;
    }
    await context.read<PatientController>().save(
          PatientProfile(name: name, surname: surname),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено')));
    }
  }

  Future<void> _showInviteCodeDialog() async {
    try {
      final code = await context.read<AuthSession>().fetchInviteCode();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Код для врача или родственника'),
          content: SelectableText(code, style: Theme.of(ctx).textTheme.bodyLarge),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
            FilledButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Код скопирован')));
              },
              child: const Text('Копировать'),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dioErrorRu(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userErrorRu(e))));
    }
  }

  Future<void> _showLinkPatientDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _LinkPatientByCodeDialog(
        parentContext: context,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<PatientController>();
    final uiPrefs = context.watch<UiPreferencesController>();
    final auth = context.watch<AuthSession>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.role == 'caregiver' ? 'Профиль опекуна' : 'Профиль пациента'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Ещё',
            onSelected: (value) async {
              if (value == 'alerts') {
                if (!mounted) return;
                context.push('/caregiver-alerts');
              }
              if (value == 'about') {
                if (!mounted) return;
                context.push('/about');
              }
              if (value == 'logout') {
                final router = GoRouter.of(context);
                final authS = context.read<AuthSession>();
                final cg = context.read<CaregiverScope>();
                final app = context.read<AppServices>();
                await authS.logout();
                cg.clear();
                await app.clearUserBoundLocalCache();
                if (!mounted) return;
                router.go('/login');
              }
            },
            itemBuilder: (context) => [
              if (auth.role == 'caregiver')
                const PopupMenuItem(value: 'alerts', child: Text('Пропуски приёмов')),
              const PopupMenuItem(value: 'about', child: Text('О приложении')),
              const PopupMenuItem(value: 'logout', child: Text('Выйти')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.spaceM),
        children: [
          if (auth.isAuthenticated && auth.role == 'patient') ...[
            FilledButton.tonalIcon(
              onPressed: _showInviteCodeDialog,
              icon: const Icon(Icons.link),
              label: const Text('Добавить лечащего врача или родственника'),
            ),
            const SizedBox(height: AppSizes.spaceM),
          ],
          if (auth.isAuthenticated && auth.role == 'caregiver') ...[
            FilledButton.tonalIcon(
              onPressed: _showLinkPatientDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Добавить пациента по коду'),
            ),
            const SizedBox(height: AppSizes.spaceM),
          ],
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSizes.spaceM),
          TextField(
            controller: _surname,
            decoration: const InputDecoration(
              labelText: 'Фамилия (необязательно)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSizes.spaceXl),
          FilledButton(onPressed: _save, child: const Text('Сохранить')),
          const SizedBox(height: AppSizes.spaceXl),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Сделать весь шрифт жирным', style: theme.textTheme.titleSmall),
            subtitle: Text('Крупнее начертание по всему приложению', style: theme.textTheme.bodyMedium),
            value: uiPrefs.boldFonts,
            onChanged: (v) async {
              final ok = await uiPrefs.setBoldFonts(v);
              if (!context.mounted || ok) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Не удалось сохранить настройку. Проверьте сеть.'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Диалог со своим [TextEditingController], чтобы не dispose до закрытия маршрута.
class _LinkPatientByCodeDialog extends StatefulWidget {
  const _LinkPatientByCodeDialog({required this.parentContext});

  final BuildContext parentContext;

  @override
  State<_LinkPatientByCodeDialog> createState() => _LinkPatientByCodeDialogState();
}

class _LinkPatientByCodeDialogState extends State<_LinkPatientByCodeDialog> {
  final _token = TextEditingController();

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить пациента'),
      content: TextField(
        controller: _token,
        decoration: const InputDecoration(
          labelText: 'Код от пациента',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: () async {
            final auth = widget.parentContext.read<AuthSession>();
            final cg = widget.parentContext.read<CaregiverScope>();
            final app = widget.parentContext.read<AppServices>();
            final meds = widget.parentContext.read<MedicationsController>();
            final messenger = ScaffoldMessenger.of(widget.parentContext);
            try {
              await auth.linkPatientByToken(_token.text);
              if (context.mounted) Navigator.pop(context);
              if (!widget.parentContext.mounted) return;
              await cg.refreshFromApi();
              if (!widget.parentContext.mounted) return;
              try {
                await app.syncRemoteNow();
              } catch (_) {}
              if (!widget.parentContext.mounted) return;
              await meds.load();
              messenger.showSnackBar(const SnackBar(content: Text('Пациент привязан')));
            } on DioException catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dioErrorRu(e))));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userErrorRu(e))));
              }
            }
          },
          child: const Text('Привязать'),
        ),
      ],
    );
  }
}
