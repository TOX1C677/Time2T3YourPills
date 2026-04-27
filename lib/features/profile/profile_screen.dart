import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_sizes.dart';
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

  @override
  Widget build(BuildContext context) {
    context.watch<PatientController>();
    final uiPrefs = context.watch<UiPreferencesController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль пациента'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Ещё',
            onSelected: (value) {
              if (value == 'about') context.push('/about');
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'about', child: Text('О приложении')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.spaceM),
        children: [
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
