import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../features/settings/data/services/localization_service.dart';

class ActivationInput extends StatefulWidget {
  final void Function(String key) onSubmit;
  final String? errorMessage;
  final bool isLoading;
  final String langCode;

  const ActivationInput({
    super.key,
    required this.onSubmit,
    this.errorMessage,
    this.isLoading = false,
    this.langCode = 'en',
  });

  @override
  State<ActivationInput> createState() => _ActivationInputState();
}

class _ActivationInputState extends State<ActivationInput> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = LocalizationService();
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.translate(
              'licensing.activationKey',
              languageCode: widget.langCode,
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.35,
            child: TextFormField(
              controller: _controller,
              enabled: !widget.isLoading,
              maxLines: 1,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-_=+/]')),
              ],
              decoration: InputDecoration(
                hintText: t.translate(
                  'licensing.activationKey.hint',
                  languageCode: widget.langCode,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                errorText: widget.errorMessage,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t.translate(
                    'licensing.activationKey.required',
                    languageCode: widget.langCode,
                  );
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: widget.isLoading ? null : _submit,
            icon: widget.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.vpn_key),
            label: Text(
              widget.isLoading
                  ? t.translate(
                      'licensing.verifying',
                      languageCode: widget.langCode,
                    )
                  : t.translate(
                      'licensing.activate',
                      languageCode: widget.langCode,
                    ),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
