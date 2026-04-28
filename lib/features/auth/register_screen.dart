import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../app/services/app_services.dart';
import '../../app/theme/app_screen_layout.dart';
import '../../core/errors/user_error_ru.dart';
import '../caregiver/caregiver_scope.dart';
import '../medications/medications_controller.dart';
import '../profile/patient_controller.dart';
import '../profile/ui_preferences_controller.dart';
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
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Введите имя');
      return;
    }
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

  /// Две равные половины, фиксированная колонка иконки, своя галочка — без скачков и переносов текста.
  Widget _buildRolePicker({
    required ThemeData theme,
    required AppScreenLayout layout,
    required TextStyle roleSegmentStyle,
    required double roleIconSize,
    required double segmentPaddingH,
    required double segmentPaddingV,
    required double roleIconSlotW,
  }) {
    final scheme = theme.colorScheme;
    final r = layout.buttonRadius;

    Widget cell(String value, String label, IconData iconIdle) {
      final selected = _role == value;
      final fg = selected ? scheme.onSecondaryContainer : scheme.onSurface;
      return Material(
        color: selected ? scheme.secondaryContainer : scheme.surface,
        child: InkWell(
          onTap: _loading ? null : () => setState(() => _role = value),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: segmentPaddingH, vertical: segmentPaddingV),
            child: Row(
              children: [
                SizedBox(
                  width: roleIconSlotW,
                  child: Center(
                    child: Icon(
                      selected ? Icons.check : iconIdle,
                      size: roleIconSize,
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
                        style: roleSegmentStyle.copyWith(color: fg),
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
      label: 'Роль',
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
              Expanded(child: cell('patient', 'Пациент', Icons.person_outline)),
              VerticalDivider(width: 1, thickness: 1, color: scheme.outline),
              Expanded(child: cell('caregiver', 'Опекун', Icons.supervisor_account_outlined)),
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
    // Только доля ширины экрана (логические px), без множителей и clamp.
    const roleHeadingFraction = 0.12; // «Роль»
    const roleSegmentFraction = 0.058; // подписи «Пациент» / «Опекун»
    const roleIconFraction = 0.072; // иконки в переключателе
    final roleHeadingPx = layoutW * roleHeadingFraction;
    final roleSegmentPx = layoutW * roleSegmentFraction;
    final roleHeadingStyle = theme.textTheme.titleSmall?.copyWith(
          fontSize: roleHeadingPx,
          fontWeight: FontWeight.w600,
        ) ??
        GoogleFonts.notoSans(fontSize: roleHeadingPx, fontWeight: FontWeight.w600);
    final segmentBase = theme.textTheme.labelLarge ?? theme.textTheme.bodyMedium ?? GoogleFonts.notoSans();
    final roleSegmentStyle = segmentBase.copyWith(
      fontSize: roleSegmentPx,
      height: 1.15,
      fontWeight: FontWeight.w500,
    );
    final roleIconSize = layoutW * roleIconFraction;
    // Внутри ячейки: умеренные доли, иначе при expanded съедается ширина под текст → перенос «Пациент».
    final segmentPaddingH = layoutW * 0.018;
    final segmentPaddingV = layoutW * 0.042;
    // Слот чуть шире иконки — одна величина для обеих ячеек, без лишнего отъема у текста.
    final minRoleIconSlotW = roleIconSize + 6;
    final maxRoleIconSlotW = layoutW * 0.09;
    final roleIconSlotUpper = maxRoleIconSlotW >= minRoleIconSlotW ? maxRoleIconSlotW : minRoleIconSlotW;
    final roleIconSlotW = (roleIconSize * 1.28).clamp(minRoleIconSlotW, roleIconSlotUpper);
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация')),
      body: ListView(
        padding: EdgeInsets.all(layout.spaceM),
        children: [
          if (_error != null) ...[
            Text(_error!, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.error)),
            SizedBox(height: layout.spaceM),
          ],
          Text('Роль', style: roleHeadingStyle),
          SizedBox(height: layout.spaceS),
          _buildRolePicker(
            theme: theme,
            layout: layout,
            roleSegmentStyle: roleSegmentStyle,
            roleIconSize: roleIconSize,
            segmentPaddingH: segmentPaddingH,
            segmentPaddingV: segmentPaddingV,
            roleIconSlotW: roleIconSlotW,
          ),
          SizedBox(height: layout.spaceM),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Имя', border: OutlineInputBorder()),
          ),
          SizedBox(height: layout.spaceM),
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
                : const Text('Зарегистрироваться'),
          ),
          SizedBox(height: layout.spaceM),
          OutlinedButton(
            onPressed: _loading ? null : () => context.pop(),
            child: const Text('Уже есть аккаунт — войти'),
          ),
        ],
      ),
    );
  }
}
