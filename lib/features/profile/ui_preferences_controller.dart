import 'package:flutter/foundation.dart';

import '../../app/storage/key_value_store.dart';
import '../../app/storage/storage_keys.dart';
import '../auth/auth_session.dart';

/// Настройки интерфейса (жирный шрифт): локально + синхронизация с `/v1/users/me`.
class UiPreferencesController extends ChangeNotifier {
  UiPreferencesController(this._store, this._auth);

  final KeyValueStore _store;
  final AuthSession _auth;

  bool _boldFonts = false;
  bool get boldFonts => _boldFonts;

  Future<void> load() async {
    if (_auth.isAuthenticated) {
      try {
        final res = await _auth.dio.get<Map<String, dynamic>>('/v1/users/me');
        final m = res.data!;
        final v = m['ui_bold_fonts'];
        _boldFonts = v == true || v == 1;
        await _store.write(StorageKeys.uiBoldFonts, _boldFonts ? '1' : '0');
        notifyListeners();
        return;
      } catch (_) {
        // офлайн или ошибка - читаем локально
      }
    }
    final raw = await _store.read(StorageKeys.uiBoldFonts);
    _boldFonts = raw == '1' || raw == 'true';
    notifyListeners();
  }

  /// Возвращает `false`, если сервер отклонил сохранение (состояние откатано).
  Future<bool> setBoldFonts(bool value) async {
    final prev = _boldFonts;
    _boldFonts = value;
    await _store.write(StorageKeys.uiBoldFonts, value ? '1' : '0');
    notifyListeners();

    if (!_auth.isAuthenticated) {
      return true;
    }
    try {
      await _auth.dio.patch<Map<String, dynamic>>(
        '/v1/users/me',
        data: {'ui_bold_fonts': value},
      );
      return true;
    } catch (_) {
      _boldFonts = prev;
      await _store.write(StorageKeys.uiBoldFonts, prev ? '1' : '0');
      notifyListeners();
      return false;
    }
  }
}
