sealed class ShiftEvent {
  const ShiftEvent();
}

final class StartShift extends ShiftEvent {
  final String username;
  const StartShift(this.username);
}

final class EndShift extends ShiftEvent {
  const EndShift();
}
