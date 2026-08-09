import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../models/user_profile.dart';
import '../widgets/profile_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile!;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text(
            'Your profile',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: EditableProfileAvatar(
              name: profile.name,
              avatarPath: profile.avatarPath,
              onChanged: (path) => _updateAvatar(profile, path),
              radius: 58,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profile.name,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            'Your photo is optional. Initials are used automatically.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 26),
          _SettingsGroup(
            title: 'Personal details',
            children: [
              _SettingTile(
                icon: Icons.person_outline_rounded,
                label: 'Name',
                value: profile.name,
                onTap: () => _openEditor(context, profile),
              ),
              _SettingTile(
                icon: Icons.cake_outlined,
                label: 'Date of birth',
                value: DateFormat.yMMMMd().format(profile.dateOfBirth),
                onTap: () => _openEditor(context, profile),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'Cycle settings',
            children: [
              _SettingTile(
                icon: Icons.sync_rounded,
                label: 'Usual cycle length',
                value: '${profile.cycleLength} days',
                onTap: () => _openEditor(context, profile),
              ),
              _SettingTile(
                icon: Icons.water_drop_outlined,
                label: 'Usual period length',
                value: '${profile.periodLength} days',
                onTap: () => _openEditor(context, profile),
              ),
              _SettingTile(
                icon: Icons.event_outlined,
                label: 'Latest period start',
                value: DateFormat.yMMMd().format(profile.lastPeriodStart),
                onTap: null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7F4),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF26715A)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Private by design',
                        style: TextStyle(
                          color: Color(0xFF225B49),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Your profile and cycle history are stored only on this device. Android cloud backup is disabled.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF3A6758),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => _confirmReset(context, profile),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete all local data'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAvatar(UserProfile profile, String? path) async {
    await controller.updateProfile(
      UserProfile(
        name: profile.name,
        dateOfBirth: profile.dateOfBirth,
        avatarPath: path,
        lastPeriodStart: profile.lastPeriodStart,
        cycleLength: profile.cycleLength,
        periodLength: profile.periodLength,
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, UserProfile profile) async {
    final updated = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EditProfileSheet(profile: profile),
    );
    if (updated != null) await controller.updateProfile(updated);
  }

  Future<void> _confirmReset(BuildContext context, UserProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Delete everything?'),
        content: const Text(
          'Your profile, avatar, and cycle history will be permanently removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete data'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final path = profile.avatarPath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await controller.reset();
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile});

  final UserProfile profile;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late DateTime _dateOfBirth;
  late double _cycleLength;
  late double _periodLength;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _dateOfBirth = widget.profile.dateOfBirth;
    _cycleLength = widget.profile.cycleLength.toDouble();
    _periodLength = widget.profile.periodLength.toDouble();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit your details',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Please enter at least 2 characters'
                    : null,
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.cake_outlined),
                title: const Text('Date of birth'),
                subtitle: Text(DateFormat.yMMMMd().format(_dateOfBirth)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickBirthDate,
              ),
              const Divider(height: 28),
              _EditSlider(
                label: 'Usual cycle length',
                value: _cycleLength,
                min: 21,
                max: 45,
                divisions: 24,
                onChanged: (value) => setState(() => _cycleLength = value),
              ),
              _EditSlider(
                label: 'Usual period length',
                value: _periodLength,
                min: 1,
                max: 10,
                divisions: 9,
                onChanged: (value) => setState(() => _periodLength = value),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      UserProfile(
        name: _nameController.text.trim(),
        dateOfBirth: _dateOfBirth,
        avatarPath: widget.profile.avatarPath,
        lastPeriodStart: widget.profile.lastPeriodStart,
        cycleLength: _cycleLength.round(),
        periodLength: _periodLength.round(),
      ),
    );
  }
}

class _EditSlider extends StatelessWidget {
  const _EditSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            '${value.round()} days',
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
        label: '${value.round()} days',
        onChanged: onChanged,
      ),
    ],
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 5),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ),
        ...children,
      ],
    ),
  );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 21),
    ),
    title: Text(label),
    subtitle: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
