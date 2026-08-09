import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../services/cycle_calculator.dart';
import 'today_screen.dart';

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
    final calculator = const CycleCalculator();
    final today = DateTime.now();
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
              'A gentle map of recorded and estimated cycle days.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                      final snapshot = calculator.calculate(
                        onDate: date,
                        lastPeriodStart: profile.lastPeriodStart,
                        cycleLength: profile.cycleLength,
                        periodLength: profile.periodLength,
                      );
                      final isToday = DateUtils.isSameDay(date, today);
                      final isLoggedStart = widget.controller.periodStarts.any(
                        (logged) => DateUtils.isSameDay(logged, date),
                      );
                      return _DayCell(
                        day: day,
                        phase: snapshot.phase,
                        isToday: isToday,
                        isLoggedStart: isLoggedStart,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 14,
              runSpacing: 10,
              children: CyclePhase.values
                  .map((phase) => _LegendItem(phase: phase))
                  .toList(),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: Color(0xFF9A5719),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Colored days are estimates based on a ${profile.cycleLength}-day cycle. A dark ring marks today; a small dot marks a period start you recorded.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6F4219),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
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
  });

  final int day;
  final CyclePhase phase;
  final bool isToday;
  final bool isLoggedStart;

  @override
  Widget build(BuildContext context) {
    final color = colorForPhase(phase);
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        shape: BoxShape.circle,
        border: isToday ? Border.all(color: color, width: 2) : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
          if (isLoggedStart)
            Positioned(
              bottom: 5,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
