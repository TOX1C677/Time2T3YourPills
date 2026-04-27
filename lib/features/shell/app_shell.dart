import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme/app_sizes.dart';
import '../auth/auth_session.dart';
import '../connectivity/connectivity_notifier.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

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

  static const _caregiverDestinations = [
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
  Widget build(BuildContext context) {
    final offline = context.watch<ConnectivityNotifier>().isOffline;
    final auth = context.watch<AuthSession>();
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
        onDestinationSelected: isCaregiver ? onCaregiverSelect : navigationShell.goBranch,
        destinations: isCaregiver ? _caregiverDestinations : _patientDestinations,
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceM, vertical: AppSizes.spaceS),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: scheme.onSecondaryContainer),
              const SizedBox(width: AppSizes.spaceS),
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
