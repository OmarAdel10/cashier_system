import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/printing/print_service.dart';
import '../../../../core/printing/svg_checks.dart';
import '../../../../core/theme/spacing.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import 'settings_section.dart';

class AdminGeneralSection extends StatefulWidget {
  const AdminGeneralSection({super.key});

  @override
  State<AdminGeneralSection> createState() => _AdminGeneralSectionState();
}

class _AdminGeneralSectionState extends State<AdminGeneralSection> {
  final _storeController = TextEditingController();
  final _footnoteController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _validatingSvg = false;

  @override
  void initState() {
    super.initState();
    _syncFromSettings();
  }

  void _syncFromSettings() {
    final s = context.read<SettingsBloc>().state.settings;
    if (_storeController.text != s.storeName) {
      _storeController.text = s.storeName;
    }
    if (_footnoteController.text != s.receiptFootnote) {
      _footnoteController.text = s.receiptFootnote;
    }
    if (_addressController.text != s.storeAddress) {
      _addressController.text = s.storeAddress;
    }
    if (_phoneController.text != s.storePhoneNumber) {
      _phoneController.text = s.storePhoneNumber;
    }
  }

  Uint8List? _tryDecodeBase64(String? data) {
    if (data == null || data.trim().isEmpty) return null;
    try {
      return base64Decode(data.trim());
    } catch (_) {
      return null;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _localizedSvgError(String langCode, String? code) {
    final t = LocalizationService();
    final key = switch (code) {
      'TOO_LARGE' => 'svg.tooLarge',
      'NOT_SVG' => 'svg.invalidFile',
      'MALFORMED_XML' => 'svg.malformedXml',
      'DOCTYPE_FORBIDDEN' => 'svg.forbiddenDtd',
      'SCRIPT_FORBIDDEN' ||
      'FORBIDDEN_ELEMENT' ||
      'EVENT_ATTR_FORBIDDEN' ||
      'UNSAFE_CONTENT' => 'svg.containsScript',
      'EXTERNAL_REF_FORBIDDEN' => 'svg.externalReference',
      'TOO_COMPLEX' => 'svg.tooComplex',
      'NOT_RENDERABLE' || 'DIMENSIONS_INVALID' => 'svg.notRenderable',
      _ => 'svg.validationFailed',
    };
    return t.translate(key, languageCode: langCode);
  }

  @override
  void dispose() {
    _storeController.dispose();
    _footnoteController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final storeName = context.select<SettingsBloc, String>(
      (b) => b.state.settings.storeName,
    );
    final footnote = context.select<SettingsBloc, String>(
      (b) => b.state.settings.receiptFootnote,
    );
    final storeAddress = context.select<SettingsBloc, String>(
      (b) => b.state.settings.storeAddress,
    );
    final storePhone = context.select<SettingsBloc, String>(
      (b) => b.state.settings.storePhoneNumber,
    );
    final logoSvgData = context.select<SettingsBloc, String?>(
      (b) => b.state.settings.logoSvgData,
    );

    if (_storeController.text != storeName) {
      _storeController.text = storeName;
    }
    if (_footnoteController.text != footnote) {
      _footnoteController.text = footnote;
    }
    if (_addressController.text != storeAddress) {
      _addressController.text = storeAddress;
    }
    if (_phoneController.text != storePhone) {
      _phoneController.text = storePhone;
    }

    final t = LocalizationService();
    final logoBytes = _tryDecodeBase64(logoSvgData);

    return SettingsSection(
      title: t.translate('general', languageCode: langCode),
      children: [
        TextField(
          controller: _storeController,
          decoration: InputDecoration(
            labelText: t.translate('storeName', languageCode: langCode),
            hintText: t.translate('storeNameHint', languageCode: langCode),
            helperText: t.translate(
              'storeNameSubtitle',
              languageCode: langCode,
            ),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            context.read<SettingsBloc>().add(StoreNameChanged(value));
          },
        ),
        SizedBox(height: Spacing.lg),
        TextField(
          controller: _addressController,
          decoration: InputDecoration(
            labelText: t.translate('storeAddress', languageCode: langCode),
            hintText: t.translate('storeAddressHint', languageCode: langCode),
            helperText: t.translate(
              'storeAddressSubtitle',
              languageCode: langCode,
            ),
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            context.read<SettingsBloc>().add(StoreAddressChanged(value));
          },
        ),
        SizedBox(height: Spacing.lg),
        TextField(
          controller: _phoneController,
          decoration: InputDecoration(
            labelText: t.translate('storePhone', languageCode: langCode),
            hintText: t.translate('storePhoneHint', languageCode: langCode),
            helperText: t.translate(
              'storePhoneSubtitle',
              languageCode: langCode,
            ),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (value) {
            context.read<SettingsBloc>().add(StorePhoneNumberChanged(value));
          },
        ),
        SizedBox(height: Spacing.lg),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (logoBytes != null)
              Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SvgPicture.memory(
                  logoBytes,
                  fit: BoxFit.contain,
                  placeholderBuilder: (_) => const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.translate('logoSvg.notSet', languageCode: langCode),
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              t.translate('logoSvg.subtitle', languageCode: langCode),
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _validatingSvg
                  ? null
                  : () async {
                      final result = await FilePicker.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['svg'],
                      );
                      if (result.isEmpty || !context.mounted) return;
                      final file = File(result.single.path!);
                      final size = await file.length();
                      if (!context.mounted) return;
                      const maxSize = 5 * 1024 * 1024;
                      if (size > maxSize) {
                        _showMessage(
                          t.translate('svg.tooLarge', languageCode: langCode),
                        );
                        return;
                      }
                      final bytes = await file.readAsBytes();
                      if (!context.mounted) return;

                      final quick = SvgQuickCheck.check(bytes);
                      if (!quick.valid) {
                        _showMessage(
                          _localizedSvgError(langCode, quick.errorCode),
                        );
                        return;
                      }

                      setState(() => _validatingSvg = true);
                      final service = PrintService();
                      try {
                        final errors = await service
                            .validateSvg(base64Encode(bytes))
                            .timeout(const Duration(seconds: 10));
                        if (!context.mounted) return;
                        if (errors.isNotEmpty) {
                          _showMessage(
                            _localizedSvgError(langCode, errors.first),
                          );
                          return;
                        }
                      } catch (_) {
                        if (!context.mounted) return;
                        _showMessage(
                          t.translate(
                            'svg.serverUnreachable',
                            languageCode: langCode,
                          ),
                        );
                        return;
                      } finally {
                        service.dispose();
                        if (mounted) setState(() => _validatingSvg = false);
                      }
                      if (!context.mounted) return;
                      context.read<SettingsBloc>().add(
                        LogoSvgChanged(base64Encode(bytes)),
                      );
                    },
              icon: const Icon(Icons.image, size: 18),
              label: _validatingSvg
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(t.translate('logoSvg.choose', languageCode: langCode)),
            ),
          ],
        ),
        SizedBox(height: Spacing.lg),
        TextField(
          controller: _footnoteController,
          decoration: InputDecoration(
            labelText: t.translate('receiptFootnote', languageCode: langCode),
            hintText: t.translate(
              'receiptFootnoteHint',
              languageCode: langCode,
            ),
            helperText: t.translate(
              'receiptFootnoteSubtitle',
              languageCode: langCode,
            ),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          onChanged: (value) {
            context.read<SettingsBloc>().add(ReceiptFootnoteChanged(value));
          },
        ),
      ],
    );
  }
}
