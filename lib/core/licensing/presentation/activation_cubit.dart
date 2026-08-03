import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/enums/license_status.dart';
import '../engine/license_engine.dart';

sealed class ActivationState {
  const ActivationState();
}

class ActivationInitial extends ActivationState {
  const ActivationInitial();
}

class ActivationLoading extends ActivationState {
  const ActivationLoading();
}

class ActivationError extends ActivationState {
  final String message;
  const ActivationError(this.message);
}

class ActivationDeviceReady extends ActivationState {
  final String deviceId;
  final LicenseStatus status;
  const ActivationDeviceReady({required this.deviceId, required this.status});
}

class ActivationSuccess extends ActivationState {
  const ActivationSuccess();
}

class ActivationCubit extends Cubit<ActivationState> {
  final LicenseEngine _engine;

  ActivationCubit({LicenseEngine? engine})
      : _engine = engine ?? LicenseEngine(),
        super(const ActivationInitial());

  Future<void> checkLicense() async {
    emit(const ActivationLoading());
    try {
      final status = await _engine.verifyLicense();
      if (status == LicenseStatus.valid) {
        emit(const ActivationSuccess());
        return;
      }
      final deviceId = await _engine.getDeviceId();
      emit(ActivationDeviceReady(deviceId: deviceId, status: status));
    } catch (_) {
      emit(const ActivationError('Failed to check license.'));
    }
  }

  Future<void> submitActivationKey(String key) async {
    if (key.trim().isEmpty) {
      emit(const ActivationError('Activation key cannot be empty.'));
      return;
    }
    emit(const ActivationLoading());
    try {
      final success = await _engine.activate(key.trim());
      if (success) {
        emit(const ActivationSuccess());
      } else {
        emit(const ActivationError('Invalid activation key. Verify the key and try again.'));
      }
    } catch (_) {
      emit(const ActivationError('Activation failed. Please try again.'));
    }
  }

  void resetError() {
    final current = state;
    if (current is ActivationError) {
      emit(const ActivationInitial());
    }
  }
}
