import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../models/user_profile.dart';
import '../widgets/profile_avatar.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _pageController = PageController();
  final _profileKey = GlobalKey<FormState>();
  int _page = 0;
  DateTime? _dateOfBirth;
  DateTime _lastPeriodStart = DateTime.now();
  double _cycleLength = 28;
  double _periodLength = 5;
  String? _avatarPath;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.blur_circular_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Cycle Compass',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${_page + 1} of 2',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: LinearProgressIndicator(
                value: (_page + 1) / 2,
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [_profileStep(), _cycleStep()],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Row(
                children: [
                  if (_page == 1) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : _back,
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving
                          ? null
                          : (_page == 0 ? _next : _finish),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_page == 0 ? 'Continue' : 'See my cycle'),
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

  Widget _profileStep() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Form(
        key: _profileKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Let’s make it yours',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your details stay on this device. You can change your name and photo at any time.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: EditableProfileAvatar(
                name: _nameController.text,
                avatarPath: _avatarPath,
                onChanged: (value) => setState(() => _avatarPath = value),
                radius: 52,
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'How should we greet you?',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Please enter your name';
                if (name.length < 2) {
                  return 'Please enter at least 2 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: 'Choose date of birth',
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _pickDateOfBirth,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date of birth',
                    errorText: _dateOfBirth == null && _triedProfile
                        ? 'Please choose your date of birth'
                        : null,
                    prefixIcon: const Icon(Icons.cake_outlined),
                    suffixIcon: const Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(
                    _dateOfBirth == null
                        ? 'Choose a date'
                        : DateFormat.yMMMMd().format(_dateOfBirth!),
                    style: TextStyle(
                      color: _dateOfBirth == null
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _InfoStrip(
              icon: Icons.lock_outline_rounded,
              text: 'No account, no cloud sync, and no advertising trackers.',
            ),
          ],
        ),
      ),
    );
  }

  bool _triedProfile = false;

  Widget _cycleStep() {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your cycle basics',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'These answers create your first estimate. It gets more useful as you keep logging.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'When did your latest period start?',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: _pickLastPeriod,
                  icon: const Icon(Icons.water_drop_outlined),
                  label: Text(DateFormat.yMMMMd().format(_lastPeriodStart)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SliderCard(
            title: 'Usual cycle length',
            valueLabel: '${_cycleLength.round()} days',
            helper: 'From the first day of one period to the next.',
            value: _cycleLength,
            min: 21,
            max: 45,
            divisions: 24,
            onChanged: (value) => setState(() => _cycleLength = value),
          ),
          const SizedBox(height: 14),
          _SliderCard(
            title: 'Usual period length',
            valueLabel: '${_periodLength.round()} days',
            helper: 'How many days bleeding usually lasts.',
            value: _periodLength,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (value) => setState(() => _periodLength = value),
          ),
          const SizedBox(height: 18),
          const _InfoStrip(
            icon: Icons.info_outline_rounded,
            text:
                'Cycle phases are estimates and must not be used as birth control or a diagnosis.',
          ),
        ],
      ),
    );
  }

  void _next() {
    setState(() => _triedProfile = true);
    if (!(_profileKey.currentState?.validate() ?? false) ||
        _dateOfBirth == null) {
      return;
    }
    setState(() => _page = 1);
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    setState(() => _page = 0);
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final profile = UserProfile(
      name: _nameController.text.trim(),
      dateOfBirth: _dateOfBirth!,
      avatarPath: _avatarPath,
      lastPeriodStart: _lastPeriodStart,
      cycleLength: _cycleLength.round(),
      periodLength: _periodLength.round(),
    );
    await widget.controller.completeOnboarding(profile);
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select date of birth',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _pickLastPeriod() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastPeriodStart,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Select first day of latest period',
    );
    if (picked != null) setState(() => _lastPeriodStart = picked);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );
}

class _SliderCard extends StatelessWidget {
  const _SliderCard({
    required this.title,
    required this.valueLabel,
    required this.helper,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String valueLabel;
  final String helper;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => _SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              valueLabel,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
        Text(
          helper,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F0FA),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFF65558F)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ),
      ],
    ),
  );
}
