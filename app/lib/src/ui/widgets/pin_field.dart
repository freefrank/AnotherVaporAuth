import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/responsive.dart';

/// A compact 6-digit numeric PIN input (obscured, centred, number keyboard).
class PinField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool autofocus;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;

  /// Fires as soon as all 6 digits are entered (for auto-submit).
  final ValueChanged<String>? onCompleted;

  const PinField({
    super.key,
    required this.controller,
    required this.label,
    this.autofocus = false,
    this.errorText,
    this.onSubmitted,
    this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      onSubmitted: onSubmitted,
      onChanged: (v) {
        if (v.length == 6) onCompleted?.call(v);
      },
      style: TextStyle(fontSize: context.r(20), letterSpacing: context.r(8)),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
        errorText: errorText,
      ),
    );
  }
}
