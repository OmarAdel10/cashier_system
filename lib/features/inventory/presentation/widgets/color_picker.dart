import 'package:flutter/material.dart';

class ColorPicker extends StatelessWidget {
  final List<String> colors;
  final String? selectedHex;
  final ValueChanged<String> onColorTap;

  const ColorPicker({
    super.key,
    required this.colors,
    required this.selectedHex,
    required this.onColorTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: colors.map((hex) {
        final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
        final sel = selectedHex == hex;
        return GestureDetector(
          onTap: () => onColorTap(hex),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
              border: sel ? Border.all(color: Colors.white, width: 3) : null,
              boxShadow: sel ? [BoxShadow(color: color.withAlpha(128), blurRadius: 8)] : null,
            ),
            child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
          ),
        );
      }).toList(),
    );
  }
}
