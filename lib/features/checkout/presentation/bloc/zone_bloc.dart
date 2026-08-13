import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cashier_system/features/checkout/domain/repositories/i_zone_repository.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_state.dart';

class ZoneBloc extends Bloc<ZoneEvent, ZoneState> {
  final IZoneRepository _repository;

  ZoneBloc({required IZoneRepository repository})
    : _repository = repository,
      super(const ZoneState()) {
    on<LoadZones>(_onLoadZones);
    on<SaveZone>(_onSaveZone);
    on<DeleteZone>(_onDeleteZone);
  }

  Future<void> _onLoadZones(LoadZones event, Emitter<ZoneState> emit) async {
    emit(state.copyWith(status: ZoneBlocStatus.loading, clearFailure: true));
    final result = await _repository.getZones();
    result.fold(
      (failure) =>
          emit(state.copyWith(status: ZoneBlocStatus.error, failure: failure)),
      (zones) =>
          emit(state.copyWith(status: ZoneBlocStatus.ready, zones: zones)),
    );
  }

  Future<void> _onSaveZone(SaveZone event, Emitter<ZoneState> emit) async {
    final result = await _repository.saveZone(event.zone);
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (_) => emit(
        state.copyWith(
          zones: [
            event.zone,
            ...state.zones.where((z) => z.id != event.zone.id),
          ],
          clearFailure: true,
        ),
      ),
    );
  }

  Future<void> _onDeleteZone(DeleteZone event, Emitter<ZoneState> emit) async {
    final result = await _repository.deleteZone(event.zoneId);
    result.fold(
      (failure) => emit(state.copyWith(failure: failure)),
      (_) => emit(
        state.copyWith(
          zones: state.zones.where((z) => z.id != event.zoneId).toList(),
          clearFailure: true,
        ),
      ),
    );
  }
}
