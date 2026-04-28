import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Изолят сервиса: держит FGS живым; таймер и HTTP остаются в основном изоляте Flutter.
@pragma('vm:entry-point')
void patientForegroundStartCallback() {
  FlutterForegroundTask.setTaskHandler(_PatientForegroundTaskHandler());
}

class _PatientForegroundTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Пустой цикл достаточен: цель — не дать ОС убить процесс с основным таймером и Dio.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}
