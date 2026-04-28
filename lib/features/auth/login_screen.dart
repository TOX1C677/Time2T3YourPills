import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/services/app_services.dart';
import '../../app/theme/app_screen_layout.dart';
import '../../core/errors/user_error_ru.dart';
import '../caregiver/caregiver_scope.dart';
import '../medications/medications_controller.dart';
import '../profile/patient_controller.dart';
import '../profile/ui_preferences_controller.dart';
import 'auth_session.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
      await context.read<AuthSession>().login(
            email: _email.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      await app.clearUserBoundLocalCache();
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
      await context.read<UiPreferencesController>().load();
      if (!mounted) return;
      context.go('/timer');
    } on DioException catch (e) {
      setState(() => _error = dioErrorRu(e));
    } catch (e) {
      setState(() => _error = userErrorRu(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = context.layout;
    return Scaffold(
      appBar: AppBar(title: const Text('Вход')),
      body: ListView(
        padding: EdgeInsets.all(layout.spaceM),
        children: [
          Text(
            'Войдите под учётной записью.',
            style: theme.textTheme.bodyMedium,
          ),
          SizedBox(height: layout.spaceL),
          if (_error != null) ...[
            Text(_error!, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error)),
            SizedBox(height: layout.spaceM),
          ],
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Эл. почта', border: OutlineInputBorder()),
          ),
          SizedBox(height: layout.spaceM),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Пароль', border: OutlineInputBorder()),
          ),
          SizedBox(height: layout.spaceXl),
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? SizedBox(
                    height: layout.shortestSide * 0.072,
                    width: layout.shortestSide * 0.072,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Войти'),
          ),
          SizedBox(height: layout.spaceM),
          OutlinedButton(
            onPressed: _loading ? null : () => context.push('/register'),
            child: const Text('Регистрация'),
          ),
        ],
      ),
    );
  }
}
