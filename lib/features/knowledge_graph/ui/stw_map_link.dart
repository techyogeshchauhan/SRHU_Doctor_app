import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme.dart';

/// "Explore in STW Map": opens the map on a PDF box or topic ([focus]), on
/// the box an MCQ citation names ([reference]), or on the STW of a PDF file
/// ([file]) when the box is not known.
class StwMapLinkButton extends StatelessWidget {
  const StwMapLinkButton({
    super.key,
    this.focus,
    this.reference,
    this.file,
    this.label = 'Explore in STW Map',
  });

  final String? focus;
  final String? reference;
  final String? file;
  final String label;

  static String location({String? focus, String? reference, String? file}) =>
      Uri(path: '/stw-map', queryParameters: {
        if (focus != null) 'focus': focus,
        if (reference != null) 'ref': reference,
        if (file != null) 'file': file,
      }).toString();

  @override
  Widget build(BuildContext context) => TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.primaryBlue,
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        icon: const Icon(Icons.account_tree_outlined, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
        onPressed: () => context.push(
          location(focus: focus, reference: reference, file: file),
        ),
      );
}
