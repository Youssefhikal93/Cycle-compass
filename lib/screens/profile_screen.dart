import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_controller.dart';
import '../models/life_stage_entry.dart';
import '../models/period_entry.dart';
import '../models/user_profile.dart';
import '../services/backup_codec.dart';
import '../services/backup_service.dart';
import '../services/clock.dart';
import '../services/cycle_calculator.dart';
import '../widgets/profile_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.controller,
    this.backupService = const BackupService(),
    this.backupCodec = const BackupCodec(),
  });

  final AppController controller;
  final BackupService backupService;
  final BackupCodec backupCodec;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile!;
    final latestEntry = controller.periodEntries.first;
    final isPostpartum = profile.isPostpartumOn(appNow());
    final historyLength = const CycleCalculator().estimatedCycleLength(
      periodStarts: controller.periodStarts,
      configuredLength: profile.cycleLength,
    );
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
                value: controller.periodStarts.length > 1
                    ? '${profile.cycleLength} days · fallback; history estimate $historyLength'
                    : '${profile.cycleLength} days · used until more dates are added',
                onTap: () => _openEditor(context, profile),
              ),
              _SettingTile(
                icon: Icons.water_drop_outlined,
                label: 'Usual period length',
                value: '${profile.periodLength} days',
                onTap: () => _openEditor(context, profile),
              ),
              _SettingTile(
                icon: Icons.event_available_outlined,
                label: 'Next period due date',
                value: profile.isPregnant
                    ? isPostpartum
                          ? 'Paused until the first postpartum period'
                          : 'Paused during pregnancy'
                    : profile.nextPeriodDueDate == null
                    ? 'Automatic estimate · tap to set a date'
                    : '${DateFormat.yMMMMd().format(profile.nextPeriodDueDate!)} · set by you',
                onTap: profile.isPregnant
                    ? null
                    : () => _editNextPeriodDueDate(context, profile),
              ),
              _SettingTile(
                icon: Icons.event_outlined,
                label: 'Latest period start',
                value: _periodEntryLabel(latestEntry),
                onTap: () => _editPeriodDate(context, latestEntry),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'Notifications',
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Cycle notifications'),
                subtitle: Text(
                  profile.notificationsEnabled
                      ? controller.notificationsAllowed
                            ? 'On · every estimated phase and mode change '
                                  'around 9:00 AM'
                            : 'On · Android permission is needed'
                      : 'Off',
                ),
                value: profile.notificationsEnabled,
                onChanged: (enabled) async {
                  if (enabled) {
                    await _enableNotifications(context);
                  } else {
                    await controller.disableNotifications();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'Pregnancy & postpartum',
            children: [
              _SettingTile(
                icon: profile.isPregnant
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: 'Current mode',
                value: isPostpartum
                    ? 'Postpartum · waiting for the first period'
                    : profile.isPregnant
                    ? profile.dueDate == null
                          ? 'Pregnancy · cycle estimates paused'
                          : 'Pregnancy · due ${DateFormat.yMMMd().format(profile.dueDate!)}'
                    : 'Period tracking · pregnancy mode is off',
                onTap: () => _openPregnancySettings(context, profile),
              ),
              if (profile.isPregnant && profile.dueDate != null)
                _SettingTile(
                  icon: Icons.event_outlined,
                  label: isPostpartum
                      ? 'Postpartum started'
                      : 'Expected due date',
                  value: DateFormat.yMMMMd().format(profile.dueDate!),
                  onTap: isPostpartum
                      ? null
                      : () => _openPregnancySettings(context, profile),
                ),
              if (profile.postpartumStartedOn != null &&
                  profile.postpartumEndedOn != null)
                _SettingTile(
                  icon: Icons.history_rounded,
                  label: 'Last postpartum tracking',
                  value:
                      '${DateFormat.yMMMd().format(profile.postpartumStartedOn!)} – '
                      '${DateFormat.yMMMd().format(profile.postpartumEndedOn!)} · '
                      'ended with first period',
                  onTap: null,
                ),
              for (final entry in controller.lifeStageEntries)
                _SettingTile(
                  icon: entry.type == LifeStageType.pregnancy
                      ? Icons.favorite_outline_rounded
                      : Icons.spa_outlined,
                  label: '${entry.type.label} history',
                  value:
                      '${DateFormat.yMMMd().format(entry.startDate)} – '
                      '${DateFormat.yMMMd().format(entry.endDate)} · '
                      '${entry.durationDays} days',
                  onTap: () => _openLifeStageEditor(context, entry),
                ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: const Text('Add past pregnancy or postpartum'),
                subtitle: const Text(
                  'Record a completed date range for your history',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openLifeStageEditor(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'Period history',
            children: [
              for (final entry in controller.periodEntries.take(6))
                _SettingTile(
                  icon: Icons.water_drop_outlined,
                  label:
                      DateUtils.isSameDay(
                        entry.startDate,
                        profile.lastPeriodStart,
                      )
                      ? 'Latest period'
                      : 'Earlier period',
                  value: _periodEntryLabel(entry),
                  onTap: () => _editPeriodDate(context, entry),
                ),
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: Text(
                  isPostpartum
                      ? 'Log first postpartum period'
                      : 'Add a period date',
                ),
                subtitle: Text(
                  profile.isPregnant && !isPostpartum
                      ? 'Available automatically from the expected due date'
                      : isPostpartum
                      ? 'This ends postpartum mode and starts a new cycle'
                      : 'Choose any previous start day',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                enabled: !profile.isPregnant || isPostpartum,
                onTap: profile.isPregnant && !isPostpartum
                    ? null
                    : () => _addPeriodDate(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'Backup & restore',
            children: [
              _SettingTile(
                icon: Icons.save_alt_rounded,
                label: 'Export backup',
                value: 'Save a copy of your data as a file you keep',
                onTap: () => _exportBackup(context),
              ),
              _SettingTile(
                icon: Icons.restore_page_outlined,
                label: 'Import backup',
                value: 'Restore from a backup file you saved earlier',
                onTap: () => _importBackup(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _PrivacyGroup(),
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
    await controller.updateProfile(profile.copyWith(avatarPath: path));
  }

  Future<void> _enableNotifications(BuildContext context) async {
    final allowed = await controller.enableNotifications();
    if (!context.mounted || allowed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Allow notifications in Android settings to turn reminders on.',
        ),
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

  Future<void> _addPeriodDate(BuildContext context) async {
    final now = appNow();
    final profile = controller.profile!;
    final isPostpartum = profile.isPostpartumOn(now);
    final earliest = isPostpartum ? profile.dueDate! : DateTime(1900);
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: earliest,
      lastDate: now,
      helpText: isPostpartum
          ? 'First period after pregnancy'
          : 'Choose the first day of the period',
    );
    if (picked == null) return;
    await controller.logPeriodStart(picked);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPostpartum
              ? 'Postpartum tracking ended on ${DateFormat.yMMMd().format(picked)}. Cycle tracking resumed.'
              : 'Period start added for ${DateFormat.yMMMd().format(picked)}.',
        ),
      ),
    );
  }

  Future<void> _editNextPeriodDueDate(
    BuildContext context,
    UserProfile profile,
  ) async {
    final action = await showModalBottomSheet<_DueDateAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Next period due date'),
              subtitle: Text(
                profile.nextPeriodDueDate == null
                    ? 'Add the date you currently expect your period to start.'
                    : 'Currently ${DateFormat.yMMMMd().format(profile.nextPeriodDueDate!)}',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: Text(
                profile.nextPeriodDueDate == null
                    ? 'Set expected date'
                    : 'Change expected date',
              ),
              onTap: () => Navigator.pop(sheetContext, _DueDateAction.edit),
            ),
            if (profile.nextPeriodDueDate != null)
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Use automatic estimate'),
                subtitle: const Text('Remove the date you entered'),
                onTap: () => Navigator.pop(sheetContext, _DueDateAction.clear),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == _DueDateAction.clear) {
      await controller.setNextPeriodDueDate(null);
      return;
    }
    final today = appNow();
    final firstDate = profile.lastPeriodStart.add(const Duration(days: 1));
    final automatic = const CycleCalculator()
        .calculate(
          onDate: today,
          lastPeriodStart: profile.lastPeriodStart,
          cycleLength: profile.cycleLength,
          periodLength: profile.periodLength,
          periodStarts: controller.periodStarts,
        )
        .nextPeriod;
    final initial = profile.nextPeriodDueDate ?? automatic;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate) ? firstDate : initial,
      firstDate: firstDate,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Expected next period start',
    );
    if (picked != null) await controller.setNextPeriodDueDate(picked);
  }

  String _periodEntryLabel(PeriodEntry entry) {
    final start = DateFormat.yMMMd().format(entry.startDate);
    final end = entry.endDate;
    if (end == null) return '$start · last day not recorded';
    final duration = entry.durationDays!;
    return '$start – ${DateFormat.yMMMd().format(end)} · $duration ${duration == 1 ? 'day' : 'days'}';
  }

  Future<void> _editPeriodDate(BuildContext context, PeriodEntry entry) async {
    final date = entry.startDate;
    final usualLength = controller.profile!.periodLength;
    final today = appNow();
    final effectiveEnd =
        entry.endDate ?? date.add(Duration(days: usualLength - 1));
    final extraDay = effectiveEnd.add(const Duration(days: 1));
    final canAddDay = !extraDay.isAfter(today);
    final action = await showModalBottomSheet<_PeriodAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.yMMMMd().format(date),
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                entry.endDate == null
                    ? 'Start recorded. Add the last bleeding day to replace the usual $usualLength-day estimate.'
                    : '${entry.durationDays} bleeding ${entry.durationDays == 1 ? 'day' : 'days'} recorded.',
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_calendar_outlined),
                title: const Text('Change date'),
                onTap: () => Navigator.pop(sheetContext, _PeriodAction.edit),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range_outlined),
                title: Text(
                  entry.endDate == null
                      ? 'Set last bleeding day'
                      : 'Change last bleeding day',
                ),
                subtitle: entry.endDate == null
                    ? null
                    : Text(DateFormat.yMMMMd().format(entry.endDate!)),
                onTap: () => Navigator.pop(sheetContext, _PeriodAction.editEnd),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: canAddDay,
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: const Text('Add one more day'),
                subtitle: Text(
                  canAddDay
                      ? 'Last day becomes ${DateFormat.yMMMd().format(extraDay)}'
                      : 'The next day is in the future',
                ),
                onTap: canAddDay
                    ? () => Navigator.pop(sheetContext, _PeriodAction.addDay)
                    : null,
              ),
              if (entry.endDate != null && entry.endDate!.isAfter(date))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.remove_circle_outline_rounded),
                  title: const Text('Remove one day'),
                  subtitle: Text(
                    'Last day becomes ${DateFormat.yMMMd().format(entry.endDate!.subtract(const Duration(days: 1)))}',
                  ),
                  onTap: () =>
                      Navigator.pop(sheetContext, _PeriodAction.removeDay),
                ),
              if (entry.endDate != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Use usual-length estimate'),
                  subtitle: const Text('Remove the recorded last day'),
                  onTap: () =>
                      Navigator.pop(sheetContext, _PeriodAction.clearEnd),
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                enabled: controller.periodStarts.length > 1,
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('Delete entry'),
                subtitle: controller.periodStarts.length > 1
                    ? null
                    : const Text('Keep at least one period start'),
                textColor: Theme.of(sheetContext).colorScheme.error,
                iconColor: Theme.of(sheetContext).colorScheme.error,
                onTap: controller.periodStarts.length > 1
                    ? () => Navigator.pop(sheetContext, _PeriodAction.delete)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == _PeriodAction.delete) {
      await controller.deletePeriodStart(date);
      return;
    }
    if (action == _PeriodAction.addDay) {
      await controller.updatePeriodEnd(date, extraDay);
      return;
    }
    if (action == _PeriodAction.removeDay) {
      await controller.updatePeriodEnd(
        date,
        entry.endDate!.subtract(const Duration(days: 1)),
      );
      return;
    }
    if (action == _PeriodAction.clearEnd) {
      await controller.updatePeriodEnd(date, null);
      return;
    }
    if (action == _PeriodAction.editEnd) {
      final pickedEnd = await showDatePicker(
        context: context,
        initialDate: effectiveEnd.isAfter(today) ? today : effectiveEnd,
        firstDate: date,
        lastDate: today,
        helpText: 'Choose the last bleeding day',
      );
      if (pickedEnd != null) {
        await controller.updatePeriodEnd(date, pickedEnd);
      }
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: date.isAfter(today) ? today : date,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Change period start date',
    );
    if (picked == null || !context.mounted) return;
    try {
      await controller.updatePeriodStart(date, picked);
    } on ArgumentError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? 'Invalid date.')),
      );
    }
  }

  Future<void> _openPregnancySettings(
    BuildContext context,
    UserProfile profile,
  ) async {
    final update = await showModalBottomSheet<_PregnancyUpdate>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PregnancySettingsSheet(profile: profile),
    );
    if (update == null) return;
    await controller.setPregnancyMode(
      enabled: update.enabled,
      dueDate: update.dueDate,
    );
  }

  Future<void> _openLifeStageEditor(
    BuildContext context, [
    LifeStageEntry? existingEntry,
  ]) async {
    final editorResult = await showModalBottomSheet<_LifeStageEditorResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _LifeStageEditorSheet(entry: existingEntry),
    );
    if (!context.mounted || editorResult == null) return;
    if (editorResult.action == _LifeStageEditorAction.save) {
      await _saveLifeStageEntry(context, editorResult.entry);
      return;
    }
    await _confirmLifeStageDelete(context, editorResult.entry);
  }

  Future<void> _saveLifeStageEntry(
    BuildContext context,
    LifeStageEntry entry,
  ) async {
    try {
      await controller.saveLifeStageEntry(entry);
    } on ArgumentError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? 'Invalid range.')),
      );
    }
  }

  Future<void> _confirmLifeStageDelete(
    BuildContext context,
    LifeStageEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${entry.type.label.toLowerCase()} history?'),
        content: const Text(
          'This date range will be removed from the calendar and history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete history'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteLifeStageEntry(entry);
  }

  Future<void> _exportBackup(BuildContext context) async {
    final options = await showModalBottomSheet<_ExportOptions>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => const _ExportBackupSheet(),
    );
    if (options == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final payload = await controller.createBackupPayload();
      final passphrase = options.passphrase;
      final contents = passphrase == null
          ? backupCodec.encode(payload)
          : await backupCodec.encodeEncrypted(payload, passphrase: passphrase);
      await backupService.shareBackup(contents);
      messenger.showSnackBar(
        const SnackBar(content: Text('Backup file ready to save or send.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('The backup could not be created. Please try again.'),
        ),
      );
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final String? contents;
    try {
      contents = await backupService.readPickedBackup();
    } on BackupException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return;
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('That file could not be opened.')),
      );
      return;
    }
    if (contents == null) return;
    final BackupEnvelope envelope;
    try {
      envelope = backupCodec.readEnvelope(contents);
    } on BackupException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!context.mounted) return;
    final payload = envelope.isEncrypted
        ? await _openEncryptedBackup(context, envelope, messenger)
        : await _openBackup(envelope, messenger);
    if (payload == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Text(
          'Restore backup from '
          '${DateFormat.yMMMMd().format(payload.exportedAt)}? This replaces '
          'ALL current data on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await controller.restoreBackup(payload);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Backup from ${DateFormat.yMMMd().format(payload.exportedAt)} '
          'restored.',
        ),
      ),
    );
  }

  Future<BackupPayload?> _openBackup(
    BackupEnvelope envelope,
    ScaffoldMessengerState messenger, {
    String? passphrase,
  }) async {
    try {
      return await backupCodec.open(envelope, passphrase: passphrase);
    } on BackupException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
      return null;
    }
  }

  Future<BackupPayload?> _openEncryptedBackup(
    BuildContext context,
    BackupEnvelope envelope,
    ScaffoldMessengerState messenger,
  ) async {
    String? errorText;
    while (true) {
      final passphrase = await showDialog<String>(
        context: context,
        builder: (dialogContext) => _PassphraseDialog(errorText: errorText),
      );
      if (passphrase == null || !context.mounted) return null;
      try {
        return await backupCodec.open(envelope, passphrase: passphrase);
      } on BackupPassphraseException catch (error) {
        if (!context.mounted) return null;
        errorText = error.message;
      } on BackupException catch (error) {
        messenger.showSnackBar(SnackBar(content: Text(error.message)));
        return null;
      }
    }
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
    final now = appNow();
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
      widget.profile.copyWith(
        name: _nameController.text.trim(),
        dateOfBirth: _dateOfBirth,
        cycleLength: _cycleLength.round(),
        periodLength: _periodLength.round(),
      ),
    );
  }
}

class _ExportOptions {
  const _ExportOptions({this.passphrase});

  /// Null when the person chose to export without encryption.
  final String? passphrase;
}

class _ExportBackupSheet extends StatefulWidget {
  const _ExportBackupSheet();

  @override
  State<_ExportBackupSheet> createState() => _ExportBackupSheetState();
}

class _ExportBackupSheetState extends State<_ExportBackupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _passphraseController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _encrypt = true;

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Export backup',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The file holds your profile, period dates, and history. '
                'Nothing is sent anywhere — you choose where it goes.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Encrypt with passphrase (recommended)'),
                subtitle: Text(
                  _encrypt
                      ? 'You will need this passphrase to restore the file.'
                      : 'The file will be readable as plain text.',
                ),
                value: _encrypt,
                onChanged: (value) => setState(() => _encrypt = value),
              ),
              if (_encrypt) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passphraseController,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Passphrase',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (value) => (value?.length ?? 0) < 6
                      ? 'Use at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'Confirm passphrase',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (value) => value == _passphraseController.text
                      ? null
                      : 'The two passphrases do not match',
                ),
                const SizedBox(height: 8),
                Text(
                  'There is no way to recover a forgotten passphrase.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Without a passphrase, anyone who opens the file can read '
                    'your data.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      height: 1.4,
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _export,
                  child: const Text('Create backup file'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _export() {
    if (_encrypt && !(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _ExportOptions(passphrase: _encrypt ? _passphraseController.text : null),
    );
  }
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({this.errorText});

  final String? errorText;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Enter the backup passphrase'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('This backup is encrypted.'),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          obscureText: true,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Passphrase',
            errorText: widget.errorText,
            errorMaxLines: 3,
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: const Text('Open backup'),
      ),
    ],
  );
}

enum _PeriodAction { edit, editEnd, addDay, removeDay, clearEnd, delete }

enum _DueDateAction { edit, clear }

class _PregnancyUpdate {
  const _PregnancyUpdate({required this.enabled, this.dueDate});

  final bool enabled;
  final DateTime? dueDate;
}

enum _LifeStageEditorAction { save, delete }

class _LifeStageEditorResult {
  const _LifeStageEditorResult({required this.action, required this.entry});

  final _LifeStageEditorAction action;
  final LifeStageEntry entry;
}

class _LifeStageEditorSheet extends StatefulWidget {
  const _LifeStageEditorSheet({this.entry});

  final LifeStageEntry? entry;

  @override
  State<_LifeStageEditorSheet> createState() => _LifeStageEditorSheetState();
}

class _LifeStageEditorSheetState extends State<_LifeStageEditorSheet> {
  late LifeStageType _type;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _type = widget.entry?.type ?? LifeStageType.pregnancy;
    _startDate = widget.entry?.startDate;
    _endDate = widget.entry?.endDate;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.entry == null ? 'Add past history' : 'Edit past history',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a completed range. Current pregnancy tracking stays separate.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _typeSelector(),
            const SizedBox(height: 14),
            _dateSelector(
              Icons.first_page_rounded,
              'Start date',
              _startDate,
              _pickStartDate,
            ),
            _dateSelector(
              Icons.last_page_rounded,
              'End date',
              _endDate,
              _pickEndDate,
            ),
            const SizedBox(height: 14),
            _editorActions(),
          ],
        ),
      ),
    );
  }

  Widget _typeSelector() => SegmentedButton<LifeStageType>(
    segments: const [
      ButtonSegment(
        value: LifeStageType.pregnancy,
        label: Text('Pregnancy'),
        icon: Icon(Icons.favorite_outline_rounded),
      ),
      ButtonSegment(
        value: LifeStageType.postpartum,
        label: Text('Postpartum'),
        icon: Icon(Icons.spa_outlined),
      ),
    ],
    selected: {_type},
    onSelectionChanged: _selectType,
  );

  Widget _dateSelector(
    IconData icon,
    String label,
    DateTime? date,
    VoidCallback onTap,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(_dateLabel(date)),
    trailing: const Icon(Icons.edit_calendar_outlined),
    onTap: onTap,
  );

  Widget _editorActions() => Row(
    children: [
      if (widget.entry != null) ...[
        OutlinedButton.icon(
          onPressed: () => _close(_LifeStageEditorAction.delete),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Delete'),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: FilledButton(
          onPressed: _startDate == null || _endDate == null
              ? null
              : () => _close(_LifeStageEditorAction.save),
          child: const Text('Save history'),
        ),
      ),
    ],
  );

  Future<void> _pickStartDate() async {
    final today = _day(appNow());
    final initialEnd = _endDate ?? today;
    final suggestedDays = switch (_type) {
      LifeStageType.pregnancy => 280,
      LifeStageType.postpartum => 42,
    };
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _startDate ?? initialEnd.subtract(Duration(days: suggestedDays)),
      firstDate: DateTime(1900),
      lastDate: initialEnd,
      helpText: '${_type.label} start date',
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final today = _day(appNow());
    final initialDate = _endDate ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: _startDate ?? DateTime(1900),
      lastDate: today,
      helpText: '${_type.label} end date',
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  void _selectType(Set<LifeStageType> selection) =>
      setState(() => _type = selection.first);

  String _dateLabel(DateTime? date) =>
      date == null ? 'Choose a date' : DateFormat.yMMMMd().format(date);

  void _close(_LifeStageEditorAction action) {
    Navigator.pop(
      context,
      _LifeStageEditorResult(
        action: action,
        entry: LifeStageEntry(
          id: widget.entry?.id,
          type: _type,
          startDate: _startDate!,
          endDate: _endDate!,
        ),
      ),
    );
  }
}

class _PregnancySettingsSheet extends StatefulWidget {
  const _PregnancySettingsSheet({required this.profile});

  final UserProfile profile;

  @override
  State<_PregnancySettingsSheet> createState() =>
      _PregnancySettingsSheetState();
}

class _PregnancySettingsSheetState extends State<_PregnancySettingsSheet> {
  late bool _enabled;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _enabled = widget.profile.isPregnant;
    _dueDate = widget.profile.dueDate;
  }

  @override
  Widget build(BuildContext context) {
    final isPostpartum = widget.profile.isPostpartumOn(appNow());
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPostpartum ? 'Postpartum tracking' : 'Pregnancy mode',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              isPostpartum
                  ? 'Cycle estimates stay paused until the first real period after pregnancy is logged.'
                  : 'Pause period and ovulation estimates while keeping your cycle history safe.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                isPostpartum ? 'Postpartum mode is active' : 'I am pregnant',
              ),
              subtitle: Text(
                isPostpartum && _enabled
                    ? 'Waiting for the first postpartum period'
                    : _enabled
                    ? 'Cycle estimates will be paused'
                    : 'Period tracking is active',
              ),
              value: _enabled,
              onChanged: isPostpartum
                  ? null
                  : (value) => setState(() => _enabled = value),
            ),
            if (isPostpartum)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Postpartum mode ends automatically when you log your first period.',
                ),
              ),
            if (_enabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Expected due date'),
                subtitle: Text(
                  _dueDate == null
                      ? 'Not added'
                      : DateFormat.yMMMMd().format(_dueDate!),
                ),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: isPostpartum ? null : _pickDueDate,
              ),
            if (_enabled && _dueDate == null)
              Text(
                'Add a due date so Postpartum mode can start automatically.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_enabled && _dueDate != null && !isPostpartum)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _dueDate = null),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Remove due date'),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _enabled && _dueDate == null
                    ? null
                    : () => Navigator.pop(
                        context,
                        isPostpartum
                            ? null
                            : _PregnancyUpdate(
                                enabled: _enabled,
                                dueDate: _enabled ? _dueDate : null,
                              ),
                      ),
                child: Text(isPostpartum ? 'Close' : 'Save tracking status'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final today = appNow();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today.add(const Duration(days: 140)),
      firstDate: DateTime(1900),
      lastDate: today.add(const Duration(days: 730)),
      helpText: 'Expected due date',
    );
    if (picked != null) setState(() => _dueDate = picked);
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
    child: ExpansionTile(
      key: PageStorageKey<String>('profile-section-$title'),
      initiallyExpanded: true,
      maintainState: true,
      tilePadding: const EdgeInsets.fromLTRB(18, 4, 10, 4),
      childrenPadding: const EdgeInsets.only(bottom: 6),
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w900,
          letterSpacing: .7,
        ),
      ),
      children: [
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        ...children,
      ],
    ),
  );
}

class _PrivacyGroup extends StatelessWidget {
  const _PrivacyGroup();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF1E332B)
        : const Color(0xFFF0F7F4);
    final accent = isDark ? const Color(0xFF7FC7AC) : const Color(0xFF26715A);
    final titleColor = isDark
        ? const Color(0xFFA5D6C1)
        : const Color(0xFF225B49);
    final bodyColor = isDark
        ? const Color(0xFF9CC0B1)
        : const Color(0xFF3A6758);
    return Material(
      color: background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey<String>('profile-section-privacy'),
        initiallyExpanded: true,
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: accent,
        collapsedIconColor: accent,
        leading: Icon(Icons.shield_outlined, color: accent),
        title: Text(
          'Private by design',
          style: TextStyle(color: titleColor, fontWeight: FontWeight.w800),
        ),
        children: [
          Text(
            'Your profile and cycle history are stored only on this device. Android cloud backup is disabled.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: bodyColor, height: 1.4),
          ),
        ],
      ),
    );
  }
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
    subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);
