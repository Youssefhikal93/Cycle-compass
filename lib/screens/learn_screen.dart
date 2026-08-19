import 'package:flutter/material.dart';

import '../services/cycle_calculator.dart';
import 'today_screen.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            'Know your cycle',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Clear, careful explanations—without telling you how you are supposed to feel.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.layers_outlined,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'One cycle, four commonly described stages. Menstruation overlaps biologically with the follicular phase, but is shown separately here because it is easier to understand and track.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const _LearnCard(
            phase: CyclePhase.menstruation,
            number: '01',
            timing: 'Begins on Day 1',
            body:
                'Hormone levels have fallen and the uterine lining sheds as bleeding. A period often lasts several days, but length and flow vary from person to person.',
            track:
                'Flow, pain, energy, headaches, and anything unusual for you.',
          ),
          const _LearnCard(
            phase: CyclePhase.follicular,
            number: '02',
            timing: 'From Day 1 until ovulation',
            body:
                'Follicle-stimulating hormone helps follicles develop in the ovaries. Estrogen generally rises and the uterine lining rebuilds. This phase varies most in length.',
            track:
                'Bleeding, cervical fluid, mood, sleep, and your own patterns.',
          ),
          const _LearnCard(
            phase: CyclePhase.ovulation,
            number: '03',
            timing: 'An event, not a fixed day',
            body:
                'A surge in luteinizing hormone can trigger an ovary to release an egg. It often happens roughly 10–16 days before the next period, not always on Day 14.',
            track:
                'Calendar estimates are uncertain; an ovulation test can add information.',
          ),
          const _LearnCard(
            phase: CyclePhase.luteal,
            number: '04',
            timing: 'After ovulation until the next period',
            body:
                'Progesterone generally rises to support the uterine lining. If pregnancy does not occur, progesterone and estrogen fall and a new period begins.',
            track:
                'Possible changes in mood, breasts, skin, headaches, sleep, or digestion.',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sources & safety',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Educational content is based on the U.S. Office on Women’s Health, NHS, and ACOG patient guidance. It needs clinician review before public release. This app is not medical advice or contraception.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _LearnCard extends StatelessWidget {
  const _LearnCard({
    required this.phase,
    required this.number,
    required this.timing,
    required this.body,
    required this.track,
  });

  final CyclePhase phase;
  final String number;
  final String timing;
  final String body;
  final String track;

  @override
  Widget build(BuildContext context) {
    final color = colorForPhase(phase);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: color.withValues(alpha: .08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: color.withValues(alpha: .16)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 7,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            leading: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            title: Text(
              phase.label,
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
            subtitle: Text(timing),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Useful to track: $track',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
