import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Устанавливает [tz.local] по IANA-имени устройства. Неверное имя ломает zonedSchedule.
Future<void> configureLocalTimeZone() async {
  tzdata.initializeTimeZones();
  try {
    final name = await FlutterTimezone.getLocalTimezone();
    final loc = tz.getLocation(name);
    tz.setLocalLocation(loc);
    if (kDebugMode) {
      debugPrint('timezone: local=$name');
    }
  } catch (e, st) {
    debugPrint('timezone: failed to resolve device zone: $e\n$st');
    try {
      tz.setLocalLocation(tz.getLocation('UTC'));
    } catch (_) {
      // последний шанс - база уже инициализирована
    }
  }
}
