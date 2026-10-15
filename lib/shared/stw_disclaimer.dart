import 'package:flutter/material.dart';

import '../content/stw_content.dart';
import '../core/theme.dart';

/// The STW PDFs bundled with the app, followed by the STW disclaimer.
/// Shown in the Home "Disclaimer" sheet and on the References screen.
class StwDisclaimerContent extends StatelessWidget {
  const StwDisclaimerContent({super.key, this.color = AppTheme.bodyText});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final body = TextStyle(
      fontFamily: 'Inter',
      fontSize: 13,
      height: 1.5,
      color: color,
    );
    final heading = body.copyWith(fontWeight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STWs in this app', style: heading),
        const SizedBox(height: 4),
        for (final s in bundledStws)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: body),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: s.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: ' · ${[
                            if (s.code != null) s.code!,
                            s.version,
                            'for the ${s.appliesTo}',
                          ].join(' · ')}',
                        ),
                      ],
                    ),
                    style: body,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Text(stwDisclaimer, style: body),
        const SizedBox(height: 8),
        Text(stwDisclaimerNote,
            style: body.copyWith(fontStyle: FontStyle.italic)),
      ],
    );
  }
}
