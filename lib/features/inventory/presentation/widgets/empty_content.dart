import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../features/settings/data/services/localization_service.dart';

class EmptyContent extends StatelessWidget {
  final LocalizationService t;
  final String langCode;
  final String titleKey;
  final String actionKey;

  const EmptyContent({
    super.key,
    required this.t,
    required this.langCode,
    required this.titleKey,
    required this.actionKey,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIcons.package, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(t.translate(titleKey, languageCode: langCode), style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(t.translate(actionKey, languageCode: langCode), style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
