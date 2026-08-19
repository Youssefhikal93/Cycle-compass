import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../models/intercourse_entry.dart';
import '../models/life_stage_entry.dart';
import '../models/period_entry.dart';
import '../models/user_profile.dart';
import '../services/clock.dart';
import '../services/cycle_calculator.dart';
import 'today_screen.dart';

const _pregnancyColor = Color(0xFF8D4D72);
const _postpartumColor = Color(0xFF8A6652);
const _protectedSexColor = Color(0xFF26715A);
const _unprotectedSexColor = Color(0xFFB14962);
const _ovulationFlowerColor = Color(0xFFD49A19);

Color _pregnancyBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF4A3040)
    : const Color(0xFFF2DFEA);

Color _postpartumBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF41352C)
    : const Color(0xFFE7DDD7);

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
    final now = appNow();
    _visibleMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.controller.profile!;
    final isPostpartum = profile.isPostpartumOn(appNow());
    final pregnancyActive = profile.isPregnant && !isPostpartum;
    final calculator = const CycleCalculator();
    final today = appNow();
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
    final monthDays = List.generate(daysInMonth, (index) {
      final date = DateTime(_visibleMonth.year, _visibleMonth.month, index + 1);
      return _calendarDayState(date, profile, calculator, today);
    });
    final legendItems = _legendItems(monthDays);
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
                        ? 'Postpartum mode. Tap a date to record sex or log the first real period.'
                        : 'Pregnancy mode is on. Tap a date to record sex; period logging is paused.'
                  : 'Tap a date to record sex or manage a period entry.',
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
            GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 150) return;
                _moveMonth(velocity < 0 ? 1 : -1);
              },
              child: Container(
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
                        if (!DateUtils.isSameMonth(_visibleMonth, today))
                          IconButton(
                            tooltip: 'Back to this month',
                            onPressed: () => setState(
                              () => _visibleMonth = DateTime(
                                today.year,
                                today.month,
                              ),
                            ),
                            icon: const Icon(Icons.today_rounded),
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
                        final dayState = monthDays[index - leading];
                        return _DayCell(
                          dayState: dayState,
                          onTap: dayState.date.isAfter(today)
                              ? null
                              : () => _openDayEditor(
                                  context,
                                  dayState,
                                  pregnancyActive,
                                ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (legendItems.isNotEmpty) ...[
              Wrap(spacing: 14, runSpacing: 10, children: legendItems),
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

  _CalendarDayState _calendarDayState(
    DateTime date,
    UserProfile profile,
    CycleCalculator calculator,
    DateTime today,
  ) {
    final lifeStageType = _lifeStageTypeOn(date, profile, today);
    final recordedEntry = _recordedEntryFor(date);
    final phase = _phaseOn(date, profile, calculator, lifeStageType);
    final events = (
      period: recordedEntry,
      intercourse: widget.controller.intercourseEntryOn(date),
      lifeStage: lifeStageType,
    );
    return _CalendarDayState(
      date: date,
      phase: phase,
      events: events,
      markers: _markersFor(date, profile, today),
    );
  }

  _CalendarDayMarkers _markersFor(
    DateTime date,
    UserProfile profile,
    DateTime today,
  ) => (
    today: DateUtils.isSameDay(date, today),
    periodStart: widget.controller.periodStarts.any(
      (logged) => DateUtils.isSameDay(logged, date),
    ),
    periodDue: DateUtils.isSameDay(date, profile.nextPeriodDueDate),
    pregnancyDue:
        profile.isPregnant && DateUtils.isSameDay(date, profile.dueDate),
  );

  CyclePhase? _phaseOn(
    DateTime date,
    UserProfile profile,
    CycleCalculator calculator,
    LifeStageType? lifeStageType,
  ) {
    if (profile.isPregnant || lifeStageType != null) return null;
    final recordedEntry = _recordedEntryFor(date);
    if (recordedEntry != null) return CyclePhase.menstruation;
    final snapshot = calculator.calculate(
      onDate: date,
      lastPeriodStart: profile.lastPeriodStart,
      cycleLength: profile.cycleLength,
      periodLength: profile.periodLength,
      periodStarts: widget.controller.periodStarts,
      nextPeriodDueDate: profile.nextPeriodDueDate,
    );
    final cycleEntry = _entryStartingOn(snapshot.currentCycleStart);
    if (snapshot.phase == CyclePhase.menstruation &&
        cycleEntry?.endDate != null &&
        date.isAfter(cycleEntry!.endDate!)) {
      return CyclePhase.follicular;
    }
    return snapshot.phase;
  }

  LifeStageType? _lifeStageTypeOn(
    DateTime date,
    UserProfile profile,
    DateTime today,
  ) {
    for (final entry in widget.controller.lifeStageEntries) {
      if (entry.contains(date)) return entry.type;
    }
    if (profile.isPostpartumDate(date, through: today)) {
      return LifeStageType.postpartum;
    }
    if (_isActivePregnancyDate(date, profile)) {
      return LifeStageType.pregnancy;
    }
    return null;
  }

  bool _isActivePregnancyDate(DateTime date, UserProfile profile) {
    final pregnancyStart = profile.pregnancyStartedOn;
    final dueDate = profile.dueDate;
    if (!profile.isPregnant || pregnancyStart == null || dueDate == null) {
      return false;
    }
    return !date.isBefore(pregnancyStart) && date.isBefore(dueDate);
  }

  List<Widget> _legendItems(List<_CalendarDayState> monthDays) {
    final phases = monthDays
        .map((day) => day.phase)
        .whereType<CyclePhase>()
        .toSet();
    return [
      for (final phase in CyclePhase.values)
        if (phases.contains(phase)) _LegendItem(phase: phase),
      if (monthDays.any((day) => day.isLoggedStart)) const _PeriodStartLegend(),
      for (final status in ProtectionStatus.values)
        if (monthDays.any(
          (day) => day.intercourseEntry?.protectionStatus == status,
        ))
          _IntercourseLegend(protectionStatus: status),
      for (final stageType in LifeStageType.values)
        if (monthDays.any((day) => day.lifeStageType == stageType))
          _LifeStageLegend(lifeStageType: stageType),
      if (monthDays.any((day) => day.isDueDate)) const _DueDateLegend(),
      if (monthDays.any((day) => day.isPregnancyDueDate))
        const _PregnancyDueDateLegend(),
    ];
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
    final now = appNow();
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

  Future<void> _openDayEditor(
    BuildContext context,
    _CalendarDayState dayState,
    bool pregnancyActive,
  ) async {
    final action = await showModalBottomSheet<_CalendarDayAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _CalendarDayEditorSheet(
        dayState: dayState,
        pregnancyActive: pregnancyActive,
      ),
    );
    if (!context.mounted || action == null) return;
    await _applyDayAction(context, dayState, action);
  }

  Future<void> _applyDayAction(
    BuildContext context,
    _CalendarDayState dayState,
    _CalendarDayAction action,
  ) async {
    switch (action) {
      case _CalendarDayAction.protectedSex:
        return widget.controller.saveIntercourseEntry(
          dayState.date,
          ProtectionStatus.protected,
        );
      case _CalendarDayAction.unprotectedSex:
        return widget.controller.saveIntercourseEntry(
          dayState.date,
          ProtectionStatus.unprotected,
        );
      case _CalendarDayAction.removeSex:
        return widget.controller.deleteIntercourseEntry(dayState.date);
      case _CalendarDayAction.addPeriod:
        return widget.controller.logPeriodStart(dayState.date);
      case _CalendarDayAction.managePeriod:
        final entry = _periodEntryFor(dayState);
        if (entry != null) await _managePeriodEntry(context, entry);
    }
  }

  PeriodEntry? _periodEntryFor(_CalendarDayState dayState) {
    final recordedEntry = dayState.recordedPeriodEntry;
    if (recordedEntry != null) return recordedEntry;
    for (final entry in widget.controller.periodEntries) {
      if (DateUtils.isSameDay(entry.startDate, dayState.date)) return entry;
    }
    return null;
  }

  Future<void> _managePeriodEntry(
    BuildContext context,
    PeriodEntry entry,
  ) async {
    final now = appNow();
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
    if (picked != null && context.mounted) {
      try {
        await widget.controller.updatePeriodStart(entry.startDate, picked);
      } on ArgumentError catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message?.toString() ?? 'Invalid date.')),
        );
      }
    }
  }
}

enum _CalendarPeriodAction { edit, editEnd, addDay, delete }

enum _CalendarDayAction {
  protectedSex,
  unprotectedSex,
  removeSex,
  addPeriod,
  managePeriod,
}

typedef _CalendarDayEvents = ({
  PeriodEntry? period,
  IntercourseEntry? intercourse,
  LifeStageType? lifeStage,
});

typedef _CalendarDayMarkers = ({
  bool today,
  bool periodStart,
  bool periodDue,
  bool pregnancyDue,
});

class _CalendarDayState {
  const _CalendarDayState({
    required this.date,
    required this.phase,
    required this.events,
    required this.markers,
  });

  final DateTime date;
  final CyclePhase? phase;
  final _CalendarDayEvents events;
  final _CalendarDayMarkers markers;

  int get day => date.day;
  PeriodEntry? get recordedPeriodEntry => events.period;
  IntercourseEntry? get intercourseEntry => events.intercourse;
  LifeStageType? get lifeStageType => events.lifeStage;
  bool get isToday => markers.today;
  bool get isLoggedStart => markers.periodStart;
  bool get isDueDate => markers.periodDue;
  bool get isPregnancyDueDate => markers.pregnancyDue;
  bool get hasPeriodEntry => recordedPeriodEntry != null || isLoggedStart;
}

class _CalendarDayEditorSheet extends StatelessWidget {
  const _CalendarDayEditorSheet({
    required this.dayState,
    required this.pregnancyActive,
  });

  final _CalendarDayState dayState;
  final bool pregnancyActive;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(DateFormat.yMMMMd().format(dayState.date)),
            subtitle: const Text('Add or update entries for this day'),
          ),
          const Divider(height: 1),
          for (final status in ProtectionStatus.values)
            _intercourseOption(context, status),
          if (dayState.intercourseEntry != null) _removeSexOption(context),
          const Divider(height: 1),
          _periodOption(context),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  Widget _intercourseOption(
    BuildContext context,
    ProtectionStatus protectionStatus,
  ) {
    final action = protectionStatus == ProtectionStatus.protected
        ? _CalendarDayAction.protectedSex
        : _CalendarDayAction.unprotectedSex;
    final title = protectionStatus == ProtectionStatus.protected
        ? 'Sex with protection'
        : 'Sex without protection';
    return ListTile(
      leading: Icon(
        _iconForProtection(protectionStatus),
        color: _colorForProtection(protectionStatus),
      ),
      title: Text(title),
      trailing: dayState.intercourseEntry?.protectionStatus == protectionStatus
          ? const Icon(Icons.check_rounded)
          : null,
      onTap: () => Navigator.pop(context, action),
    );
  }

  Widget _removeSexOption(BuildContext context) => ListTile(
    leading: const Icon(Icons.close_rounded),
    title: const Text('Remove sex entry'),
    onTap: () => Navigator.pop(context, _CalendarDayAction.removeSex),
  );

  Widget _periodOption(BuildContext context) => ListTile(
    enabled: dayState.hasPeriodEntry || !pregnancyActive,
    leading: const Icon(Icons.water_drop_outlined),
    title: Text(
      dayState.hasPeriodEntry ? 'Manage period entry' : 'Add period start',
    ),
    subtitle: pregnancyActive && !dayState.hasPeriodEntry
        ? const Text('Period logging is paused during pregnancy')
        : null,
    onTap: dayState.hasPeriodEntry
        ? () => Navigator.pop(context, _CalendarDayAction.managePeriod)
        : pregnancyActive
        ? null
        : () => Navigator.pop(context, _CalendarDayAction.addPeriod),
  );
}

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = hasRangeNotice
        ? Theme.of(context).colorScheme.error
        : isDark
        ? const Color(0xFFE5B87A)
        : const Color(0xFF9A5719);
    final background = hasRangeNotice
        ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: .55)
        : isDark
        ? const Color(0xFF3A2E1D)
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
                        : isDark
                        ? const Color(0xFFD9C1A0)
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
  const _DayCell({required this.dayState, required this.onTap});

  final _CalendarDayState dayState;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stageType = dayState.lifeStageType;
    final stageColor = stageType == null ? null : _colorForLifeStage(stageType);
    final color = stageColor ?? _dayCellColor(context, dayState);
    return Material(
      color: stageType == LifeStageType.pregnancy
          ? _pregnancyBackground(context)
          : stageType == LifeStageType.postpartum
          ? _postpartumBackground(context)
          : dayState.phase == null
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : color.withValues(
              alpha: dayState.recordedPeriodEntry != null ? .24 : .10,
            ),
      shape: CircleBorder(
        side: dayState.isToday || dayState.isPregnancyDueDate
            ? BorderSide(
                color: color,
                width: dayState.isPregnancyDueDate ? 2.5 : 2,
              )
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (dayState.phase == CyclePhase.ovulation)
              _ovulationFlowerMarker(),
            _dayNumber(context),
            if (dayState.isLoggedStart) _periodStartMarker(context),
            if (dayState.isDueDate && !dayState.isLoggedStart)
              _periodDueMarker(context),
            if (dayState.isPregnancyDueDate) _pregnancyDueMarker(),
            if (dayState.intercourseEntry != null) _intercourseMarker(),
          ],
        ),
      ),
    );
  }

  Widget _dayNumber(BuildContext context) => Text(
    '${dayState.day}',
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: dayState.isToday || dayState.recordedPeriodEntry != null
          ? FontWeight.w900
          : FontWeight.w600,
    ),
  );

  Widget _ovulationFlowerMarker() => Icon(
    Icons.local_florist_rounded,
    size: 30,
    color: _ovulationFlowerColor.withValues(alpha: .34),
  );

  Widget _periodStartMarker(BuildContext context) => Positioned(
    bottom: 5,
    child: Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
    ),
  );

  Widget _periodDueMarker(BuildContext context) => Positioned(
    top: 5,
    right: 5,
    child: Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
    ),
  );

  Widget _pregnancyDueMarker() => Positioned(
    bottom: 4,
    child: Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: _postpartumColor,
        shape: BoxShape.circle,
      ),
    ),
  );

  Widget _intercourseMarker() {
    final protectionStatus = dayState.intercourseEntry!.protectionStatus;
    return Positioned(
      top: 3,
      left: 3,
      child: Icon(
        _iconForProtection(protectionStatus),
        size: 12,
        color: _colorForProtection(protectionStatus),
      ),
    );
  }
}

Color _dayCellColor(BuildContext context, _CalendarDayState dayState) {
  if (dayState.isPregnancyDueDate) return _postpartumColor;
  final phase = dayState.phase;
  return phase == null
      ? Theme.of(context).colorScheme.outline
      : colorForPhase(phase);
}

Color _colorForLifeStage(LifeStageType lifeStageType) =>
    switch (lifeStageType) {
      LifeStageType.pregnancy => _pregnancyColor,
      LifeStageType.postpartum => _postpartumColor,
    };

Color _colorForProtection(ProtectionStatus protectionStatus) =>
    switch (protectionStatus) {
      ProtectionStatus.protected => _protectedSexColor,
      ProtectionStatus.unprotected => _unprotectedSexColor,
    };

IconData _iconForProtection(ProtectionStatus protectionStatus) =>
    switch (protectionStatus) {
      ProtectionStatus.protected => Icons.health_and_safety_outlined,
      ProtectionStatus.unprotected => Icons.favorite_outline_rounded,
    };

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.phase});

  final CyclePhase phase;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (phase == CyclePhase.ovulation)
        const Icon(
          Icons.local_florist_rounded,
          size: 14,
          color: _ovulationFlowerColor,
        )
      else
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
          color: Theme.of(context).colorScheme.surface,
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

class _PeriodStartLegend extends StatelessWidget {
  const _PeriodStartLegend();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Text('Period start', style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _IntercourseLegend extends StatelessWidget {
  const _IntercourseLegend({required this.protectionStatus});

  final ProtectionStatus protectionStatus;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        _iconForProtection(protectionStatus),
        size: 14,
        color: _colorForProtection(protectionStatus),
      ),
      const SizedBox(width: 6),
      Text(
        protectionStatus.label,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _LifeStageLegend extends StatelessWidget {
  const _LifeStageLegend({required this.lifeStageType});

  final LifeStageType lifeStageType;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _colorForLifeStage(lifeStageType),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        '${lifeStageType.label} days',
        style: Theme.of(context).textTheme.bodySmall,
      ),
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
          color: Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: _postpartumColor, width: 2),
        ),
      ),
      const SizedBox(width: 6),
      Text('Expected due date', style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
