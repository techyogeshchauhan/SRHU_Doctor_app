import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
    this.helper,
    this.enabled = true,
  });

  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  final int min;
  final int max;
  final String? suffix;
  final String? helper;
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
    return TextField(
      controller: _controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffix,
        helperText: widget.helper,
        helperMaxLines: 2,
        errorText: _error,
      ),
      onChanged: _onChanged,
    );
  }
}

/// −/+ stepper for small integer ranges (e.g. PEEP 4–8 cm H₂O).
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
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value == null ? 'Select date' : dateFormat.format(value!)),
      ),
    );
  }
}
