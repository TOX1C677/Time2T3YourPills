import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/services/app_services.dart';
import '../../app/theme/app_sizes.dart';
import '../caregiver/caregiver_scope.dart';
import '../medications/medications_controller.dart';
import '../profile/patient_controller.dart';
import 'auth_session.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  String _role = 'patient';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final caregiver = context.read<CaregiverScope>();
    final app = context.read<AppServices>();
    final meds = context.read<MedicationsController>();
    final pat = context.read<PatientController>();
    try {
      await context.read<AuthSession>().register(
            email: _email.text.trim(),
            password: _password.text,
            displayName: _name.text.trim(),
            role: _role,
          );
      if (!mounted) return;
      await caregiver.refreshFromApi();
      if (!mounted) return;
      try {
        await app.syncRemoteNow();
      } catch (_) {}
      if (!mounted) return;
      await meds.load();
      if (!mounted) return;
      await pat.load();
      if (!mounted) return;
      context.go('/timer');
    } on DioException catch (e) {
      final msg = e.response?.data;
      setState(() {
        _error = msg is Map && msg['detail'] != null ? '${msg['detail']}' : 'Ошибка регистрации';
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.spaceM),
        children: [
          Text(
            'Выберите роль: пациент — таймер и свои таблетки; врач или родственник — управление таблетками привязанных пациентов.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSizes.spaceL),
          if (_error != null) ...[
            Text(_error!, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error)),
            const SizedBox(height: AppSizes.spaceM),
          ],
          Text('Роль', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSizes.spaceS),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'patient', label: Text('Пациент'), icon: Icon(Icons.person)),
              ButtonSegment<String>(
                value: 'caregiver',
                label: Text('Врач / родственник'),
                icon: Icon(Icons.medical_services_outlined),
              ),
            ],
            selected: {_role},
            onSelectionChanged: (s) {
              if (_loading) return;
              setState(() => _role = s.first);
            },
          ),
          const SizedBox(height: AppSizes.spaceM),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Как вас называть', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSizes.spaceM),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Эл. почта', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSizes.spaceM),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Пароль (не короче 6 символов)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: AppSizes.spaceXl),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading ? const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Зарегистрироваться'),
          ),
          const SizedBox(height: AppSizes.spaceM),
          OutlinedButton(
            onPressed: _loading ? null : () => context.pop(),
            child: const Text('Уже есть аккаунт — войти'),
          ),
        ],
      ),
    );
  }
}
