import 'package:dio/dio.dart';

/// Краткое сообщение на русском для любой ошибки (сеть, API, неизвестное).
String userErrorRu(Object error) {
  if (error is DioException) {
    return dioErrorRu(error);
  }
  final s = error.toString();
  if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('Network is unreachable')) {
    return 'Нет интернета';
  }
  return 'Что-то пошло не так';
}

/// Сообщение по ответу [DioException] (тело FastAPI, код, таймаут).
String dioErrorRu(DioException e) {
  final detail = _extractApiDetail(e.response?.data);
  if (detail != null && detail.isNotEmpty) {
    final mapped = _mapKnownDetail(detail);
    if (mapped != null) {
      return mapped;
    }
    if (_isMostlyRussian(detail) && detail.length <= 140) {
      return detail.trim();
    }
    // Неизвестный текст от API (часто англ. валидация) — коротко по коду.
    switch (e.response?.statusCode) {
      case 422:
        return 'Проверьте поля формы';
      case 400:
        return 'Неверные данные';
      case 401:
        return 'Нужен повторный вход';
      case 403:
        return 'Нет доступа';
      case 404:
        return 'Не найдено';
      case 409:
        return 'Данные уже заняты';
      case 429:
        return 'Слишком часто, подождите';
      default:
        return 'Ошибка сервера';
    }
  }

  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Долгое ожидание ответа';
    case DioExceptionType.connectionError:
      return 'Нет связи с сервером';
    case DioExceptionType.cancel:
      return 'Запрос отменён';
    case DioExceptionType.badCertificate:
      return 'Ошибка защищённого соединения';
    default:
      break;
  }

  switch (e.response?.statusCode) {
    case 400:
      return 'Неверный запрос';
    case 401:
      return 'Нужен повторный вход';
    case 403:
      return 'Нет доступа';
    case 404:
      return 'Не найдено';
    case 409:
      return 'Данные уже заняты';
    case 422:
      return 'Проверьте поля формы';
    case 429:
      return 'Слишком часто, подождите';
    case 500:
    case 502:
    case 503:
    case 504:
      return 'Сервер недоступен';
    default:
      return 'Ошибка сети';
  }
}

String? _extractApiDetail(dynamic data) {
  if (data is! Map) return null;
  final detail = data['detail'];
  if (detail is String) {
    return detail;
  }
  if (detail is List) {
    final parts = <String>[];
    for (final x in detail) {
      if (x is Map) {
        final msg = x['msg'];
        if (msg != null) {
          parts.add(msg.toString());
        }
      }
    }
    if (parts.isNotEmpty) {
      return parts.join(' ');
    }
  }
  return null;
}

bool _isMostlyRussian(String s) => RegExp(r'[а-яА-ЯёЁ]').hasMatch(s);

String? _mapKnownDetail(String raw) {
  final t = raw.trim();
  const m = <String, String>{
    'Email already registered': 'Этот email уже занят',
    'Invalid email or password': 'Неверный email или пароль',
    'Invalid refresh token': 'Сессия устарела — войдите снова',
    'Invalid token type': 'Сессия устарела — войдите снова',
    'Invalid token': 'Сессия устарела — войдите снова',
    'Refresh token revoked': 'Вы вышли на другом устройстве — войдите снова',
    'User not found': 'Пользователь не найден',
    'Not authenticated': 'Войдите в аккаунт',
    'Patient role required': 'Нужна роль пациента',
    'Caregiver role required': 'Нужна роль опекуна',
    'Patient profile missing': 'Профиль пациента не найден',
    'Not your medication': 'Это не ваш препарат',
    'Medication not found': 'Препарат не найден',
    'Patient not linked to this caregiver': 'Пациент не привязан',
    'Invalid code': 'Неверный код',
    'Invalid patient account': 'Неверный аккаунт пациента',
    'Cannot link your own account': 'Нельзя привязать себя',
    'Medication belongs to another patient': 'Препарат другого пациента',
    'Неверный ключ worker': 'Неверный ключ фоновой задачи',
  };
  if (m.containsKey(t)) {
    return m[t];
  }
  if (t.startsWith('Слишком')) {
    return t.length <= 120 ? t : '${t.substring(0, 117)}…';
  }
  return null;
}
