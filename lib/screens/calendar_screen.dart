import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../models/period_entry.dart';
import '../services/cycle_calculator.dart';
import 'today_screen.dart';

const _postpartumColor = Color(0xFF8A6652);
const _postpartumBackground = Color(0xFFE7DDD7);

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.controller.profile!;
    final isPostpartum = profile.isPostpartumOn(DateTime.now());
    final pregnancyActive = profile.isPregnant && !isPostpartum;
    final calculator = const CycleCalculator();
    final today = DateTime.now();
    final estimatedLength = calculator.estimatedCycleLength(
      periodStarts: widget.controller.periodStarts,
      configuredLength: profile.cycleLength,
    );
    final monthInsights = calculator.insightsForMonth(
      month: _visibleMonth,
      periodStarts: widget.controller.periodStarts,
      expectedCycleLength: profile.cycleLength,
    );
    final daysInMonth = DateUtils.getDaysInMonth(
      _visibleMonth.year,
      _visibleMonth.month,
    );
    final firstWeekday = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
    ).weekday;
    final leading = firstWeekday - 1;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your calendar',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              profile.isPregnant
                  ? isPostpartum
                        ? 'Postpartum mode. Log the first real period when your cycle returns.'
                        : 'Pregnancy mode is on. Period logging is paused until the expected due date.'
                  : 'Tap a date to add or manage a period start.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: pregnancyActive ? null : () => _addPeriodDate(context),
              icon: const Icon(Icons.add_rounded),
              label: Text(
                isPostpartum
                    ? 'Log first postpartum period'
                    : 'Add period date',
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => _moveMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          DateFormat.yMMMM().format(_visibleMonth),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Next month',
                        onPressed: () => _moveMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      _WeekLabel('M'),
                      _WeekLabel('T'),
                      _WeekLabel('W'),
                      _WeekLabel('T'),
                      _WeekLabel('F'),
                      _WeekLabel('S'),
                      _WeekLabel('S'),
                    ],
                  ),
                  const SizedBox(height: 5),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 5,
                          crossAxisSpacing: 3,
                        ),
                    itemCount: leading + daysInMonth,
                    itemBuilder: (context, index) {
                      if (index < leading) return const SizedBox.shrink();
                      final day = index - leading + 1;
                      final date = DateTime(
                        _visibleMonth.year,
                        _visibleMonth.month,
                        day,
                      );
                      final recordedEntry = _recordedEntryFor(date);
                      final calculatedSnapshot = profile.isPregnant
                          ? null
                          : calculator.calculate(
                              onDate: date,
                              lastPeriodStart: profile.lastPeriodStart,
                              cycleLength: profile.cycleLength,
                              periodLength: profile.periodLength,
                              periodStarts: widget.controller.periodStarts,
                              nextPeriodDueDate: profile.nextPeriodDueDate,
                            );
                      final cycleEntry = calculatedSnapshot == null
                          ? null
                          : _entryStartingOn(
                              calculatedSnapshot.currentCycleStart,
                            );
                      final phase = profile.isPregnant
                          ? null
                          : recordedEntry != null
                          ? CyclePhase.menstruation
                          : calculatedSnapshot!.phase ==
                                    CyclePhase.menstruation &&
                                cycleEntry?.endDate != null &&
                                date.isAfter(cycleEntry!.endDate!)
                          ? CyclePhase.follicular
                          : calculatedSnapshot.phase;
                      final isToday = DateUtils.isSameDay(date, today);
                      final isDueDate = DateUtils.isSameDay(
                        date,
                        profile.nextPeriodDueDate,
                      );
                      final isPregnancyDueDate =
                          profile.isPregnant &&
                          DateUtils.isSameDay(date, profile.dueDate);
                      final isPostpartumDay = profile.isPostpartumDate(
                        date,
                        through: today,
                      );
                      final isLoggedStart = widget.controller.periodStarts.any(
                        (logged) => DateUtils.isSameDay(logged, date),
                      );
                      return _DayCell(
                        day: day,
                        phase: phase,
                        isToday: isToday,
                        isLoggedStart: isLoggedStart,
                        isRecordedPeriodDay: recordedEntry != null,
                        isDueDate: isDueDate,
                        isPregnancyDueDate: isPregnancyDueDate,
                        isPostpartumDay: isPostpartumDay,
                        onTap:
                            date.isAfter(today) ||
                                (pregnancyActive && !isLoggedStart)
                            ? null
                            : () => _manageDate(
                                context,
                                date,
                                isLoggedStart,
                                recordedEntry,
                              ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!profile.isPregnant) ...[
              Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  ...CyclePhase.values.map(
                    (phase) => _LegendItem(phase: phase),
                  ),
                  if (profile.nextPeriodDueDate != null) const _DueDateLegend(),
                  if (profile.postpartumStartedOn != null &&
                      profile.postpartumEndedOn != null)
                    const _PostpartumLegend(),
                ],
              ),
              const SizedBox(height: 24),
            ] else ...[
              Wrap(
                spacing: 14,
                runSpacing: 10,
                children: [
                  if (isPostpartum) const _PostpartumLegend(),
                  const _PregnancyDueDateLegend(),
                ],
              ),
              const SizedBox(height: 24),
            ],
            _MonthSummaryCard(
              month: _visibleMonth,
              isPregnant: profile.isPregnant,
              isPostpartum: isPostpartum,
              configuredLength: profile.cycleLength,
              estimatedLength: estimatedLength,
              hasHistory: widget.controller.periodStarts.length > 1,
              insights: monthInsights,
              periodEntries: widget.controller.periodEntries,
              usualPeriodLength: profile.periodLength,
              nextPeriodDueDate: profile.nextPeriodDueDate,
              today: today,
            ),
          ],
        ),
      ),
    );
  }

  void _moveMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  PeriodEntry? _recordedEntryFor(DateTime date) {
    for (final entry in widget.controller.periodEntries) {
      if (entry.contains(date)) return entry;
    }
    return null;
  }

  PeriodEntry? _entryStartingOn(DateTime date) {
    for (final entry in widget.controller.periodEntries) {
      if (DateUtils.isSameDay(entry.startDate, date)) return entry;
    }
    return null;
  }

  Future<void> _addPeriodDate(BuildContext context) async {
    final now = DateTime.now();
    final profile = widget.controller.profile!;
    final isPostpartum = profile.isPostpartumOn(now);
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: isPostpartum ? profile.dueDate! : DateTime(1900),
      lastDate: now,
      helpText: isPostpartum
          ? 'First period after pregnancy'
          : 'Choose the first day of the period',
    );
    if (picked != null) await widget.controller.logPeriodStart(picked);
  }

  Future<void> _manageDate(
    BuildContext context,
    DateTime date,
    bool isLoggedStart,
    PeriodEntry? recordedEntry,
  ) async {
    if (!isLoggedStart && recordedEntry == null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.water_drop_outlined),
          title: const Text('Add period start?'),
          content: Text(
            '${DateFormat.yMMMMd().format(date)} will be recorded as Day 1.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Add date'),
            ),
          ],
        ),
      );
      if (confirmed == true) await widget.controller.logPeriodStart(date);
      return;
    }

    final entry =
        recordedEntry ??
        widget.controller.periodEntries.firstWhere(
          (candidate) => DateUtils.isSameDay(candidate.startDate, date),
        );
    final now = DateTime.now();
    final effectiveEnd =
        entry.endDate ??
        entry.startDate.add(
          Duration(days: widget.controller.profile!.periodLength - 1),
        );
    final nextEnd = effectiveEnd.add(const Duration(days: 1));
    final canAddDay = !nextEnd.isAfter(now);
    final action = await showModalBottomSheet<_CalendarPeriodAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(DateFormat.yMMMMd().format(entry.startDate)),
              subtitle: Text(
                entry.endDate == null
                    ? 'Last bleeding day not recorded'
                    : '${entry.durationDays} bleeding ${entry.durationDays == 1 ? 'day' : 'days'} recorded',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: Text(
                entry.endDate == null
                    ? 'Set last bleeding day'
                    : 'Change last bleeding day',
              ),
              onTap: () =>
                  Navigator.pop(sheetContext, _CalendarPeriodAction.editEnd),
            ),
            ListTile(
              enabled: canAddDay,
              leading: const Icon(Icons.add_circle_outline_rounded),
              title: const Text('Add one more day'),
              subtitle: canAddDay
                  ? Text(
                      'Last day becomes ${DateFormat.yMMMd().format(nextEnd)}',
                    )
                  : const Text('The next day is in the future'),
              onTap: canAddDay
                  ? () => Navigator.pop(
                      sheetContext,
                      _CalendarPeriodAction.addDay,
                    )
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Change date'),
              onTap: () =>
                  Navigator.pop(sheetContext, _CalendarPeriodAction.edit),
            ),
            ListTile(
              enabled: widget.controller.periodStarts.length > 1,
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Delete entry'),
              subtitle: widget.controller.periodStarts.length == 1
                  ? const Text('Keep at least one period start')
                  : null,
              onTap: widget.controller.periodStarts.length > 1
                  ? () => Navigator.pop(
                      sheetContext,
                      _CalendarPeriodAction.delete,
                    )
                  : null,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == _CalendarPeriodAction.delete) {
      await widget.controller.deletePeriodStart(entry.startDate);
      return;
    }
    if (action == _CalendarPeriodAction.editEnd) {
      final estimatedEnd = entry.startDate.add(
        Duration(days: widget.controller.profile!.periodLength - 1),
      );
      final initialEnd = entry.endDate ?? estimatedEnd;
      final pickedEnd = await showDatePicker(
        context: context,
        initialDate: initialEnd.isAfter(now) ? now : initialEnd,
        firstDate: entry.startDate,
        lastDate: now,
        helpText: 'Choose the last bleeding day',
      );
      if (pickedEnd != null) {
        await widget.controller.updatePeriodEnd(entry.startDate, pickedEnd);
      }
      return;
    }
    if (action == _CalendarPeriodAction.addDay) {
      if (!nextEnd.isAfter(now)) {
        await widget.controller.updatePeriodEnd(entry.startDate, nextEnd);
      }
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: entry.startDate,
      firstDate:
          widget.controller.profile!.postpartumEndedOn != null &&
              DateUtils.isSameDay(
                entry.startDate,
                widget.controller.profile!.postpartumEndedOn,
              )
          ? widget.controller.profile!.postpartumStartedOn!
          : DateTime(1900),
      lastDate: now,
      helpText: 'Change period start date',
    );
    if (picked != null) {
      await widget.controller.updatePeriodStart(entry.startDate, picked);
    }
  }
}

enum _CalendarPeriodAction { edit, editEnd, addDay, delete }

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.month,
    required this.isPregnant,
    required this.isPostpartum,
    required this.configuredLength,
    required this.estimatedLength,
    required this.hasHistory,
    required this.insights,
    required this.periodEntries,
    required this.usualPeriodLength,
    required this.nextPeriodDueDate,
    required this.today,
  });

  final DateTime month;
  final bool isPregnant;
  final bool isPostpartum;
  final int configuredLength;
  final int estimatedLength;
  final bool hasHistory;
  final List<CycleIntervalInsight> insights;
  final List<PeriodEntry> periodEntries;
  final int usualPeriodLength;
  final DateTime? nextPeriodDueDate;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final hasRangeNotice = insights.any(
      (insight) => insight.outsideCommonAdultRange,
    );
    final color = hasRangeNotice
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF9A5719);
    final background = hasRangeNotice
        ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: .55)
        : const Color(0xFFFFF4E8);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPregnant
                ? Icons.pause_circle_outline_rounded
                : hasRangeNotice
                ? Icons.info_outline_rounded
                : Icons.auto_awesome_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DateFormat.MMMM().format(month)} summary',
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  _summaryText(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: hasRangeNotice
                        ? Theme.of(context).colorScheme.onErrorContainer
                        : const Color(0xFF6F4219),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _summaryText() {
    if (isPregnant) {
      return isPostpartum
          ? 'Postpartum mode is active. Cycle estimates remain paused because periods return at different times after pregnancy. Log the first real period to resume tracking.'
          : 'Pregnancy mode is active. Period logging and cycle estimates are paused until the expected due date.';
    }
    final estimateSource = hasHistory
        ? 'recent recorded intervals'
        : 'your $configuredLength-day setting';
    final estimateNote =
        'Estimated coloring uses a $estimatedLength-day cycle from $estimateSource.';
    final messages = <String>[
      if (insights.isEmpty) 'No period start was recorded this month.',
      ...insights.map(_messageFor),
      ...periodEntries
          .where(
            (entry) =>
                entry.startDate.year == month.year &&
                entry.startDate.month == month.month,
          )
          .map(_durationMessageFor),
      if (nextPeriodDueDate?.year == month.year &&
          nextPeriodDueDate?.month == month.month)
        _dueDateMessage(nextPeriodDueDate!),
      estimateNote,
    ];
    return messages.join('\n\n');
  }

  String _dueDateMessage(DateTime dueDate) {
    final date = DateFormat.yMMMMd().format(dueDate);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final current = DateTime(today.year, today.month, today.day);
    if (due.isBefore(current)) {
      final days = current.difference(due).inDays;
      return 'You expected your period on $date. That was $days ${days == 1 ? 'day' : 'days'} ago; log the actual start or update this date.';
    }
    return 'You set your next period due date to $date. This guides the estimate but does not guarantee when bleeding will start.';
  }

  String _messageFor(CycleIntervalInsight insight) {
    final date = DateFormat.MMMd().format(insight.start);
    if (insight.timing == CycleTiming.firstRecorded) {
      return 'Period recorded on $date. Add the previous start date to compare its timing.';
    }
    final actual = insight.actualLength!;
    final difference = insight.differenceFromExpected.abs();
    final timing = switch (insight.timing) {
      CycleTiming.early =>
        'started $difference ${difference == 1 ? 'day' : 'days'} earlier',
      CycleTiming.late =>
        'started $difference ${difference == 1 ? 'day' : 'days'} later',
      CycleTiming.onExpectedDay => 'matched your setting',
      CycleTiming.firstRecorded => '',
    };
    final rangeNote = insight.outsideCommonAdultRange
        ? ' This is outside the common 21–35-day adult range described by ACOG and the NHS. If it repeats or your usual pattern has changed, consider talking with a healthcare professional.'
        : '';
    return 'Period on $date: $timing ($actual-day cycle versus your $configuredLength-day setting).$rangeNote';
  }

  String _durationMessageFor(PeriodEntry entry) {
    final end = entry.endDate;
    if (end == null) {
      return 'Last bleeding day is not recorded, so the usual $usualPeriodLength-day duration is estimated.';
    }
    final duration = entry.durationDays!;
    final difference = duration - usualPeriodLength;
    final comparison = switch (difference.compareTo(0)) {
      > 0 =>
        '${difference.abs()} ${difference.abs() == 1 ? 'day' : 'days'} longer than usual',
      < 0 =>
        '${difference.abs()} ${difference.abs() == 1 ? 'day' : 'days'} shorter than usual',
      _ => 'matches your usual length',
    };
    final range =
        '${DateFormat.MMMd().format(entry.startDate)}–${DateFormat.MMMd().format(end)}';
    final guidance = duration > 7
        ? ' ACOG describes bleeding longer than 7 days as unusual; consider discussing it with a healthcare professional.'
        : '';
    return 'Bleeding recorded $range: $duration days ($comparison).$guidance';
  }
}

class _WeekLabel extends StatelessWidget {
  const _WeekLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.phase,
    required this.isToday,
    required this.isLoggedStart,
    required this.isRecordedPeriodDay,
    required this.isDueDate,
    required this.isPregnancyDueDate,
    required this.isPostpartumDay,
    required this.onTap,
  });

  final int day;
  final CyclePhase? phase;
  final bool isToday;
  final bool isLoggedStart;
  final bool isRecordedPeriodDay;
  final bool isDueDate;
  final bool isPregnancyDueDate;
  final bool isPostpartumDay;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isPostpartumDay || isPregnancyDueDate
        ? _postpartumColor
        : phase == null
        ? Theme.of(context).colorScheme.outline
        : colorForPhase(phase!);
    return Material(
      color: isPostpartumDay
          ? _postpartumBackground
          : phase == null
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : color.withValues(alpha: isRecordedPeriodDay ? .24 : .10),
      shape: CircleBorder(
        side: isToday || isPregnancyDueDate
            ? BorderSide(color: color, width: isPregnancyDueDate ? 2.5 : 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$day',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: isToday || isRecordedPeriodDay
                    ? FontWeight.w900
                    : FontWeight.w600,
              ),
            ),
            if (isLoggedStart)
              Positioned(
                bottom: 5,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (isDueDate && !isLoggedStart)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
            if (isPregnancyDueDate)
              Positioned(
                bottom: 4,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _postpartumColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.phase});

  final CyclePhase phase;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: colorForPhase(phase),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Text(phase.label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _DueDateLegend extends StatelessWidget {
  const _DueDateLegend();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text('Due date', style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _PostpartumLegend extends StatelessWidget {
  const _PostpartumLegend();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: _postpartumColor,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Text('Postpartum days', style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _PregnancyDueDateLegend extends StatelessWidget {
  const _PregnancyDueDateLegend();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _postpartumColor, width: 2),
        ),
      ),
      const SizedBox(width: 6),
      Text('Expected due date', style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
