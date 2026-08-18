import 'dart:async';

import 'package:flutter/foundation.dart';

/// App-wide one-second ticker that drives every live elapsed-time display.
///
/// A single [Timer] runs only while at least one listener is attached and
/// exposes the current wall-clock time in whole seconds, so widgets rebuild
/// from one shared clock instead of each scheduling its own timer and calling
/// [State.setState].
class ClockTicker extends ValueNotifier<int> {
  ClockTicker._() : super(DateTime.now().millisecondsSinceEpoch ~/ 1000);

  /// The app-wide ticker instance.
  static final ClockTicker instance = ClockTicker._();

  Timer? _timer;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (hasListeners && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        value = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      });
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners && _timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }
}