import 'dart:convert';

import '../../app/storage/key_value_store.dart';
import '../../app/storage/storage_keys.dart';
import '../../core/models/patient_profile.dart';
import '../sources/remote/remote_sync_data_source.dart';
import 'outbox_repository.dart';

class PatientRepository {
  PatientRepository(this._store, this._remote, this._outbox);

  final KeyValueStore _store;
  final RemoteSyncDataSource _remote;
  final OutboxRepository _outbox;

  Future<PatientProfile?> loadLocal() async {
    final raw = await _store.read(StorageKeys.patientProfileJson);
    return PatientProfile.tryParse(raw);
  }

  Future<void> persistLocal(PatientProfile profile) async {
    await _store.write(StorageKeys.patientProfileJson, profile.toJsonString());
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
    await _store.remove(StorageKeys.patientProfileJson);
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
