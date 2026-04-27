import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_sizes.dart';
import '../auth/auth_session.dart';
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
  final _middle = TextEditingController();

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
        _middle.text = p.middleName;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _middle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final middle = _middle.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Имя не может быть пустым')),
      );
      return;
    }
    await context.read<PatientController>().save(
          PatientProfile(name: name, middleName: middle),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено локально')));
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
      final d = e.response?.data;
      final msg = d is Map ? '${d['detail'] ?? e.message}' : '${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _showLinkPatientDialog() async {
    final tokenCtrl = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
        title: const Text('Добавить пациента'),
        content: TextField(
          controller: tokenCtrl,
          decoration: const InputDecoration(
            labelText: 'Код от пациента',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () async {
              try {
                await context.read<AuthSession>().linkPatientByToken(tokenCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пациент привязан')));
                }
              } on DioException catch (e) {
                final d = e.response?.data;
                final msg = d is Map ? '${d['detail'] ?? e.message}' : '${e.message}';
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
                }
              }
            },
            child: const Text('Привязать'),
          ),
        ],
      ),
    );
    } finally {
      tokenCtrl.dispose();
    }
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
              if (value == 'about') context.push('/about');
              if (value == 'logout') {
                await context.read<AuthSession>().logout();
                if (context.mounted) context.go('/login');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'about', child: Text('О приложении')),
              PopupMenuItem(value: 'logout', child: Text('Выйти')),
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Сделать весь шрифт жирным', style: theme.textTheme.titleSmall),
            subtitle: Text('Крупнее начертание по всему приложению', style: theme.textTheme.bodyMedium),
            value: uiPrefs.boldFonts,
            onChanged: (v) => uiPrefs.setBoldFonts(v),
          ),
          const SizedBox(height: AppSizes.spaceL),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSizes.spaceM),
          TextField(
            controller: _middle,
            decoration: const InputDecoration(labelText: 'Отчество / второе имя', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSizes.spaceXl),
          FilledButton(onPressed: _save, child: const Text('Сохранить')),
        ],
      ),
    );
  }
}
