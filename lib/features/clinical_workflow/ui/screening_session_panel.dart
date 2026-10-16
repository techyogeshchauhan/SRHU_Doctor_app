import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/repositories/screening_sync_repository.dart';
import '../../condition_selection/domain/neonatal_condition.dart';

class AvailableDiseaseCount extends StatelessWidget {
  const AvailableDiseaseCount({super.key, this.showListed = false});
  final bool showListed;

  @override
  Widget build(BuildContext context) => Text(
        '$availableDiseaseCount diseases available'
        '${showListed ? ' · $listedConditionCount care areas listed' : ''}',
        key: const ValueKey('available-disease-count'),
        style: const TextStyle(
            fontSize: 12,
            color: AppTheme.primaryBlue,
            fontWeight: FontWeight.w600),
      );
}

String _diseaseTitle(String code) =>
    conditionDefinitions
        .where((d) => diseaseCodeOf(d.id) == code)
        .firstOrNull
        ?.title ??
    code;

/// Only this small panel ticks. The clinical form, engine and PDF viewer do
/// not rebuild every second, and elapsed time comes from saved timestamps.
class ScreeningSessionPanel extends ConsumerStatefulWidget {
  const ScreeningSessionPanel({super.key, required this.diseaseCodes});
  final Set<String> diseaseCodes;

  @override
  ConsumerState<ScreeningSessionPanel> createState() =>
      _ScreeningSessionPanelState();
}

class _ScreeningSessionPanelState extends ConsumerState<ScreeningSessionPanel> {
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(screeningTimingsProvider);
    final repo = ref.read(screeningSyncRepositoryProvider);
    final timings = repo.activeTimings(widget.diseaseCodes);
    final completed = timings.length == widget.diseaseCodes.length &&
        timings.isNotEmpty &&
        timings.every((t) => t.isCompleted);
    final start = timings.isEmpty
        ? null
        : timings
            .map((t) => t.startedAt)
            .reduce((a, b) => a.isBefore(b) ? a : b);
    final end = completed
        ? timings
            .map((t) => t.completedAt!)
            .reduce((a, b) => a.isAfter(b) ? a : b)
        : repo.currentTime;
    final elapsed = start == null ? Duration.zero : end.difference(start);
    if (timings.any((t) => t.isRunning)) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Wrap(spacing: 16, runSpacing: 4, children: [
          Text('Screening time',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy)),
          AvailableDiseaseCount(),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
              child: Text(
                  widget.diseaseCodes.length == 1
                      ? _diseaseTitle(widget.diseaseCodes.single)
                      : '${widget.diseaseCodes.length} selected diseases',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(
              '${completed ? 'Time taken: ' : ''}'
              '${formatScreeningDuration(elapsed)}',
              key: const ValueKey('screening-elapsed-time'),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryNavy)),
        ]),
      ]),
    );
  }
}

/// Timing-only history is retained on this device after reset and restart.
class ScreeningHistoryCard extends ConsumerWidget {
  const ScreeningHistoryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(screeningTimingsProvider);
    final completed = ref
        .read(screeningSyncRepositoryProvider)
        .timings
        .where((t) => t.isCompleted)
        .toList();
    if (completed.isEmpty) return const SizedBox.shrink();
    return Card(
      key: const ValueKey('screening-history-card'),
      margin: const EdgeInsets.symmetric(vertical: 12),
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppTheme.dividerColor),
      ),
      child: ExpansionTile(
        // Override the shared zero ListTile padding and ExpansionTile's
        // default top/bottom borders; the card owns the single outer border.
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppTheme.primaryBlue,
        collapsedIconColor: AppTheme.primaryBlue,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.tint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.history_rounded,
              size: 20, color: AppTheme.primaryBlue),
        ),
        title: const Text('Previous screenings',
            style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryNavy)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text('${completed.length} completed · Saved on this device',
              style: const TextStyle(
                  fontSize: 12, height: 1.4, color: AppTheme.mutedText)),
        ),
        children: [
          for (var i = 0; i < completed.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _ScreeningHistoryEntry(number: i + 1, timing: completed[i]),
          ],
        ],
      ),
    );
  }
}

class _ScreeningHistoryEntry extends StatelessWidget {
  const _ScreeningHistoryEntry({required this.number, required this.timing});
  final int number;
  final ScreeningTiming timing;

  @override
  Widget build(BuildContext context) {
    final title = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$number.',
          key: ValueKey('screening-history-index-${timing.id}'),
          style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue)),
      const SizedBox(width: 6),
      Expanded(
          child: Text(_diseaseTitle(timing.diseaseCode),
              style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryNavy))),
    ]);
    final duration = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: AppTheme.tint, borderRadius: BorderRadius.circular(8)),
      child: Text('Time taken: ${formatScreeningDuration(timing.duration!)}',
          style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryBlue)),
    );
    return Container(
      key: ValueKey('screening-history-${timing.id}'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.scaffoldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 400 ||
              MediaQuery.textScalerOf(context).scale(14) > 18;
          if (stacked) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 8), duration]);
          }
          return Row(children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            duration,
          ]);
        }),
        const SizedBox(height: 12),
        Wrap(spacing: 24, runSpacing: 12, children: [
          _ScreeningTimestamp(label: 'Started:', time: timing.startedAt),
          _ScreeningTimestamp(label: 'Completed:', time: timing.completedAt!),
        ]),
      ]),
    );
  }
}

class _ScreeningTimestamp extends StatelessWidget {
  const _ScreeningTimestamp({required this.label, required this.time});
  final String label;
  final DateTime time;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.mutedText)),
          const SizedBox(height: 3),
          Text(DateFormat('dd MMM yyyy · HH:mm:ss').format(time.toLocal()),
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: AppTheme.bodyText)),
        ],
      );
}
