import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../services/cycle_calculator.dart';
import '../widgets/profile_avatar.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    super.key,
    required this.controller,
    required this.onOpenProfile,
  });

  final AppController controller;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile!;
    final now = DateTime.now();
    final snapshot = const CycleCalculator().calculate(
      onDate: now,
      lastPeriodStart: profile.lastPeriodStart,
      cycleLength: profile.cycleLength,
      periodLength: profile.periodLength,
    );
    final phaseColor = colorForPhase(snapshot.phase);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          profile.name.split(' ').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Open profile',
                    onPressed: onOpenProfile,
                    icon: ProfileAvatar(
                      name: profile.name,
                      avatarPath: profile.avatarPath,
                      radius: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.list(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [phaseColor.withValues(alpha: .16), Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: phaseColor.withValues(alpha: .22),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _ConfidenceBadge(color: phaseColor),
                          Flexible(
                            child: Text(
                              DateFormat.MMMd().format(now),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _CycleRing(snapshot: snapshot, color: phaseColor),
                      const SizedBox(height: 18),
                      Text(
                        snapshot.phase.label,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: phaseColor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.5,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        snapshot.phase.shortDescription,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.4,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .82),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_outlined, size: 20),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Next period estimated in ${snapshot.daysUntilNextPeriod} days',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  'Your cycle journey',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 116,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: CyclePhase.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final phase = CyclePhase.values[index];
                      return _PhaseTile(
                        phase: phase,
                        selected: snapshot.phase == phase,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                _InsightCard(phase: snapshot.phase),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _confirmPeriodStart(context),
                  icon: const Icon(Icons.water_drop_outlined),
                  label: const Text('My period started today'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Calendar-based estimates cannot confirm ovulation and should not be used as contraception.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPeriodStart(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.water_drop_outlined),
        title: const Text('Log a new period?'),
        content: const Text(
          'Today will become Day 1 and future phase estimates will update.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log today'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.logPeriodStart(DateTime.now());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Period start logged. Today is Day 1.')),
    );
  }
}

class _CycleRing extends StatelessWidget {
  const _CycleRing({required this.snapshot, required this.color});

  final CycleSnapshot snapshot;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 174,
    child: Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.square(
          dimension: 174,
          child: CircularProgressIndicator(
            value: snapshot.progress,
            strokeWidth: 13,
            strokeCap: StrokeCap.round,
            backgroundColor: color.withValues(alpha: .13),
            color: color,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DAY',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 1.7,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${snapshot.cycleDay}',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            Text(
              'of ${snapshot.cycleLength}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    ),
  );
}

class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.auto_awesome_outlined, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          'EARLY ESTIMATE',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: .4,
          ),
        ),
      ],
    ),
  );
}

class _PhaseTile extends StatelessWidget {
  const _PhaseTile({required this.phase, required this.selected});

  final CyclePhase phase;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = colorForPhase(phase);
    return Container(
      width: 118,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: selected ? color : color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconForPhase(phase), color: selected ? Colors.white : color),
          const Spacer(),
          Text(
            phase.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            selected ? 'You are here' : 'Learn more',
            style: TextStyle(
              color: selected
                  ? Colors.white.withValues(alpha: .82)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.phase});

  final CyclePhase phase;

  @override
  Widget build(BuildContext context) {
    final details = switch (phase) {
      CyclePhase.menstruation => (
        'What may be happening',
        'Bleeding, cramps, or tiredness can occur. Experiences vary, so logging what you notice is more useful than following a “typical” script.',
      ),
      CyclePhase.follicular => (
        'What is happening',
        'Follicles develop in the ovaries and estrogen generally rises. Menstruation is biologically part of this phase, even though this app shows it separately for clarity.',
      ),
      CyclePhase.ovulation => (
        'An estimated event',
        'Ovulation is the release of an egg. A calendar can only estimate its timing; tests or clinical methods are needed for more certainty.',
      ),
      CyclePhase.luteal => (
        'What may be happening',
        'Progesterone generally rises after ovulation and falls before a new period if pregnancy does not occur. Some people notice premenstrual changes.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorForPhase(phase).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(iconForPhase(phase), color: colorForPhase(phase)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.$1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  details.$2,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color colorForPhase(CyclePhase phase) => switch (phase) {
  CyclePhase.menstruation => const Color(0xFFB93A5C),
  CyclePhase.follicular => const Color(0xFF31866B),
  CyclePhase.ovulation => const Color(0xFFE28A2B),
  CyclePhase.luteal => const Color(0xFF6D58B5),
};

IconData iconForPhase(CyclePhase phase) => switch (phase) {
  CyclePhase.menstruation => Icons.water_drop_outlined,
  CyclePhase.follicular => Icons.spa_outlined,
  CyclePhase.ovulation => Icons.wb_sunny_outlined,
  CyclePhase.luteal => Icons.nightlight_outlined,
};

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}
