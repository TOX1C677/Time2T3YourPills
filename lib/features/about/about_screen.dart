import 'package:flutter/material.dart';

import '../../app/theme/app_sizes.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('О приложении')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.spaceM),
        children: [
          Text('Time2T3 Your Pills', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSizes.spaceS),
          Text('Версия 1.0.0', style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSizes.spaceL),
          Text(
            'Клиент для напоминаний о приёме лекарств. Интерфейс адаптирован под двигательные и зрительные ограничения при паркинсонизме (см. DESIGN_GUIDELINES_PARKINSON.md).',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSizes.spaceL),
          Text(
            'Офлайн: данные читаются из кэша; правки ставятся в очередь и имеют приоритет при последующей синхронизации.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
