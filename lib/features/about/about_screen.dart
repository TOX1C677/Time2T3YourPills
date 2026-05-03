import 'package:flutter/material.dart';

import '../../app/theme/app_screen_layout.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = context.layout;
    return Scaffold(
      appBar: AppBar(title: const Text('О приложении')),
      body: ListView(
        padding: EdgeInsets.all(layout.spaceM),
        children: [
          Text('TimeToTake', style: theme.textTheme.titleLarge),
          SizedBox(height: layout.spaceS),
          Text('Версия 1.0.0', style: theme.textTheme.bodyLarge),
          SizedBox(height: layout.spaceL),
          Text(
            'Клиент для напоминаний о приёме лекарств. Интерфейс адаптирован под двигательные и зрительные ограничения при паркинсонизме (см. DESIGN_GUIDELINES_PARKINSON.md).',
            style: theme.textTheme.bodyLarge,
          ),
          SizedBox(height: layout.spaceL),
          Text(
            'Офлайн: данные читаются из кэша; правки ставятся в очередь и имеют приоритет при последующей синхронизации.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
