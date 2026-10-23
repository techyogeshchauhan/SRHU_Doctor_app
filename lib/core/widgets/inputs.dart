import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

/// Multi-select checkbox list over an enum or any value type.
class CheckList<T> extends StatelessWidget {
  const CheckList({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final List<(T, String)> items;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (value, label) in items)
          CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(label),
            value: selected.contains(value),
            onChanged: enabled
                ? (checked) => onChanged(checked == true
                    ? {...selected, value}
                    : ({...selected}..remove(value)))
                : null,
          ),
      ],
    );
  }
}

/// Placeholder for a field whose label is shown above it ([floatingLabel]
/// null): a hint that only repeats the label ("Enter <label>") is dropped,
/// as the label already says it and the hint would be cut short.
String? placeholderFor(String? hint, String label, String? floatingLabel) {
  if (hint == null || floatingLabel != null) return hint;
  final bare = label.replaceAll('*', '').trim().toLowerCase();
  return hint.toLowerCase().contains(bare) ? null : hint;
}

/// Shows [label] as the field's floating label when it fits on one line, or
/// as wrapping text above the field so long questions are never cut short
/// on narrow screens. [builder] receives the floating label, or null when
/// the label is shown above.
class AdaptiveLabelField extends StatelessWidget {
  const AdaptiveLabelField({
    super.key,
    required this.label,
    required this.builder,
    this.trailingWidth = 0,
  });

  final String label;
  final Widget Function(String? floatingLabel) builder;

  /// Further width reserved at the end of the field (e.g. an icon).
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final theme = Theme.of(context);
      final style = theme.textTheme.bodyLarge
          ?.merge(theme.inputDecorationTheme.labelStyle);
      double widthOf(String text) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      }

      // Content padding (14 + 14) plus border. Suffix text only appears
      // once the label has floated (at 75% size), so it is not reserved.
      final available = constraints.maxWidth - 32 - trailingWidth;
      if (!constraints.hasBoundedWidth || widthOf(label) <= available) {
        return builder(label);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppTheme.primaryNavy,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          builder(null),
        ],
      );
    });
  }
}

/// Integer field with range validation. Reports `null` while empty/invalid.
class NumberField extends StatefulWidget {
  const NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.suffix,
    this.hintText,
    this.helper,
    this.rangeHint,
    this.enabled = true,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final int min;
  final int max;
  final String? suffix;
  final String? hintText;
  final String? helper;

  /// Expected range from the STW, shown as a small line under the field.
  final String? rangeHint;
  final bool enabled;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value?.toString() ?? '');
  String? _error;

  @override
  void didUpdateWidget(NumberField old) {
    super.didUpdateWidget(old);
    // Reflect external changes (e.g. "Clear") without fighting the user.
    if (int.tryParse(_controller.text) != widget.value && _error == null) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final v = int.tryParse(text);
    String? error;
    if (text.isNotEmpty && (v == null || v < widget.min || v > widget.max)) {
      error = 'Enter ${widget.min}–${widget.max}';
    }
    setState(() => _error = error);
    widget.onChanged(error == null ? v : null);
  }

  @override
  Widget build(BuildContext context) {
    final field = AdaptiveLabelField(
      label: widget.label,
      builder: (label) => TextField(
        controller: _controller,
        enabled: widget.enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [
          TextInputFormatter.withFunction((oldValue, newValue) =>
              RegExp(r'^\d*$').hasMatch(newValue.text) ? newValue : oldValue),
        ],
        decoration: InputDecoration(
          labelText: label,
          hintText: _controller.text.isEmpty
              ? placeholderFor(widget.hintText, widget.label, label)
              : null,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          hintMaxLines: 2,
          suffixText: widget.suffix,
          helperText: widget.helper,
          helperMaxLines: 5,
          errorText: _error,
          errorMaxLines: 2,
        ),
        onChanged: _onChanged,
      ),
    );
    final hint = widget.rangeHint;
    if (hint == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [field, _RangeHint(hint)],
    );
  }
}

/// STW range line shown under a number field, outside the placeholder, so
/// it stays visible while typing.
class _RangeHint extends StatelessWidget {
  const _RangeHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 4, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1, right: 6),
            child: Icon(Icons.straighten_rounded,
                size: 14, color: AppTheme.primaryBlue),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// −/+ stepper for small integer ranges (e.g. PEEP 4–8 cm H₂O).
/// Decimal field with range validation. Reports `null` while empty/invalid.
class DecimalNumberField extends StatefulWidget {
  const DecimalNumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
    this.suffix,
    this.hintText,
    this.helper,
    this.rangeHint,
  });

  final String label;
  final num? value;
  final ValueChanged<num?> onChanged;
  final num min;
  final num max;
  final String? suffix;
  final String? hintText;
  final String? helper;
  final String? rangeHint;

  @override
  State<DecimalNumberField> createState() => _DecimalNumberFieldState();
}

class _DecimalNumberFieldState extends State<DecimalNumberField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value?.toString() ?? '');
  String? _error;

  @override
  void didUpdateWidget(DecimalNumberField old) {
    super.didUpdateWidget(old);
    if (double.tryParse(_controller.text) != widget.value && _error == null) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    final value = double.tryParse(text);
    String? error;
    if (text.isNotEmpty &&
        (value == null || value < widget.min || value > widget.max)) {
      error = 'Enter ${widget.min}–${widget.max}';
    }
    setState(() => _error = error);
    widget.onChanged(error == null ? value : null);
  }

  @override
  Widget build(BuildContext context) {
    final field = AdaptiveLabelField(
      label: widget.label,
      builder: (label) => TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          TextInputFormatter.withFunction((oldValue, newValue) =>
              RegExp(r'^\d*\.?\d*$').hasMatch(newValue.text)
                  ? newValue
                  : oldValue),
        ],
        decoration: InputDecoration(
          labelText: label,
          hintText: _controller.text.isEmpty
              ? placeholderFor(widget.hintText, widget.label, label)
              : null,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          hintMaxLines: 2,
          suffixText: widget.suffix,
          helperText: widget.helper,
          helperMaxLines: 5,
          errorText: _error,
          errorMaxLines: 2,
        ),
        onChanged: _onChanged,
      ),
    );
    final hint = widget.rangeHint;
    if (hint == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [field, _RangeHint(hint)],
    );
  }
}

class IntStepper extends StatelessWidget {
  const IntStepper({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix = '',
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(child: Text(label, style: text.titleSmall)),
        IconButton.outlined(
          tooltip: 'Decrease',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 96,
          child: Text(
            '$value $suffix',
            textAlign: TextAlign.center,
            style: text.titleLarge,
          ),
        ),
        IconButton.outlined(
          tooltip: 'Increase',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// FiO₂ slider, 0.21–1.00 in 0.01 steps.
class Fio2Slider extends StatelessWidget {
  const Fio2Slider({super.key, required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('FiO₂', style: text.titleSmall)),
            Text(value.toStringAsFixed(2), style: text.titleLarge),
          ],
        ),
        Slider(
          value: value,
          min: 0.21,
          max: 1.0,
          divisions: 79,
          label: value.toStringAsFixed(2),
          onChanged: (v) => onChanged((v * 100).round() / 100),
        ),
      ],
    );
  }
}

final dateFormat = DateFormat('dd MMM yyyy');

/// Read-only field that opens a date picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.firstDate,
    required this.lastDate,
    this.helper,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) onChanged(picked);
      },
      child: AdaptiveLabelField(
        label: label,
        trailingWidth: 48,
        builder: (floatingLabel) => InputDecorator(
          decoration: InputDecoration(
            labelText: floatingLabel,
            helperText: helper,
            helperMaxLines: 5,
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          child:
              Text(value == null ? 'Select date' : dateFormat.format(value!)),
        ),
      ),
    );
  }
}
