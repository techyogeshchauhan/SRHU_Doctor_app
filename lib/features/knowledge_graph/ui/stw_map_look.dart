import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../clinical_workflow/domain/clinical_finding.dart';
import '../../clinical_workflow/ui/assessment_summary.dart' show toneFor;
import '../domain/stw_map.dart';

/// Colours and icon of each kind of map node.
({Color bg, Color fg, IconData icon}) mapLook(
  MapKind kind, [
  FindingLevel? level,
]) =>
    switch (kind) {
      MapKind.topic => (
          bg: AppTheme.tint,
          fg: AppTheme.primaryNavy,
          icon: Icons.menu_book_outlined,
        ),
      MapKind.box => (
          bg: const Color(0xFFF3E8FF),
          fg: const Color(0xFF6B21A8),
          icon: Icons.picture_as_pdf_outlined,
        ),
      MapKind.question => (
          bg: const Color(0xFFE0F2FE),
          fg: const Color(0xFF075985),
          icon: Icons.edit_note_rounded,
        ),
      MapKind.finding => (
          bg: toneFor(level ?? FindingLevel.info).background(),
          fg: toneFor(level ?? FindingLevel.info).foreground(),
          icon: toneFor(level ?? FindingLevel.info).icon,
        ),
      MapKind.link => (
          bg: const Color(0xFFFFEDD5),
          fg: const Color(0xFF9A3412),
          icon: Icons.link_rounded,
        ),
    };
