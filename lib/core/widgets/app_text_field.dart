import 'package:flutter/material.dart';

/// Standard text input field used across the app.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.label,
    super.key,
    this.controller,
    this.hintText,
    this.errorText,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? errorText;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        errorText: errorText,
      ),
    );
  }
}
