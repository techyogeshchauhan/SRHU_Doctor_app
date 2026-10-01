import 'package:flutter/material.dart';

import '../content/stw_content.dart';
import '../core/theme.dart';
import '../core/widgets/layout.dart';

/// Read-only STW reference: sections, related links and optional header.
class ReferenceView extends StatelessWidget {
  const ReferenceView({
    super.key,
    required this.sections,
    required this.links,
    this.header = const [],
  });

  final List<RefSection> sections;
  final List<RelatedLink> links;
  final List<Widget> header;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final b = Theme.of(context).brightness;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...header,
        for (final s in sections)
          Card(
            color: s.isDont ? Tone.danger.background(b) : null,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: text.titleMedium?.copyWith(
                      color: s.isDont ? Tone.danger.foreground(b) : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Bullets(s.lines),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Related information', style: text.titleMedium),
                for (final l in links)
                  ListTile(
                    leading: const Icon(Icons.qr_code_2),
                    title: Text(l.title),
                    subtitle: Text(l.url ?? 'Link to be added (QR code in STW)'),
                  ),
              ],
            ),
          ),
        ),
        const DisclaimerFooter(),
      ],
    );
  }
}
