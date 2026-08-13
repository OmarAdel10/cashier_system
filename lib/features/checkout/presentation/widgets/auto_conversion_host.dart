import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cashier_system/features/checkout/presentation/bloc/station_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/services/auto_conversion_service.dart';

/// Starts [AutoConversionService] for the lifetime of playstation mode and
/// disposes it when the workspace leaves the tree.
class AutoConversionHost extends StatefulWidget {
  const AutoConversionHost({super.key, required this.child});

  final Widget child;

  @override
  State<AutoConversionHost> createState() => _AutoConversionHostState();
}

class _AutoConversionHostState extends State<AutoConversionHost> {
  AutoConversionService? _service;

  @override
  void initState() {
    super.initState();
    _service = AutoConversionService(stationBloc: context.read<StationBloc>())
      ..start();
  }

  @override
  void dispose() {
    _service?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
