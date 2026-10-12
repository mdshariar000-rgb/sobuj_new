import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'widgets/field_diagnostics_card.dart';

/// "Check the weather in your area" from Home's quick access list.
class WeatherScreen extends StatelessWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Weather in your area')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: const [FieldDiagnosticsCard()],
      ),
    );
  }
}
