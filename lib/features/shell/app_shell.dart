import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_screen_layout.dart';
import '../auth/auth_session.dart';
import '../caregiver/caregiver_scope.dart';
import '../connectivity/connectivity_notifier.dart';
import '../medications/medications_controller.dart';
import '../timer/intake_timer_controller.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  StatefulNavigationShell get navigationShell => widget.navigationShell;

  static const _patientDestinations = [
    NavigationDestination(
      icon: Icon(Icons.timer_outlined),
      selectedIcon: Icon(Icons.timer),
      label: 'Таймер',
    ),
    NavigationDestination(
      icon: Icon(Icons.medication_outlined),
      selectedIcon: Icon(Icons.medication),
      label: 'Таблетки',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: 'История',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Профиль',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = context.read<AuthSession>();
      if (auth.isAuthenticated && auth.role == 'caregiver') {
        await context.read<CaregiverScope>().refreshMissedAlertsCount();
      }
      if (!mounted) return;
      // Сразу подтянуть препараты в таймер (до открытия вкладки «Таймер»).
      if (auth.isAuthenticated && auth.role == 'patient') {
        await context.read<IntakeTimerController>().refreshFromMedications();
      }
    });
  }

  List<NavigationDestination> _caregiverDestinations(int missedCount) {
    Widget profileIcon(IconData iconData) {
      if (missedCount <= 0) {
        return Icon(iconData);
      }
      final label = missedCount > 99 ? '99+' : '$missedCount';
      return Badge(label: Text(label), child: Icon(iconData));
    }

    return [
      const NavigationDestination(
        icon: Icon(Icons.medication_outlined),
        selectedIcon: Icon(Icons.medication),
        label: 'Таблетки',
      ),
      const NavigationDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history),
        label: 'История',
      ),
      NavigationDestination(
        icon: profileIcon(Icons.person_outline),
        selectedIcon: profileIcon(Icons.person),
        label: 'Профиль',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<ConnectivityNotifier>().isOffline;
    final auth = context.watch<AuthSession>();
    final cg = context.watch<CaregiverScope>();
    final isCaregiver = auth.isAuthenticated && auth.role == 'caregiver';

    int caregiverSelectedDisplay() {
      final i = navigationShell.currentIndex;
      if (i <= 0) {
        return 0;
      }
      return i - 1;
    }

    void onCaregiverSelect(int displayIndex) {
      navigationShell.goBranch(displayIndex + 1);
      context.read<CaregiverScope>().refreshMissedAlertsCount();
    }

    return Scaffold(
      body: Column(
        children: [
          if (offline) const _OfflineBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: isCaregiver ? caregiverSelectedDisplay() : navigationShell.currentIndex,
        onDestinationSelected: isCaregiver
            ? onCaregiverSelect
            : (int index) {
                navigationShell.goBranch(index);
                if (index == 0) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    context.read<IntakeTimerController>().refreshFromMedications();
                  });
                }
                if (index == 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    context.read<MedicationsController>().load();
                  });
                }
              },
        destinations: isCaregiver ? _caregiverDestinations(cg.missedAlertsCount) : _patientDestinations,
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: layout.spaceM, vertical: layout.spaceS),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: scheme.onSecondaryContainer),
              SizedBox(width: layout.spaceS),
              Expanded(
                child: Text(
                  'Нет сети: работаем из кэша, изменения в очереди на отправку.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
