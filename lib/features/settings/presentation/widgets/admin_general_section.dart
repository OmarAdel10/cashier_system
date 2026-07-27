import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

    return SettingsSection(
      title: t.translate('general', languageCode: langCode),
      children: [
        TextField(
          controller: _storeController,
          decoration: InputDecoration(
            labelText: t.translate('storeName', languageCode: langCode),
            hintText: t.translate('storeNameHint', languageCode: langCode),
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
            if (logoSvgData != null && logoSvgData.isNotEmpty)
              Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SvgPicture.memory(
                  base64Decode(logoSvgData),
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
                  Icon(Icons.image_outlined, size: 40, color: Colors.grey.shade300),
                  const SizedBox(width: 8),
                  Text(
                    t.translate('logoSvg.notSet', languageCode: langCode),
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['svg'],
                );
                if (result != null && context.mounted) {
                  final file = File(result.files.single.path!);
                  final size = await file.length();
                  if (!context.mounted) return;
                  const maxSize = 5 * 1024 * 1024;
                  if (size > maxSize) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('SVG too large (max 5MB)')),
                    );
                    return;
                  }
                  final bytes = await file.readAsBytes();
                  if (!context.mounted) return;
                  final b64 = base64Encode(bytes);
                  context.read<SettingsBloc>().add(LogoSvgChanged(b64));
                }
              },
              icon: const Icon(Icons.image, size: 18),
              label: Text(t.translate('logoSvg.choose', languageCode: langCode)),
            ),
          ],
        ),
        SizedBox(height: Spacing.lg),
        TextField(
          controller: _footnoteController,
          decoration: InputDecoration(
            labelText: t.translate('receiptFootnote', languageCode: langCode),
            hintText: t.translate('receiptFootnoteHint', languageCode: langCode),
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
