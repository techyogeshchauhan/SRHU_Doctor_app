import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/radio_choice_group.dart';
import '../../clinical_workflow/domain/clinical_question.dart';
import '../../jaundice/domain/jaundice_rules.dart';
import '../../jaundice/domain/jaundice_workflow.dart';
import '../../post_asphyxia/domain/post_asphyxia_workflow.dart';
import '../../rd/domain/rd_workflow.dart';
import '../../sepsis/domain/sepsis_workflow.dart';
import '../domain/case_parser.dart';
import '../domain/structured_case.dart';

const _basic = 'Basic information';
const _temperature = 'Temperature';
const _respiratory = 'Respiratory assessment';
const _jaundice = 'Jaundice assessment';
const _other = 'Other findings';

/// Which section each validated field belongs to.
const _sectionOf = {
  CaseField.gaWeeks: _basic,
  CaseField.gaDays: _basic,
  CaseField.birthWeightKg: _basic,
  CaseField.age: _basic,
  CaseField.temperature: _temperature,
  CaseField.rr: _respiratory,
  CaseField.tcb: _jaundice,
  CaseField.tsb: _jaundice,
  CaseField.bg: _other,
};

List<(String, String)> _items(List<QuestionOption> options) =>
    [for (final o in options) ('${o.value}', o.label)];

/// Case history from selectable fields: sections → summary → "Analyse Case".
/// Calls [onAnalyse] with the case built by the shared case builder.
class StructuredCaseForm extends StatefulWidget {
  const StructuredCaseForm({super.key, required this.onAnalyse});

  final ValueChanged<ParsedCase> onAnalyse;

  @override
  State<StructuredCaseForm> createState() => _StructuredCaseFormState();
}

class _StructuredCaseFormState extends State<StructuredCaseForm> {
  final _case = StructuredCase();
  late final Map<String, TextEditingController> _text = {
    for (final f in _sectionOf.keys) f: TextEditingController(),
  };
  final _open = <String>{_basic};
  var _reviewing = false;

  /// Errors are shown once the user has asked to review.
  var _showErrors = false;

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _setText(String field, String v) => setState(() {
        switch (field) {
          case CaseField.gaWeeks:
            _case.gaWeeks = v;
          case CaseField.gaDays:
            _case.gaDays = v;
          case CaseField.birthWeightKg:
            _case.birthWeightKg = v;
          case CaseField.age:
            _case.age = v;
          case CaseField.temperature:
            _case.temperature = v;
          case CaseField.rr:
            _case.rr = v;
          case CaseField.tcb:
            _case.tcb = v;
          case CaseField.tsb:
            _case.tsb = v;
          case CaseField.bg:
            _case.bg = v;
        }
      });

  void _review() {
    final errors = _case.validate();
    setState(() {
      _showErrors = true;
      if (errors.isEmpty) {
        _reviewing = true;
      } else {
        _open.addAll(errors.keys.map((f) => _sectionOf[f]!));
      }
    });
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (errors.isNotEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text(errors.length == 1
            ? 'Check the highlighted value before reviewing.'
            : 'Check the ${errors.length} highlighted values before '
                'reviewing.'),
      ));
    }
  }

  void _edit(String section) => setState(() {
        _reviewing = false;
        _open
          ..clear()
          ..add(section);
      });

  @override
  Widget build(BuildContext context) =>
      _reviewing ? _summary(context) : _form(context);

  // ---- Summary ----

  Widget _summary(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rows = _case.summary();
    final sections = {for (final r in rows) r.$1};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          key: const ValueKey('case-summary'),
          title: 'Case summary',
          subtitle: 'Check the values as entered. Tap Edit to change a '
              'section.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in sections) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(s,
                          style: text.titleSmall?.copyWith(
                              color: AppTheme.primaryNavy,
                              fontWeight: FontWeight.w700)),
                    ),
                    TextButton.icon(
                      key: ValueKey('case-edit-$s'),
                      onPressed: () => _edit(s),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                  ],
                ),
                for (final (sec, label, value) in rows)
                  if (sec == s)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text: '$label: ',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: value),
                      ])),
                    ),
                const Divider(height: 16),
              ],
            ],
          ),
        ),
        FilledButton.icon(
          key: const ValueKey('case-analyse-structured'),
          onPressed: () => widget.onAnalyse(_case.toParsedCase()),
          icon: const Icon(Icons.manage_search_rounded),
          label: const Text('Analyse Case'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() => _reviewing = false),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Back to the form'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
        ),
      ],
    );
  }

  // ---- Form ----

  Widget _form(BuildContext context) {
    final errors = _showErrors ? _case.validate() : const <String, String>{};
    final rows = _case.summary();
    String status(String section) {
      final recorded = [
        for (final (s, _, v) in rows)
          if (s == section &&
              v != 'Not recorded' &&
              v != 'Not assessed' &&
              !v.startsWith('Unknown'))
            v,
      ];
      if (errors.keys.any((f) => _sectionOf[f] == section)) {
        return 'Check the highlighted value';
      }
      return recorded.isEmpty ? 'Nothing recorded' : recorded.join(' · ');
    }

    Widget field(String id, String label,
            {String? unit, String? helper, bool decimal = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            key: ValueKey('cf-$id'),
            controller: _text[id],
            onChanged: (v) => _setText(id, v),
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            decoration: InputDecoration(
              labelText: label,
              suffixText: unit,
              helperText: helper,
              helperMaxLines: 2,
              errorText: errors[id],
              errorMaxLines: 2,
              border: const OutlineInputBorder(),
            ),
          ),
        );

    Widget sub(String t) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(t,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.primaryNavy, fontWeight: FontWeight.w600)),
        );

    Widget section(String id, IconData icon, List<Widget> children) => _Section(
          id: id,
          icon: icon,
          status: status(id),
          hasError: errors.keys.any((f) => _sectionOf[f] == id),
          open: _open.contains(id),
          onToggle: () => setState(
              () => _open.contains(id) ? _open.remove(id) : _open.add(id)),
          children: children,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(_basic, Icons.child_care_outlined, [
          sub('Gestational age'),
          RadioChoiceGroup<GaStatus>(
            horizontal: true,
            value: _case.gaStatus,
            onChanged: (v) => setState(() => _case.gaStatus = v),
            options: const [
              ChoiceOption(GaStatus.known, 'Known'),
              ChoiceOption(GaStatus.uncertain, 'Uncertain'),
              ChoiceOption(GaStatus.notRecorded, 'Not recorded'),
            ],
          ),
          if (_case.gaStatus == GaStatus.known) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: field(CaseField.gaWeeks, 'Completed weeks',
                        unit: 'wk', helper: '22–44')),
                const SizedBox(width: 12),
                Expanded(
                    child: field(CaseField.gaDays, '+ days (optional)',
                        unit: 'd', helper: '0–6')),
              ],
            ),
          ],
          const SizedBox(height: 8),
          field(CaseField.birthWeightKg, 'Birth weight (optional)',
              unit: 'kg', helper: 'e.g. 2.4 · 0.3–6 kg', decimal: true),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: field(CaseField.age, 'Age of baby (optional)',
                      helper: _case.ageUnit == AgeUnit.hours
                          ? '0–720 hours'
                          : '0–30 days')),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SegmentedButton<AgeUnit>(
                  key: const ValueKey('cf-ageUnit'),
                  segments: [
                    for (final u in AgeUnit.values)
                      ButtonSegment(value: u, label: Text(u.label)),
                  ],
                  selected: {_case.ageUnit},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _case.ageUnit = s.single),
                ),
              ),
            ],
          ),
        ]),
        section(_temperature, Icons.thermostat_outlined, [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: field(CaseField.temperature, 'Temperature (optional)',
                    helper: 'Recorded as measured; not classified here',
                    decimal: true),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SegmentedButton<TemperatureUnit>(
                  segments: [
                    for (final u in TemperatureUnit.values)
                      ButtonSegment(value: u, label: Text(u.label)),
                  ],
                  selected: {_case.temperatureUnit},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      setState(() => _case.temperatureUnit = s.single),
                ),
              ),
            ],
          ),
        ]),
        section(_respiratory, Icons.air_rounded, [
          field(CaseField.rr, 'Respiratory rate (optional)',
              unit: 'breaths/min', helper: '0–150'),
          sub('Signs of respiratory distress'),
          RadioChoiceGroup<SignsStatus>(
            value: _case.rdStatus,
            onChanged: (v) => setState(() => _case.rdStatus = v),
            options: [
              for (final s in SignsStatus.values) ChoiceOption(s, s.label),
            ],
          ),
          if (_case.rdStatus == SignsStatus.present)
            CheckList<String>(
              items: [for (final s in rdFormSigns) (s.name, s.label)],
              selected: _case.rdSigns,
              onChanged: (v) => setState(() => _case.rdSigns
                ..clear()
                ..addAll(v)),
            ),
          CheckList<String>(
            items: [(rdEmergencyKey, qRdEmergency.question)],
            selected: {if (_case.rdEmergency) rdEmergencyKey},
            onChanged: (v) =>
                setState(() => _case.rdEmergency = v.contains(rdEmergencyKey)),
          ),
        ]),
        section(_jaundice, Icons.wb_sunny_outlined, [
          sub('Jaundice present?'),
          RadioChoiceGroup<YesNoUnknown>(
            horizontal: true,
            value: _case.jaundice,
            onChanged: (v) => setState(() => _case.jaundice = v),
            options: [
              for (final v in YesNoUnknown.values)
                ChoiceOption(
                    v, v == YesNoUnknown.unknown ? 'Unknown' : v.label),
            ],
          ),
          if (_case.jaundicePresent) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const ValueKey('cf-kramer'),
              initialValue: _case.kramer,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Extent (Kramer zone)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Not assessed')),
                for (final z in KramerZone.values)
                  DropdownMenuItem(
                    value: z.name,
                    child: Text('${z.number} · ${z.label} (≈${z.approxTsb})',
                        overflow: TextOverflow.ellipsis),
                  ),
                const DropdownMenuItem(
                    value: kramerUnsure,
                    child: Text('Unsure about visual assessment')),
              ],
              onChanged: (v) => setState(() => _case.kramer = v),
            ),
            if (_case.asksBefore24h) ...[
              sub(qJaundiceBefore24h.question),
              RadioChoiceGroup<YesNoUnknown>(
                horizontal: true,
                value: _case.before24h,
                onChanged: (v) => setState(() => _case.before24h = v),
                options: [
                  for (final v in YesNoUnknown.values)
                    ChoiceOption(
                        v, v == YesNoUnknown.unknown ? 'Unknown' : v.label),
                ],
              ),
            ],
            sub('Signs of acute bilirubin encephalopathy (ABE)'),
            CheckList<String>(
              items: _items(qJaundiceAbe.options),
              selected: _case.abe,
              onChanged: (v) => setState(() => _case.abe
                ..clear()
                ..addAll(v)),
            ),
            sub('Abnormal posturing and related signs'),
            CheckList<String>(
              items: _items(qJaundicePosture.options),
              selected: _case.posture,
              onChanged: (v) => setState(() => _case.posture
                ..clear()
                ..addAll(v)),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: field(CaseField.tcb, 'TcB (optional)',
                        unit: 'mg/dL', decimal: true)),
                const SizedBox(width: 12),
                Expanded(
                    child: field(CaseField.tsb, 'TSB (optional)',
                        unit: 'mg/dL', decimal: true)),
              ],
            ),
          ],
        ]),
        section(_other, Icons.playlist_add_check_rounded, [
          field(CaseField.bg, 'Blood glucose (optional)',
              unit: 'mg/dL', helper: '0–600'),
          sub('Hypoglycemia: whom to screen'),
          CheckList<String>(
            items: _items(hypoRiskOptions),
            selected: _case.hypoRisks,
            onChanged: (v) => setState(() => _case.hypoRisks
              ..clear()
              ..addAll(v)),
          ),
          sub('Sepsis: red flags'),
          CheckList<String>(
            items: _items(qSepsisRed.options),
            selected: _case.sepsisRed,
            onChanged: (v) => setState(() => _case.sepsisRed
              ..clear()
              ..addAll(v)),
          ),
          sub('Sepsis: yellow signs'),
          CheckList<String>(
            items: _items(qSepsisYellow.options),
            selected: _case.sepsisYellow,
            onChanged: (v) => setState(() => _case.sepsisYellow
              ..clear()
              ..addAll(v)),
          ),
          sub('Post asphyxia: identify risk'),
          CheckList<String>(
            items: _items(qPaRisk.options),
            selected: _case.paRisk,
            onChanged: (v) => setState(() => _case.paRisk
              ..clear()
              ..addAll(v)),
          ),
        ]),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('case-review-structured'),
          onPressed: _review,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Review case'),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
        ),
      ],
    );
  }
}

/// Collapsible form section; the header shows what is recorded inside.
class _Section extends StatelessWidget {
  const _Section({
    required this.id,
    required this.icon,
    required this.status,
    required this.hasError,
    required this.open,
    required this.onToggle,
    required this.children,
  });

  final String id;
  final IconData icon;
  final String status;
  final bool hasError;
  final bool open;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: '$id, $status',
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('cs-$id'),
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(
                    children: [
                      Icon(icon, color: AppTheme.primaryNavy),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(id,
                                style: text.titleMedium?.copyWith(
                                    color: AppTheme.primaryNavy,
                                    fontWeight: FontWeight.w700)),
                            Text(
                              status,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall?.copyWith(
                                  color: hasError
                                      ? scheme.error
                                      : AppTheme.mutedText),
                            ),
                          ],
                        ),
                      ),
                      Icon(open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
        ],
      ),
    );
  }
}
