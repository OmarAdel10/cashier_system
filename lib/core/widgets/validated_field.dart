import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../theme/spacing.dart';

class ValidatedFieldRule {
  final String message;
  final bool Function(String value) isValid;

  const ValidatedFieldRule({
    required this.message,
    required this.isValid,
  });
}

enum ValidationState { none, valid, invalid }

class ValidatedField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final List<ValidatedFieldRule> rules;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final void Function()? onFieldSubmitted;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final bool isLast;
  final VoidCallback? onLastFieldSubmit;
  final bool obscureText;
  final bool autoValidate;

  const ValidatedField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.rules,
    this.keyboardType,
    this.focusNode,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
    this.isLast = false,
    this.onLastFieldSubmit,
    this.obscureText = false,
    this.autoValidate = false,
  });

  @override
  ValidatedFieldState createState() => ValidatedFieldState();
}

class ValidatedFieldState extends State<ValidatedField> {
  late final FocusNode _focusNode;
  final _validationStateNotifier = ValueNotifier<ValidationState>(ValidationState.none);
  final _errorNotifier = ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    if (widget.autoValidate) _validateSilent();
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    _validationStateNotifier.dispose();
    _errorNotifier.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _runValidation();
    }
  }

  void validate() {
    _runValidation();
  }

  void _validateSilent() {
    final value = widget.controller.text.trim();
    for (final rule in widget.rules) {
      if (!rule.isValid(value)) {
        _validationStateNotifier.value = ValidationState.invalid;
        _errorNotifier.value = rule.message;
        return;
      }
    }
    _validationStateNotifier.value = ValidationState.valid;
    _errorNotifier.value = '';
  }

  void _runValidation() {
    _validateSilent();
  }

  bool get isValid {
    _runValidation();
    return _validationStateNotifier.value == ValidationState.valid;
  }

  void _onSubmitted(String value) {
    _runValidation();
    if (widget.isLast && _validationStateNotifier.value == ValidationState.valid) {
      widget.onLastFieldSubmit?.call();
    } else {
      widget.onFieldSubmitted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_validationStateNotifier, _errorNotifier]),
      builder: (context, _) {
        final iconColor = switch (_validationStateNotifier.value) {
          ValidationState.none => Colors.grey.shade400,
          ValidationState.valid => Colors.green,
          ValidationState.invalid => Colors.red,
        };
        final textColor = switch (_validationStateNotifier.value) {
          ValidationState.none => Colors.grey.shade500,
          ValidationState.valid => Colors.green,
          ValidationState.invalid => Colors.red,
        };
        final icon = switch (_validationStateNotifier.value) {
          ValidationState.none => PhosphorIcons.circle,
          ValidationState.valid => PhosphorIcons.checkCircle,
          ValidationState.invalid => PhosphorIcons.xCircle,
        };
        final message = switch (_validationStateNotifier.value) {
          ValidationState.none => widget.hint,
          ValidationState.valid => widget.hint,
          ValidationState.invalid => _errorNotifier.value,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              obscureText: widget.obscureText,
              decoration: InputDecoration(
                labelText: widget.label,
                prefixIcon: widget.prefixIcon,
                suffixIcon: widget.suffixIcon,
                border: const OutlineInputBorder(),
              ),
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              onSubmitted: _onSubmitted,
              textInputAction: widget.isLast ? TextInputAction.done : TextInputAction.next,
            ),
            const SizedBox(height: Spacing.xs),
            Row(
              children: [
                PhosphorIcon(icon, size: 14, color: iconColor),
                const SizedBox(width: Spacing.xs),
                Text(message, style: TextStyle(fontSize: 12, color: textColor)),
              ],
            ),
          ],
        );
      },
    );
  }
}
