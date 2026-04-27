import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityNotifier extends ChangeNotifier {
  ConnectivityNotifier({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  List<ConnectivityResult> _last = const [ConnectivityResult.none];
  List<ConnectivityResult> get last => _last;

  bool get isOffline =>
      _last.isEmpty || _last.every((r) => r == ConnectivityResult.none);

  Future<void> start() async {
    _sub?.cancel();
    try {
      _last = await _connectivity.checkConnectivity();
      notifyListeners();
    } catch (_) {
      _last = const [ConnectivityResult.none];
    }
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      _last = results;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
