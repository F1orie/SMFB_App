import 'package:smf_app/features/alarm/domain/sleep_session.dart';
import 'package:smf_app/features/alarm/infrastructure/sleep_repository.dart';

import 'sleep_payload.dart';

class SleepPayloadBuilder {
  SleepPayloadBuilder({SleepRepository? repository})
    : _repository = repository ?? SleepRepository.instance;

  final SleepRepository _repository;

  Future<SleepPayload> build({
    SleepSession? targetSession,
    int sessionLimit = 7,
  }) async {
    final sessions = await _repository.getSessions();
    if (sessions.isEmpty) {
      return SleepPayload(
        payloadVersion: SleepPayload.currentVersion,
        sleepDataSource: _repository.dataSource,
        targetSessionId: targetSession?.id,
        sessions: const [],
        epochs: const [],
        notes: const [],
      );
    }

    final ordered = [...sessions]
      ..sort((a, b) => a.startAtEpochMs.compareTo(b.startAtEpochMs));
    final selected = targetSession ?? ordered.last;

    final recent = ordered.reversed
        .take(sessionLimit)
        .toList()
        .reversed
        .toList();
    final includedSessions = <SleepSession>[
      if (!recent.any((session) => session.id == selected.id)) selected,
      ...recent,
    ];
    final includedIds = includedSessions.map((session) => session.id).toSet();

    final epochs = <Map<String, dynamic>>[];
    final notes = <Map<String, dynamic>>[];
    for (final sessionId in includedIds) {
      epochs.addAll(
        (await _repository.getEpochsBySessionId(
          sessionId,
        )).map((epoch) => epoch.toJson()),
      );
      notes.addAll(
        (await _repository.getNotesBySessionId(
          sessionId,
        )).map((note) => note.toJson()),
      );
    }

    return SleepPayload(
      payloadVersion: SleepPayload.currentVersion,
      sleepDataSource: _repository.dataSource,
      targetSessionId: selected.id,
      sessions: includedSessions.map((session) => session.toJson()).toList(),
      epochs: epochs,
      notes: notes,
    );
  }
}
