import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/widgets/validated_field.dart';

class ObscuredField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final List<ValidatedFieldRule> rules;
  final TextInputType? keyboardType;
  final FocusNode? focusNode;
  final void Function()? onFieldSubmitted;
  final Widget? prefixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final bool isLast;
  final VoidCallback? onLastFieldSubmit;

  const ObscuredField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.rules,
    this.keyboardType,
    this.focusNode,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.inputFormatters,
    this.isLast = false,
    this.onLastFieldSubmit,
  });

  @override
  State<ObscuredField> createState() => _ObscuredFieldState();
}

class _ObscuredFieldState extends State<ObscuredField> {
  final _obscureNotifier = ValueNotifier<bool>(true);

  @override
  void dispose() {
    _obscureNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _obscureNotifier,
      builder: (context, obscure, _) {
        return ValidatedField(
          controller: widget.controller,
          label: widget.label,
          hint: widget.hint,
          obscureText: obscure,
          rules: widget.rules,
          keyboardType: widget.keyboardType,
          focusNode: widget.focusNode,
          onFieldSubmitted: widget.onFieldSubmitted,
          prefixIcon: widget.prefixIcon,
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? PhosphorIcons.eye : PhosphorIcons.eyeSlash,
            ),
            onPressed: () =>
                _obscureNotifier.value = !_obscureNotifier.value,
          ),
          inputFormatters: widget.inputFormatters,
          isLast: widget.isLast,
          onLastFieldSubmit: widget.onLastFieldSubmit,
        );
      },
    );
  }
}
