import 'package:uuid/uuid.dart';

import '../../app/storage/key_value_store.dart';
import '../../app/storage/storage_keys.dart';
import '../../core/models/outbox_entry.dart';

class OutboxRepository {
  OutboxRepository(this._store, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final KeyValueStore _store;
  final Uuid _uuid;

  Future<List<OutboxEntry>> readAll() async {
    final raw = await _store.read(StorageKeys.outboxJson);
    return OutboxEntry.listFromJsonString(raw);
  }

  Future<void> _writeAll(List<OutboxEntry> items) async {
    await _store.write(StorageKeys.outboxJson, OutboxEntry.listToJsonString(items));
  }

  Future<void> enqueue({required String type, required String payloadJson}) async {
    final list = await readAll();
    list.add(
      OutboxEntry(
        id: _uuid.v4(),
        type: type,
        payloadJson: payloadJson,
        createdAt: DateTime.now(),
      ),
    );
    await _writeAll(list);
  }

  Future<void> clear() async {
    await _store.write(StorageKeys.outboxJson, '[]');
  }

  Future<void> replaceAll(List<OutboxEntry> next) async {
    await _writeAll(next);
  }
}
