import 'dart:convert';

import '../../app/storage/key_value_store.dart';
import '../../app/storage/storage_keys.dart';
import '../../core/models/medication.dart';
import '../sources/remote/mock_remote_data_source.dart';
import 'outbox_repository.dart';

class MedicationsRepository {
  MedicationsRepository(this._store, this._remote, this._outbox);

  final KeyValueStore _store;
  final MockRemoteDataSource _remote;
  final OutboxRepository _outbox;

  Future<List<Medication>> loadLocal() async {
    final raw = await _store.read(StorageKeys.medicationsJson);
    return Medication.listFromJsonString(raw);
  }

  Future<void> persistLocal(List<Medication> items) async {
    await _store.write(StorageKeys.medicationsJson, Medication.listToJsonString(items));
  }

  /// Локально + outbox. Офлайн-правки имеют приоритет до успешной отправки.
  Future<void> upsertLocalEnqueue(Medication medication) async {
    final current = await loadLocal();
    final idx = current.indexWhere((e) => e.id == medication.id);
    final next = List<Medication>.from(current);
    final stamped = medication.copyWith(updatedAt: DateTime.now());
    if (idx >= 0) {
      next[idx] = stamped;
    } else {
      next.add(stamped);
    }
    await persistLocal(next);
    await _outbox.enqueue(
      type: 'medication_upsert',
      payloadJson: jsonEncode(stamped.toJson()),
    );
  }

  /// Удаление локально + запись в outbox для синка.
  Future<void> deleteLocalEnqueue(String id) async {
    final current = await loadLocal();
    final next = current.where((e) => e.id != id).toList();
    await persistLocal(next);
    await _outbox.enqueue(
      type: 'medication_delete',
      payloadJson: jsonEncode({'id': id}),
    );
  }

  /// Pull: если очередь пуста — можно подтянуть «сервер»; иначе не перетираем локальные правки.
  Future<List<Medication>> pullMergePreferLocal() async {
    final pending = await _outbox.readAll();
    if (pending.isNotEmpty) {
      return loadLocal();
    }
    final remote = await _remote.fetchMedications();
    await persistLocal(remote);
    return remote;
  }
}
