import 'package:cashier_system/features/checkout/domain/entities/session_record_entity.dart';

sealed class SessionRecordEvent {
  const SessionRecordEvent();
}

class LoadSessionRecords extends SessionRecordEvent {
  final int limit;

  const LoadSessionRecords({this.limit = 100});
}

class CreateSessionRecord extends SessionRecordEvent {
  final SessionRecordEntity record;

  const CreateSessionRecord({required this.record});
}

class DeleteSessionRecord extends SessionRecordEvent {
  final String id;

  const DeleteSessionRecord({required this.id});
}
