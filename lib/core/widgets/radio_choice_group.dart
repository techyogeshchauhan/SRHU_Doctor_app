import 'package:flutter/material.dart';

class ChoiceOption<T> {
  const ChoiceOption(this.value, this.label, {this.subtitle, this.leading});

  final T value;
  final String label;
  final String? subtitle;

  /// Optional picture (e.g. the SAS drawing for a grade).
  final Widget? leading;
}

/// A group of mutually exclusive options rendered as radio buttons.
///
/// Built from plain widgets rather than [Radio] so it looks the same across
/// Flutter versions (the Radio API is being migrated to RadioGroup) and can
/// show an image per option. Exposes radio semantics to screen readers.
class RadioChoiceGroup<T> extends StatelessWidget {
  const RadioChoiceGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.horizontal = false,
    this.enabled = true,
  });

  final List<ChoiceOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;

  /// Compact wrapping row (for short labels like "Zone I / II / III").
  final bool horizontal;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final o in options)
        _RadioOptionTile<T>(
          option: o,
          selected: o.value == value,
          compact: horizontal,
          onTap: enabled ? () => onChanged(o.value) : null,
        ),
    ];
    if (horizontal) {
      return Wrap(spacing: 8, runSpacing: 8, children: tiles);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final t in tiles)
          Padding(padding: const EdgeInsets.only(bottom: 6), child: t),
      ],
    );
  }
}

class _RadioOptionTile<T> extends StatelessWidget {
  const _RadioOptionTile({
    required this.option,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final ChoiceOption<T> option;
  final bool selected;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final border = selected ? scheme.primary : scheme.outlineVariant;
    final disabled = onTap == null;

    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          option.label,
          style: text.bodyLarge?.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        if (option.subtitle != null)
          Text(option.subtitle!, style: text.bodySmall),
      ],
    );

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      enabled: !disabled,
      label: option.label,
      excludeSemantics: true,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Material(
          color: selected ? scheme.primaryContainer : scheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: border, width: selected ? 2 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 10 : 12,
                  vertical: compact ? 6 : 8,
                ),
                child: Row(
                  mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected ? scheme.primary : scheme.outline,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    if (option.leading != null) ...[
                      option.leading!,
                      const SizedBox(width: 10),
                    ],
                    if (compact) label else Expanded(child: label),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
