import 'package:flutter/material.dart';

import 'focus_controller.dart';

/// Wraps overlay content for modal stack tracking.
///
/// Calls [FocusController.pushModal()] on initState and [FocusController.popModal()]
/// on dispose. The modal stack depth (routes + overlays) determines whether
/// [FocusController.canActivate] blocks shortcut dispatch.
///
/// Usage in GlobalShortcutGate:
///   FocusGuard(controller: _focusController, child: GlobalSearchOverlay(...))
///
/// Today's only overlay (global search) is wrapped for uniformity.
class FocusGuard extends StatefulWidget {
  final FocusController? controller;
  final Widget child;

  const FocusGuard({required this.controller, required this.child, super.key});

  @override
  State<FocusGuard> createState() => _FocusGuardState();
}

class _FocusGuardState extends State<FocusGuard> {
  @override
  void initState() {
    super.initState();
    widget.controller?.pushModal();
  }

  @override
  void dispose() {
    widget.controller?.popModal();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
