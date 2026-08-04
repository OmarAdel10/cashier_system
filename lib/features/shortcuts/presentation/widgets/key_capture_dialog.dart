import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../helpers/key_binding_parser.dart';

class CaptureState {
  final LogicalKeyboardKey? capturedKey;
  final bool ctrl;
  final bool alt;
  final bool shift;
  final bool meta;
  final bool hasCaptured;
  final String? frozenCombo; // frozen combo string at capture time

  const CaptureState({
    this.capturedKey,
    this.ctrl = false,
    this.alt = false,
    this.shift = false,
    this.meta = false,
    this.hasCaptured = false,
    this.frozenCombo,
  });

  CaptureState copyWith({
    LogicalKeyboardKey? capturedKey,
    bool? ctrl,
    bool? alt,
    bool? shift,
    bool? meta,
    bool? hasCaptured,
    String? frozenCombo,
  }) {
    return CaptureState(
      capturedKey: capturedKey ?? this.capturedKey,
      ctrl: ctrl ?? this.ctrl,
      alt: alt ?? this.alt,
      shift: shift ?? this.shift,
      meta: meta ?? this.meta,
      hasCaptured: hasCaptured ?? this.hasCaptured,
      frozenCombo: frozenCombo ?? this.frozenCombo,
    );
  }
}

class KeyCaptureDialog extends StatefulWidget {
  final String currentCombo;
  final String languageCode;

  const KeyCaptureDialog({
    super.key,
    this.currentCombo = '',
    this.languageCode = 'ar',
  });

  @override
  State<KeyCaptureDialog> createState() => _KeyCaptureDialogState();
}

class _KeyCaptureDialogState extends State<KeyCaptureDialog> {
  final _focusNode = FocusNode(debugLabel: 'keyCapture');
  final _t = LocalizationService();
  final _captureStateNotifier = ValueNotifier<CaptureState>(const CaptureState());

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _captureStateNotifier.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight) {
      _captureStateNotifier.value = _captureStateNotifier.value.copyWith(ctrl: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      _captureStateNotifier.value = _captureStateNotifier.value.copyWith(alt: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      _captureStateNotifier.value = _captureStateNotifier.value.copyWith(shift: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      _captureStateNotifier.value = _captureStateNotifier.value.copyWith(meta: true);
      return KeyEventResult.handled;
    }

    final state = _captureStateNotifier.value;
    if (key == LogicalKeyboardKey.escape &&
        !state.ctrl && !state.alt && !state.shift && !state.meta) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    // Reject unsupported keys
    if (!isSupportedKey(key)) {
      return KeyEventResult.handled;
    }

    // Freeze combo at capture time
    final combo = buildComboString(
      key: key,
      control: state.ctrl,
      alt: state.alt,
      shift: state.shift,
      meta: state.meta,
    );

    _captureStateNotifier.value = _captureStateNotifier.value.copyWith(
      capturedKey: key,
      hasCaptured: true,
      frozenCombo: combo,
    );

    return KeyEventResult.handled;
  }

  KeyEventResult _handleKeyRelease(FocusNode node, KeyEvent event) {
    if (event is! KeyUpEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight) {
      _captureStateNotifier.value = _captureStateNotifier.value.copyWith(ctrl: false);
    }
    if (key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      _captureStateNotifier.value = _captureStateNotifier.value.copyWith(alt: false);
    }
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      _captureStateNotifier.value = _captureStateNotifier.value.copyWith(shift: false);
    }
    if (key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      _captureStateNotifier.value = _captureStateNotifier.value.copyWith(meta: false);
    }
    return KeyEventResult.ignored;
  }

  void _confirm() {
    final state = _captureStateNotifier.value;
    if (!state.hasCaptured || state.frozenCombo == null) return;
    Navigator.of(context).pop(state.frozenCombo);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        final result = _handleKeyEvent(node, event);
        if (result == KeyEventResult.handled) return result;
        return _handleKeyRelease(node, event);
      },
      child: ValueListenableBuilder<CaptureState>(
        valueListenable: _captureStateNotifier,
        builder: (context, state, _) {
          final colorScheme = Theme.of(context).colorScheme;
          // Use frozenCombo if available, otherwise compute from live state (for modifier-only display)
          final comboString = state.frozenCombo ??
              (state.hasCaptured && state.capturedKey != null
                  ? buildComboString(
                      key: state.capturedKey!,
                      control: state.ctrl,
                      alt: state.alt,
                      shift: state.shift,
                      meta: state.meta,
                    )
                  : null);

          return AlertDialog(
            title: Text(
              _t.translate('shortcuts.keyCapture.title',
                  languageCode: widget.languageCode),
            ),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (comboString != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: Spacing.lg,
                        horizontal: Spacing.xl,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.primary),
                      ),
                      child: Text(
                        displayCombo(comboString),
                        style: TextStyles.heading2.copyWith(
                          color: colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else ...[
                    Text(
                      _t.translate('shortcuts.keyCapture.prompt',
                          languageCode: widget.languageCode),
                      style: TextStyles.body.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Spacing.md),
                    Text(
                      _t.translate('shortcuts.keyCapture.escHint', languageCode: widget.languageCode),
                      style: TextStyles.caption.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  _t.translate('cancel',
                      languageCode: widget.languageCode),
                ),
              ),
              if (comboString != null)
                FilledButton(
                  onPressed: _confirm,
                  child: Text(
                    _t.translate('shortcuts.keyCapture.confirm',
                        languageCode: widget.languageCode),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
