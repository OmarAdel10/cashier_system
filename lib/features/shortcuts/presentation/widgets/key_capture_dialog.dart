import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../helpers/key_binding_parser.dart';

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

  LogicalKeyboardKey? _capturedKey;
  bool _ctrl = false;
  bool _alt = false;
  bool _shift = false;
  bool _meta = false;
  bool _hasCaptured = false;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight) {
      setState(() => _ctrl = true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      setState(() => _alt = true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      setState(() => _shift = true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      setState(() => _meta = true);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape &&
        !_ctrl && !_alt && !_shift && !_meta) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }

    setState(() {
      _capturedKey = key;
      _hasCaptured = true;
    });

    return KeyEventResult.handled;
  }

  KeyEventResult _handleKeyRelease(FocusNode node, KeyEvent event) {
    if (event is! KeyUpEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight) {
      setState(() => _ctrl = false);
    }
    if (key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight) {
      setState(() => _alt = false);
    }
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      setState(() => _shift = false);
    }
    if (key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight) {
      setState(() => _meta = false);
    }
    return KeyEventResult.ignored;
  }

  void _confirm() {
    if (!_hasCaptured || _capturedKey == null) return;
    final combo = buildComboString(
      key: _capturedKey!,
      control: _ctrl,
      alt: _alt,
      shift: _shift,
      meta: _meta,
    );
    Navigator.of(context).pop(combo);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final comboString = _hasCaptured && _capturedKey != null
        ? buildComboString(
            key: _capturedKey!,
            control: _ctrl,
            alt: _alt,
            shift: _shift,
            meta: _meta,
          )
        : null;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        final result = _handleKeyEvent(node, event);
        if (result == KeyEventResult.handled) return result;
        return _handleKeyRelease(node, event);
      },
      child: AlertDialog(
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
                  padding: EdgeInsets.symmetric(
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
                SizedBox(height: Spacing.md),
                Text(
                  'Esc',
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
      ),
    );
  }
}
