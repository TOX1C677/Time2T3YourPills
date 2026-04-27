import 'package:flutter/foundation.dart';

import '../../app/storage/key_value_store.dart';
import '../../app/storage/storage_keys.dart';

/// Локальные настройки интерфейса (жирный шрифт и т.д.).
class UiPreferencesController extends ChangeNotifier {
  UiPreferencesController(this._store);

  final KeyValueStore _store;

  bool _boldFonts = false;
  bool get boldFonts => _boldFonts;

  Future<void> load() async {
    final raw = await _store.read(StorageKeys.uiBoldFonts);
    _boldFonts = raw == '1' || raw == 'true';
    notifyListeners();
  }

  Future<void> setBoldFonts(bool value) async {
    _boldFonts = value;
    await _store.write(StorageKeys.uiBoldFonts, value ? '1' : '0');
    notifyListeners();
  }
}
