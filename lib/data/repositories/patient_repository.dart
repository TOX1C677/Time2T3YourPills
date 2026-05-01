import 'dart:convert';

import '../../app/storage/key_value_store.dart';
import '../../core/models/patient_profile.dart';
import '../sources/remote/remote_sync_data_source.dart';
import 'outbox_repository.dart';

class PatientRepository {
  PatientRepository(
    this._store,
    this._remote,
    this._outbox, {
    required String Function() storageKey,
  }) : _storageKey = storageKey;

  final KeyValueStore _store;
  final RemoteSyncDataSource _remote;
  final OutboxRepository _outbox;
  final String Function() _storageKey;

  Future<PatientProfile?> loadLocal() async {
    final raw = await _store.read(_storageKey());
    return PatientProfile.tryParse(raw);
  }

  Future<void> persistLocal(PatientProfile profile) async {
    await _store.write(_storageKey(), profile.toJsonString());
  }

  Future<void> upsertLocalEnqueue(PatientProfile profile) async {
    final stamped = PatientProfile(
      name: profile.name,
      surname: profile.surname,
      updatedAt: DateTime.now(),
    );
    await persistLocal(stamped);
    await _outbox.enqueue(
      type: 'patient_upsert',
      payloadJson: jsonEncode(stamped.toJson()),
    );
  }

  Future<void> clearLocal() async {
    await _store.remove(_storageKey());
  }

  Future<PatientProfile?> pullPreferLocal() async {
    final pending = await _outbox.readAll();
    if (pending.isNotEmpty) {
      return loadLocal();
    }
    final remote = await _remote.fetchPatient();
    if (remote != null) {
      await persistLocal(remote);
    }
    return remote ?? loadLocal();
  }
}
