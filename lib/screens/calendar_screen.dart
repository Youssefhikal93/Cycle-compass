import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../models/intercourse_entry.dart';
import '../models/life_stage_entry.dart';
import '../models/ovulation_test_entry.dart';
import '../models/period_entry.dart';
import '../models/user_profile.dart';
import '../services/clock.dart';
import '../services/cycle_calculator.dart';
import 'today_screen.dart';

const _pregnancyColor = Color(0xFF8D4D72);
const _postpartumColor = Color(0xFF8A6652);
const _breastfeedingColor = Color(0xFF2F7A6A);
const _protectedSexColor = Color(0xFF26715A);
const _unprotectedSexColor = Color(0xFFB14962);
const _ovulationFlowerColor = Color(0xFFD49A19);

/// Fill strength of a recorded period day; every fainter value below is
/// deliberately weaker so estimated days read as estimates.
const _recordedPeriodAlpha = .24;
const _estimatedPeriodAlpha = .12;
const _recordedPhaseAlpha = .10;
const _estimatedPhaseAlpha = .05;
const _ovulationFlowerAlpha = .34;
const _estimatedOvulationFlowerAlpha = .17;

Color _pregnancyBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF4A3040)
    : const Color(0xFFF2DFEA);

Color _postpartumBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF41352C)
    : const Color(0xFFE7DDD7);

Color _positiveTestColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFE0AE3A)
    : const Color(0xFFA9740B);

Color _negativeTestColor(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

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
    final estimatedEntries = widget.controller.estimatedPeriodEntries;
    final monthDays = List.generate(daysInMonth, (index) {
      final date = DateTime(_visibleMonth.year, _visibleMonth.month, index + 1);
      return _calendarDayState(
        date,
        profile,
        calculator,
        today,
        estimatedEntries,
      );
    });
    final legendItems = _legendItems(monthDays);
    final breastfeedingSince = profile.isBreastfeedingOn(today)
        ? profile.breastfeedingStartedOn
        : null;
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
            if (breastfeedingSince != null) ...[
              const SizedBox(height: 14),
              _BreastfeedingChip(since: breastfeedingSince),
            ],
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
                          child: InkWell(
                            onTap: () => _openMonthPicker(context),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      DateFormat.yMMMM().format(_visibleMonth),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
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
              today: today,
              isPregnant: profile.isPregnant,
              isPostpartum: isPostpartum,
              configuredLength: profile.cycleLength,
              estimatedLength: estimatedLength,
              hasHistory: widget.controller.periodStarts.length > 1,
              insights: monthInsights,
              periodEntries: widget.controller.periodEntries,
              usualPeriodLength: profile.periodLength,
              estimatedStarts: [
                for (final dayState in monthDays)
                  if (dayState.isEstimatedStart) dayState.date,
              ],
              breastfeedingSince: breastfeedingSince,
              lastRecordedStart: widget.controller.periodStarts.isEmpty
                  ? null
                  : widget.controller.periodStarts.first,
              positiveTests: _positiveTestNotes(monthDays, profile, calculator),
              negativeTestCount: monthDays
                  .where(
                    (dayState) =>
                        dayState.ovulationTest?.result ==
                        OvulationTestResult.negative,
                  )
                  .length,
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

  Future<void> _openMonthPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) =>
          _MonthPickerSheet(visibleMonth: _visibleMonth, today: appNow()),
    );
    if (picked != null) setState(() => _visibleMonth = picked);
  }

  _CalendarDayState _calendarDayState(
    DateTime date,
    UserProfile profile,
    CycleCalculator calculator,
    DateTime today,
    List<PeriodEntry> estimatedEntries,
  ) {
    final lifeStageType = _lifeStageTypeOn(date, profile, today);
    final recordedEntry = _recordedEntryFor(date);
    // Pregnancy and recorded life-stage ranges replace cycle coloring, so no
    // snapshot and no estimated period is calculated for those days.
    final paused = profile.isPregnant || lifeStageType != null;
    final snapshot = paused
        ? null
        : calculator.calculate(
            onDate: date,
            lastPeriodStart: profile.lastPeriodStart,
            cycleLength: profile.cycleLength,
            periodLength: profile.periodLength,
            periodStarts: widget.controller.periodStarts,
          );
    final estimatedEntry = paused || recordedEntry != null
        ? null
        : _entryContaining(estimatedEntries, date);
    final events = (
      period: recordedEntry,
      estimatedPeriod: estimatedEntry,
      intercourse: widget.controller.intercourseEntryOn(date),
      ovulationTest: widget.controller.ovulationTestOn(date),
      lifeStage: lifeStageType,
    );
    return _CalendarDayState(
      date: date,
      phase: _phaseOn(date, snapshot, recordedEntry),
      isEstimated:
          snapshot != null &&
          recordedEntry == null &&
          snapshot.estimateBasis != CycleEstimateBasis.recordedCycle,
      events: events,
      markers: _markersFor(date, profile, today, estimatedEntry),
    );
  }

  _CalendarDayMarkers _markersFor(
    DateTime date,
    UserProfile profile,
    DateTime today,
    PeriodEntry? estimatedEntry,
  ) => (
    today: DateUtils.isSameDay(date, today),
    periodStart: widget.controller.periodStarts.any(
      (logged) => DateUtils.isSameDay(logged, date),
    ),
    estimatedStart:
        estimatedEntry != null &&
        DateUtils.isSameDay(estimatedEntry.startDate, date),
    // Once a birth is recorded it replaces the expected due date as the marked
    // day, so the calendar shows what happened rather than what was expected.
    pregnancyDue:
        profile.isPregnant &&
        profile.babyBornOn == null &&
        DateUtils.isSameDay(date, profile.dueDate),
    babyBorn:
        profile.babyBornOn != null &&
        DateUtils.isSameDay(date, profile.babyBornOn),
  );

  CyclePhase? _phaseOn(
    DateTime date,
    CycleSnapshot? snapshot,
    PeriodEntry? recordedEntry,
  ) {
    if (snapshot == null) return null;
    if (recordedEntry != null) return CyclePhase.menstruation;
    final cycleEntry = _entryStartingOn(snapshot.currentCycleStart);
    if (snapshot.phase == CyclePhase.menstruation &&
        cycleEntry?.endDate != null &&
        date.isAfter(cycleEntry!.endDate!)) {
      return CyclePhase.follicular;
    }
    return snapshot.phase;
  }

  /// Positive tests in the visible month, each compared with the estimated
  /// ovulation day of the cycle it falls in.
  List<_PositiveTestNote> _positiveTestNotes(
    List<_CalendarDayState> monthDays,
    UserProfile profile,
    CycleCalculator calculator,
  ) => [
    for (final dayState in monthDays)
      if (dayState.ovulationTest?.result == OvulationTestResult.positive)
        (
          date: dayState.date,
          offsetDays: dayState.date
              .difference(
                calculator
                    .calculate(
                      onDate: dayState.date,
                      lastPeriodStart: profile.lastPeriodStart,
                      cycleLength: profile.cycleLength,
                      periodLength: profile.periodLength,
                      periodStarts: widget.controller.periodStarts,
                    )
                    .estimatedOvulation,
              )
              .inDays,
        ),
  ];

  LifeStageType? _lifeStageTypeOn(
    DateTime date,
    UserProfile profile,
    DateTime today,
  ) {
    for (final entry in widget.controller.lifeStageEntries) {
      // Breastfeeding never colors a day: periods can happen while it is
      // active, so cycle coloring has to keep running underneath it.
      if (entry.type == LifeStageType.breastfeeding) continue;
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
    // Pregnancy coloring stops at the recorded birth date when there is one,
    // and at the expected due date otherwise.
    final pregnancyEnd = profile.postpartumAnchor;
    if (!profile.isPregnant || pregnancyStart == null || pregnancyEnd == null) {
      return false;
    }
    return !date.isBefore(pregnancyStart) && date.isBefore(pregnancyEnd);
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
      if (monthDays.any((day) => day.isEstimatedStart))
        const _EstimatedPeriodLegend(),
      if (monthDays.any((day) => day.isEstimated && day.phase != null))
        const _EstimatedPhaseLegend(),
      for (final status in ProtectionStatus.values)
        if (monthDays.any(
          (day) => day.intercourseEntry?.protectionStatus == status,
        ))
          _IntercourseLegend(protectionStatus: status),
      for (final result in OvulationTestResult.values)
        if (monthDays.any((day) => day.ovulationTest?.result == result))
          _OvulationTestLegend(result: result),
      for (final stageType in LifeStageType.values)
        if (monthDays.any((day) => day.lifeStageType == stageType))
          _LifeStageLegend(lifeStageType: stageType),
      if (monthDays.any((day) => day.isPregnancyDueDate))
        const _BabyLegend(born: false),
      if (monthDays.any((day) => day.isBabyBornDate))
        const _BabyLegend(born: true),
    ];
  }

  PeriodEntry? _recordedEntryFor(DateTime date) =>
      _entryContaining(widget.controller.periodEntries, date);

  PeriodEntry? _entryContaining(List<PeriodEntry> entries, DateTime date) {
    for (final entry in entries) {
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
      firstDate: isPostpartum ? profile.postpartumAnchor! : DateTime(1900),
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
      case _CalendarDayAction.positiveTest:
        return widget.controller.saveOvulationTest(
          dayState.date,
          OvulationTestResult.positive,
        );
      case _CalendarDayAction.negativeTest:
        return widget.controller.saveOvulationTest(
          dayState.date,
          OvulationTestResult.negative,
        );
      case _CalendarDayAction.removeTest:
        return widget.controller.deleteOvulationTest(dayState.date);
      case _CalendarDayAction.addPeriod:
        return widget.controller.logPeriodStart(dayState.date);
      case _CalendarDayAction.confirmEstimatedPeriod:
        final estimated = dayState.estimatedPeriodEntry;
        if (estimated != null) {
          await widget.controller.logPeriodStart(estimated.startDate);
        }
      case _CalendarDayAction.adjustEstimatedPeriod:
        await _adjustEstimatedPeriod(context, dayState);
      case _CalendarDayAction.managePeriod:
        final entry = _periodEntryFor(dayState);
        if (entry != null) await _managePeriodEntry(context, entry);
    }
  }

  /// Lets the person move an estimated start onto the day it really began.
  Future<void> _adjustEstimatedPeriod(
    BuildContext context,
    _CalendarDayState dayState,
  ) async {
    final estimated = dayState.estimatedPeriodEntry;
    if (estimated == null) return;
    final now = appNow();
    final picked = await showDatePicker(
      context: context,
      initialDate: estimated.startDate.isAfter(now) ? now : estimated.startDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'When did this period start?',
    );
    if (picked != null) await widget.controller.logPeriodStart(picked);
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
  positiveTest,
  negativeTest,
  removeTest,
  addPeriod,
  confirmEstimatedPeriod,
  adjustEstimatedPeriod,
  managePeriod,
}

typedef _CalendarDayEvents = ({
  PeriodEntry? period,
  PeriodEntry? estimatedPeriod,
  IntercourseEntry? intercourse,
  OvulationTestEntry? ovulationTest,
  LifeStageType? lifeStage,
});

typedef _CalendarDayMarkers = ({
  bool today,
  bool periodStart,
  bool estimatedStart,
  bool pregnancyDue,
  bool babyBorn,
});

/// A positive ovulation test and how far it sits from the estimated
/// ovulation day: negative values are earlier, positive values later.
typedef _PositiveTestNote = ({DateTime date, int offsetDays});

class _CalendarDayState {
  const _CalendarDayState({
    required this.date,
    required this.phase,
    required this.isEstimated,
    required this.events,
    required this.markers,
  });

  final DateTime date;
  final CyclePhase? phase;

  /// Whether this day's coloring comes from an estimate rather than from a
  /// cycle bounded by two recorded period starts.
  final bool isEstimated;
  final _CalendarDayEvents events;
  final _CalendarDayMarkers markers;

  int get day => date.day;
  PeriodEntry? get recordedPeriodEntry => events.period;
  PeriodEntry? get estimatedPeriodEntry => events.estimatedPeriod;
  IntercourseEntry? get intercourseEntry => events.intercourse;
  OvulationTestEntry? get ovulationTest => events.ovulationTest;
  LifeStageType? get lifeStageType => events.lifeStage;
  bool get isToday => markers.today;
  bool get isLoggedStart => markers.periodStart;
  bool get isEstimatedStart => markers.estimatedStart;
  bool get isPregnancyDueDate => markers.pregnancyDue;
  bool get isBabyBornDate => markers.babyBorn;
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
          const _SectionLabel('Ovulation test'),
          for (final result in OvulationTestResult.values)
            _ovulationTestOption(context, result),
          if (dayState.ovulationTest != null) _removeTestOption(context),
          const Divider(height: 1),
          if (dayState.estimatedPeriodEntry != null) ...[
            _estimatedPeriodSection(context),
            const Divider(height: 1),
          ],
          _periodOption(context),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  Widget _ovulationTestOption(
    BuildContext context,
    OvulationTestResult result,
  ) => ListTile(
    leading: Icon(
      _iconForTestResult(result),
      color: _colorForTestResult(context, result),
    ),
    title: Text(
      result == OvulationTestResult.positive ? 'Positive' : 'Negative',
    ),
    trailing: dayState.ovulationTest?.result == result
        ? const Icon(Icons.check_rounded)
        : null,
    onTap: () => Navigator.pop(
      context,
      result == OvulationTestResult.positive
          ? _CalendarDayAction.positiveTest
          : _CalendarDayAction.negativeTest,
    ),
  );

  Widget _removeTestOption(BuildContext context) => ListTile(
    leading: const Icon(Icons.close_rounded),
    title: const Text('Remove test result'),
    onTap: () => Navigator.pop(context, _CalendarDayAction.removeTest),
  );

  /// Offers the three honest answers to an estimated period: it happened, it
  /// happened on another day, or leave the estimate alone by closing the sheet.
  Widget _estimatedPeriodSection(BuildContext context) {
    final estimatedStart = dayState.estimatedPeriodEntry!.startDate;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SectionLabel(
          'Estimated period — confirm it happened, adjust the date, or '
          'ignore it',
        ),
        ListTile(
          leading: const Icon(Icons.check_circle_outline_rounded),
          title: const Text('Confirm this period'),
          subtitle: Text(
            'Logs ${DateFormat.yMMMd().format(estimatedStart)} as the start',
          ),
          onTap: () =>
              Navigator.pop(context, _CalendarDayAction.confirmEstimatedPeriod),
        ),
        ListTile(
          leading: const Icon(Icons.edit_calendar_outlined),
          title: const Text('Adjust the date'),
          onTap: () =>
              Navigator.pop(context, _CalendarDayAction.adjustEstimatedPeriod),
        ),
      ],
    );
  }

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

/// Two wheels — months and years — that jump the calendar to any month.
///
/// The year range covers the last ten years and the next two, which is enough
/// for past history without suggesting the app can predict far ahead.
class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({required this.visibleMonth, required this.today});

  final DateTime visibleMonth;
  final DateTime today;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late final List<int> _years;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _yearController;
  late int _month;
  late int _year;

  @override
  void initState() {
    super.initState();
    final firstYear = widget.today.year - 10;
    _years = List.generate(13, (index) => firstYear + index);
    _month = widget.visibleMonth.month;
    _year = widget.visibleMonth.year.clamp(_years.first, _years.last);
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _yearController = FixedExtentScrollController(
      initialItem: _years.indexOf(_year),
    );
  }

  @override
  void dispose() {
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jump to a month',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 196,
            child: Row(
              children: [
                _wheel(
                  controller: _monthController,
                  labels: [
                    for (var month = 1; month <= 12; month++)
                      DateFormat.MMMM().format(DateTime(_year, month)),
                  ],
                  onSelected: (index) => setState(() => _month = index + 1),
                ),
                const SizedBox(width: 12),
                _wheel(
                  controller: _yearController,
                  labels: [for (final year in _years) '$year'],
                  onSelected: (index) => setState(() => _year = _years[index]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, DateTime(_year, _month)),
              child: const Text('Go to month'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _wheel({
    required FixedExtentScrollController controller,
    required List<String> labels,
    required ValueChanged<int> onSelected,
  }) => Expanded(
    child: CupertinoPicker(
      scrollController: controller,
      itemExtent: 40,
      magnification: 1.1,
      useMagnifier: true,
      squeeze: 1.1,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
        background: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: .45),
      ),
      onSelectedItemChanged: onSelected,
      children: [
        for (final label in labels)
          Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
      ],
    ),
  );
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({
    required this.month,
    required this.today,
    required this.isPregnant,
    required this.isPostpartum,
    required this.configuredLength,
    required this.estimatedLength,
    required this.hasHistory,
    required this.insights,
    required this.periodEntries,
    required this.usualPeriodLength,
    required this.estimatedStarts,
    required this.breastfeedingSince,
    required this.lastRecordedStart,
    required this.positiveTests,
    required this.negativeTestCount,
  });

  final DateTime month;
  final DateTime today;
  final bool isPregnant;
  final bool isPostpartum;
  final int configuredLength;
  final int estimatedLength;
  final bool hasHistory;
  final List<CycleIntervalInsight> insights;
  final List<PeriodEntry> periodEntries;
  final int usualPeriodLength;

  /// Estimated period starts that are shown in this month.
  final List<DateTime> estimatedStarts;
  final DateTime? breastfeedingSince;
  final DateTime? lastRecordedStart;
  final List<_PositiveTestNote> positiveTests;
  final int negativeTestCount;

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
      ..._breastfeedingMessages(),
      if (estimatedStarts.isNotEmpty) _estimatedPeriodMessage(),
      if (insights.isEmpty && estimatedStarts.isEmpty)
        'No period start was recorded this month.',
      ...insights.map(_messageFor),
      ...periodEntries
          .where(
            (entry) =>
                entry.startDate.year == month.year &&
                entry.startDate.month == month.month,
          )
          .map(_durationMessageFor),
      ..._ovulationTestMessages(),
      estimateNote,
    ];
    return messages.join('\n\n');
  }

  /// Calm context for breastfeeding: periods commonly pause, and when one does
  /// return it can stop again without anything being wrong.
  List<String> _breastfeedingMessages() {
    final since = breastfeedingSince;
    if (since == null) return const [];
    final latest = lastRecordedStart;
    final periodSinceBreastfeeding = latest != null && !latest.isBefore(since);
    final messages = <String>[
      'Breastfeeding since ${DateFormat.MMMMd().format(since)}. Periods often '
          'stay away for months while breastfeeding (lactational amenorrhoea), '
          'so the dates and predictions here are less reliable than usual.',
    ];
    if (periodSinceBreastfeeding && today.difference(latest).inDays >= 60) {
      messages.add(
        'A period returned on ${DateFormat.MMMMd().format(latest)} and none has '
        'been logged since. Cycles often stop and restart while breastfeeding, '
        'especially when feeding patterns change — this is usually normal.',
      );
    } else if (!periodSinceBreastfeeding &&
        today.difference(since).inDays >= 365) {
      messages.add(
        'No period has been logged since breastfeeding began over a year ago. '
        'That can still be normal, and if you would like it looked at, '
        'consider talking with a healthcare professional.',
      );
    }
    return messages;
  }

  String _estimatedPeriodMessage() {
    final labels = estimatedStarts
        .map(DateFormat.MMMMd().format)
        .toList(growable: false);
    final dates = labels.length == 1
        ? labels.single
        : '${labels.take(labels.length - 1).join(', ')} and ${labels.last}';
    final lead = insights.isEmpty ? 'No period was logged this month. ' : '';
    return labels.length == 1
        ? '${lead}The period shown around $dates is estimated from your usual '
              'cycle — tap it on the calendar to confirm or adjust.'
        : '${lead}The periods shown around $dates are estimated from your usual '
              'cycle — tap them on the calendar to confirm or adjust.';
  }

  /// Test results are described next to the estimate, never folded into it.
  List<String> _ovulationTestMessages() {
    if (positiveTests.isNotEmpty) {
      return [
        for (final test in positiveTests) _positiveTestMessage(test),
        'Test results are kept for your reference and do not change the '
            'estimates.',
      ];
    }
    if (negativeTestCount == 0) return const [];
    return [
      '$negativeTestCount negative ovulation '
          '${negativeTestCount == 1 ? 'test' : 'tests'} recorded this month. '
          'Test results are kept for your reference and do not change the '
          'estimates.',
    ];
  }

  String _positiveTestMessage(_PositiveTestNote test) {
    final date = DateFormat.MMMMd().format(test.date);
    final distance = test.offsetDays.abs();
    final days = distance == 1 ? 'day' : 'days';
    return switch (test.offsetDays.compareTo(0)) {
      < 0 =>
        'Positive ovulation test on $date, $distance $days before the '
            'estimated ovulation day.',
      > 0 =>
        'Positive ovulation test on $date, $distance $days after the '
            'estimated ovulation day.',
      _ => 'Positive ovulation test on $date, the estimated ovulation day.',
    };
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
    final marksBaby = dayState.isPregnancyDueDate || dayState.isBabyBornDate;
    return Material(
      color: stageType == LifeStageType.pregnancy
          ? _pregnancyBackground(context)
          : stageType == LifeStageType.postpartum
          ? _postpartumBackground(context)
          : dayState.phase == null
          ? Theme.of(context).colorScheme.surfaceContainerHighest
          : color.withValues(alpha: _fillAlpha(dayState)),
      shape: CircleBorder(
        side: dayState.isToday || marksBaby
            ? BorderSide(color: color, width: marksBaby ? 2.5 : 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (dayState.phase == CyclePhase.ovulation)
              _ovulationFlowerMarker(dayState.isEstimated),
            _dayNumber(context),
            if (dayState.isLoggedStart)
              _periodStartMarker(context)
            else if (dayState.isEstimatedStart)
              _estimatedStartMarker(context),
            if (marksBaby) _babyMarker(),
            if (dayState.intercourseEntry != null) _intercourseMarker(),
            if (dayState.ovulationTest != null) _ovulationTestMarker(context),
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

  Widget _ovulationFlowerMarker(bool isEstimated) => Icon(
    Icons.local_florist_rounded,
    size: 30,
    color: _ovulationFlowerColor.withValues(
      alpha: isEstimated
          ? _estimatedOvulationFlowerAlpha
          : _ovulationFlowerAlpha,
    ),
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

  /// A hollow ring instead of the solid dot: the same place in the cell, but
  /// visibly unconfirmed.
  Widget _estimatedStartMarker(BuildContext context) => Positioned(
    bottom: 4,
    child: Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .75),
          width: 1.4,
        ),
      ),
    ),
  );

  Widget _babyMarker() => const Positioned(
    bottom: 3,
    child: Icon(Icons.child_care, size: 13, color: _postpartumColor),
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

  Widget _ovulationTestMarker(BuildContext context) {
    final result = dayState.ovulationTest!.result;
    return Positioned(
      top: 3,
      right: 3,
      child: Icon(
        _iconForTestResult(result),
        size: 12,
        color: _colorForTestResult(context, result),
      ),
    );
  }
}

/// How strongly a day's phase color is filled.
///
/// Recorded bleeding is the strongest; estimated days are deliberately far
/// fainter so the calendar never presents a guess as a fact.
double _fillAlpha(_CalendarDayState dayState) {
  if (dayState.recordedPeriodEntry != null) return _recordedPeriodAlpha;
  if (dayState.estimatedPeriodEntry != null) return _estimatedPeriodAlpha;
  return dayState.isEstimated ? _estimatedPhaseAlpha : _recordedPhaseAlpha;
}

Color _dayCellColor(BuildContext context, _CalendarDayState dayState) {
  if (dayState.isPregnancyDueDate || dayState.isBabyBornDate) {
    return _postpartumColor;
  }
  final phase = dayState.phase;
  return phase == null
      ? Theme.of(context).colorScheme.outline
      : colorForPhase(phase);
}

Color _colorForLifeStage(LifeStageType lifeStageType) =>
    switch (lifeStageType) {
      LifeStageType.pregnancy => _pregnancyColor,
      LifeStageType.postpartum => _postpartumColor,
      LifeStageType.breastfeeding => _breastfeedingColor,
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

Color _colorForTestResult(BuildContext context, OvulationTestResult result) =>
    switch (result) {
      OvulationTestResult.positive => _positiveTestColor(context),
      OvulationTestResult.negative => _negativeTestColor(context),
    };

IconData _iconForTestResult(OvulationTestResult result) => switch (result) {
  OvulationTestResult.positive => Icons.science,
  OvulationTestResult.negative => Icons.science_outlined,
};

/// A small heading inside a bottom sheet that groups the options below it.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

/// The quiet reminder above the month grid that periods behave differently
/// while breastfeeding.
class _BreastfeedingChip extends StatelessWidget {
  const _BreastfeedingChip({required this.since});

  final DateTime since;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF8FC9B9) : const Color(0xFF23604F);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E332B) : const Color(0xFFEAF4F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.child_care_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Breastfeeding · since ${DateFormat.yMMMd().format(since)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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

class _EstimatedPeriodLegend extends StatelessWidget {
  const _EstimatedPeriodLegend();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .75),
            width: 1.4,
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text('Estimated period', style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _EstimatedPhaseLegend extends StatelessWidget {
  const _EstimatedPhaseLegend();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.auto_awesome_outlined,
        size: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      const SizedBox(width: 6),
      Text(
        'Faint colors = estimated',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _OvulationTestLegend extends StatelessWidget {
  const _OvulationTestLegend({required this.result});

  final OvulationTestResult result;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        _iconForTestResult(result),
        size: 14,
        color: _colorForTestResult(context, result),
      ),
      const SizedBox(width: 6),
      Text(result.label, style: Theme.of(context).textTheme.bodySmall),
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

class _BabyLegend extends StatelessWidget {
  const _BabyLegend({required this.born});

  /// True once a birth date is recorded, which replaces the expected due date.
  final bool born;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.child_care, size: 14, color: _postpartumColor),
      const SizedBox(width: 6),
      Text(
        born ? 'Baby born' : 'Expected due date',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}
