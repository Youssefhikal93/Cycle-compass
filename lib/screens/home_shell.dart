import 'package:flutter/material.dart';

import '../app_controller.dart';
import 'calendar_screen.dart';
import 'learn_screen.dart';
import 'profile_screen.dart';
import 'today_screen.dart';

/// Whether the Learn tab is part of the bottom navigation.
///
/// The educational content is hidden from the shell for now while it is being
/// revised. `learn_screen.dart` stays in the codebase, and the Today screen
/// keeps its own inline phase explanations, so nothing is lost by hiding it.
const bool showLearnTab = false;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _offerNotificationPermission(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.today_outlined),
        selectedIcon: Icon(Icons.today_rounded),
        label: 'Today',
      ),
      const NavigationDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month_rounded),
        label: 'Calendar',
      ),
      if (showLearnTab)
        const NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book_rounded),
          label: 'Learn',
        ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];
    // Profile is always the last destination, so its index follows whichever
    // tabs were built instead of being hard-coded.
    final profileIndex = destinations.length - 1;
    final pages = <Widget>[
      TodayScreen(
        controller: widget.controller,
        onOpenProfile: () => setState(() => _index = profileIndex),
      ),
      CalendarScreen(controller: widget.controller),
      if (showLearnTab) const LearnScreen(),
      ProfileScreen(controller: widget.controller),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: destinations,
      ),
    );
  }

  Future<void> _offerNotificationPermission() async {
    if (!mounted || !widget.controller.needsNotificationPermission) return;
    final allow = await _showNotificationPermissionDialog();
    if (allow != true) {
      await widget.controller.disableNotifications();
      return;
    }
    final allowed = await widget.controller.enableNotifications();
    if (!mounted || allowed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Notifications remain off because Android permission was not granted.',
        ),
      ),
    );
  }

  Future<bool?> _showNotificationPermissionDialog() => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: _notificationPermissionDialog,
  );

  Widget _notificationPermissionDialog(BuildContext dialogContext) =>
      AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined),
        title: const Text('Allow cycle reminders?'),
        content: const Text(
          'Cycle Compass can notify you when each estimated phase begins, '
          'including ovulation, even while the app is closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Allow reminders'),
          ),
        ],
      );
}
