import 'package:flutter/material.dart';
import '../constants/colors.dart';

class UnderlinedTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool obscure;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Widget? suffix;

  const UnderlinedTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.obscure = false,
    this.validator,
    this.keyboardType,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.black54),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        suffixIcon: suffix,
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: ResQColors.primary200, width: 1.2),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: ResQColors.primary500, width: 1.8),
        ),
      ),
    );
  }
}
