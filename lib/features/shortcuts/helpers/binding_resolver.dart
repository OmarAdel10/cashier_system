String? findConflict({
  required Map<String, String> bindings,
  required String actionToken,
  required String keyCombo,
}) {
  for (final entry in bindings.entries) {
    if (entry.value == keyCombo && entry.key != actionToken) {
      return entry.key;
    }
  }
  return null;
}

Map<String, String> resolveBindingConflicts({
  required Map<String, String> currentBindings,
  required String actionToken,
  required String keyCombo,
}) {
  final resolved = Map<String, String>.from(currentBindings);
  final conflictKey = findConflict(
    bindings: resolved,
    actionToken: actionToken,
    keyCombo: keyCombo,
  );
  if (conflictKey != null) {
    resolved.remove(conflictKey);
  }
  resolved[actionToken] = keyCombo;
  return resolved;
}
