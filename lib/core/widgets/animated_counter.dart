import 'package:flutter/material.dart';

class AnimatedCounter extends StatelessWidget {
  final String value;
  final TextStyle? style;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: Text(
        value,
        key: ValueKey(value),
        style: style,
      ),
    );
  }
}
