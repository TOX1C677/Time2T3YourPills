import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/services/app_services.dart';
import '../../app/theme/app_screen_layout.dart';
import '../../app/widgets/destructive_confirm_dialog.dart';
import '../../core/errors/user_error_ru.dart';
import '../auth/auth_session.dart';
import '../caregiver/caregiver_scope.dart';
import '../medications/medications_controller.dart';
import '../../core/models/patient_profile.dart';
import 'patient_controller.dart';
import 'ui_preferences_controller.dart';

/// Временно скрыть пункт «О приложении» в меню (маршрут `/about` и экран не трогаем).
const bool _kUiShowAboutMenuItem = false;

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

  Future<bool> _confirmLogout() {
    return showDestructiveConfirmDialog(
      context,
      title: 'Выйти из аккаунта?',
      body: 'Потребуется снова войти по почте и паролю.',
      confirmLabel: 'Выйти',
    );
  }

  Future<bool> _confirmDeleteAccount() {
    return showDestructiveConfirmDialog(
      context,
      title: 'Удалить аккаунт?',
      body: 'Профиль, приёмы и привязки будут удалены без восстановления.',
      confirmLabel: 'Удалить',
    );
  }

  Future<void> _deleteAccount() async {
    if (!await _confirmDeleteAccount()) return;
    if (!mounted) return;
    try {
      await context.read<AuthSession>().deleteAccount();
      if (!mounted) return;
      context.read<CaregiverScope>().clear();
      await context.read<AppServices>().clearUserBoundLocalCache();
      if (!mounted) return;
      GoRouter.of(context).go('/login');
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(dioErrorRu(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userErrorRu(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<PatientController>();
    final uiPrefs = context.watch<UiPreferencesController>();
    final auth = context.watch<AuthSession>();
    final theme = Theme.of(context);
    final layout = context.layout;

    final appBarTitleStyle = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          auth.role == 'caregiver' ? 'Профиль опекуна' : 'Профиль пациента',
          style: auth.role == 'caregiver'
              ? appBarTitleStyle
              : appBarTitleStyle?.copyWith(
                  fontSize: (appBarTitleStyle.fontSize ?? 22) * 0.8,
                ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Ещё',
            onSelected: (value) async {
              if (value == 'alerts') {
                if (!mounted) return;
                context.push('/caregiver-alerts');
              }
              if (_kUiShowAboutMenuItem && value == 'about') {
                if (!mounted) return;
                context.push('/about');
              }
              if (value == 'logout') {
                if (!mounted) return;
                final router = GoRouter.of(context);
                final authS = context.read<AuthSession>();
                final cg = context.read<CaregiverScope>();
                final app = context.read<AppServices>();
                if (!await _confirmLogout()) return;
                if (!mounted) return;
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
              if (_kUiShowAboutMenuItem)
                const PopupMenuItem(value: 'about', child: Text('О приложении')),
              const PopupMenuItem(value: 'logout', child: Text('Выйти')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(layout.spaceM),
        children: [
          if (auth.isAuthenticated && auth.role == 'patient') ...[
            FilledButton.tonalIcon(
              onPressed: _showInviteCodeDialog,
              icon: const Icon(Icons.link),
              label: const Text('Добавить лечащего врача или родственника'),
            ),
            SizedBox(height: layout.spaceM),
          ],
          if (auth.isAuthenticated && auth.role == 'caregiver') ...[
            FilledButton.tonalIcon(
              onPressed: _showLinkPatientDialog,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Добавить пациента по коду'),
            ),
            SizedBox(height: layout.spaceM),
          ],
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder()),
          ),
          SizedBox(height: layout.spaceM),
          TextField(
            controller: _surname,
            decoration: const InputDecoration(
              labelText: 'Фамилия (необязательно)',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: layout.spaceXl),
          FilledButton(onPressed: _save, child: const Text('Сохранить')),
          SizedBox(height: layout.spaceXl),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Сделать весь шрифт жирным', style: theme.textTheme.titleSmall),
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
          SizedBox(height: layout.spaceXl * 2),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          SizedBox(height: layout.spaceM),
          OutlinedButton(
            onPressed: auth.isAuthenticated ? _deleteAccount : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(color: theme.colorScheme.error),
              minimumSize: Size(double.infinity, layout.primaryButtonHeight * 0.55),
            ),
            child: Text('Удалить аккаунт', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
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
