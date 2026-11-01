import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:medical24/core/models/user_profile.dart';
import 'package:medical24/core/providers/app_providers.dart';
import 'package:medical24/core/router/app_routes.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/branding.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/headers.dart';
import 'package:medical24/core/widgets/app_add_action.dart';
import 'package:medical24/core/widgets/app_breadcrumb.dart';
import 'package:medical24/features/health/providers/health_providers.dart';
import 'package:medical24/features/admin/providers/admin_providers.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

class AppShellDestination {
  const AppShellDestination({required this.labelKey, required this.desktopLabelKey, required this.icon, required this.route});
  final String labelKey;
  final String desktopLabelKey;
  final IconData icon;
  final String route;
}

const List<AppShellDestination> kAppShellDestinations = <AppShellDestination>[
  AppShellDestination(labelKey: 'navHome', desktopLabelKey: 'navOverview', icon: M24Icons.home, route: AppRoutes.home),
  AppShellDestination(labelKey: 'navHealth', desktopLabelKey: 'navMyHealth', icon: M24Icons.health, route: AppRoutes.health),
  AppShellDestination(labelKey: 'navArchive', desktopLabelKey: 'navArchive', icon: M24Icons.archive, route: AppRoutes.archive),
  AppShellDestination(labelKey: 'navTreatments', desktopLabelKey: 'navTreatments', icon: M24Icons.treatments, route: AppRoutes.treatments),
  AppShellDestination(labelKey: 'navDoctor', desktopLabelKey: 'navDoctor', icon: M24Icons.doctor, route: AppRoutes.doctor),
];

/// Single adaptive shell for phone, tablet and full HD desktop.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell, required this.currentIndex, required this.onDestinationSelected});
  final Widget navigationShell;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double width = MediaQuery.sizeOf(context).width;
    final String path = _currentPath(context, currentIndex);
    final UserProfile? profile = ref.watch(myProfileProvider).value;
    final int unread = ref.watch(unreadAlertsProvider).value ?? 0;
    final String initials = _initials(profile?.fullName);
    final VoidCallback openAlerts = () => context.push(AppRoutes.alerts);
    final VoidCallback openProfileMenu = () => _showProfileMenu(context, ref);
    if (width >= 1200) return DesktopAppShell(currentIndex: currentIndex, onDestinationSelected: onDestinationSelected, path: path, unreadAlerts: unread, initials: initials, onAlerts: openAlerts, onProfile: openProfileMenu, child: navigationShell);
    if (width >= 600) return TabletAppShell(currentIndex: currentIndex, onDestinationSelected: onDestinationSelected, path: path, unreadAlerts: unread, initials: initials, onAlerts: openAlerts, onProfile: openProfileMenu, child: navigationShell);
    return PhoneAppShell(currentIndex: currentIndex, onDestinationSelected: onDestinationSelected, path: path, unreadAlerts: unread, initials: initials, onAlerts: openAlerts, onProfile: openProfileMenu, child: navigationShell);
  }

  static String _currentPath(BuildContext context, int index) {
    final GoRouter? router = GoRouter.maybeOf(context);
    return router?.routerDelegate.currentConfiguration.uri.path ?? kAppShellDestinations[index].route;
  }

  static String _initials(String? fullName) {
    final List<String> parts = (fullName ?? '').trim().split(RegExp(r'\s+')).where((String part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'M24';
    return parts.take(2).map((String part) => part[0].toUpperCase()).join();
  }

  static Future<void> _showProfileMenu(BuildContext context, WidgetRef ref) async {
    final Size size = MediaQuery.sizeOf(context);
    final _ProfileAction? action = await showMenu<_ProfileAction>(context: context, position: RelativeRect.fromLTRB(size.width - 220, 56, 16, 0), items: <PopupMenuEntry<_ProfileAction>>[
      PopupMenuItem<_ProfileAction>(value: _ProfileAction.profile, child: Row(children: <Widget>[const Icon(M24Icons.profile, size: 20), const SizedBox(width: 12), Text(context.l10n.t('navProfile'))])),
      PopupMenuItem<_ProfileAction>(value: _ProfileAction.doctor, child: Row(children: <Widget>[const Icon(M24Icons.doctor, size: 20), const SizedBox(width: 12), Text(context.l10n.t('navMyDoctor'))])),
      PopupMenuItem<_ProfileAction>(value: _ProfileAction.settings, child: Row(children: <Widget>[const Icon(M24Icons.settings, size: 20), const SizedBox(width: 12), Text(context.l10n.t('navSettings'))])),
      PopupMenuItem<_ProfileAction>(value: _ProfileAction.signOut, child: Row(children: <Widget>[const Icon(M24Icons.signOut, size: 20), const SizedBox(width: 12), Text(context.l10n.t('authSignOut'))])),
    ]);
    if (!context.mounted || action == null) return;
    if (action == _ProfileAction.profile) context.push(AppRoutes.settingsProfile);
    if (action == _ProfileAction.doctor) context.go(AppRoutes.doctor);
    if (action == _ProfileAction.settings) context.push(AppRoutes.settings);
    if (action == _ProfileAction.signOut) await ref.read(authRepositoryProvider).signOut();
  }
}

enum _ProfileAction { profile, doctor, settings, signOut }

class PhoneAppShell extends StatelessWidget {
  const PhoneAppShell({super.key, required this.currentIndex, required this.onDestinationSelected, required this.path, required this.unreadAlerts, required this.initials, required this.onAlerts, required this.onProfile, required this.child});
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final String path;
  final int unreadAlerts;
  final String initials;
  final VoidCallback onAlerts;
  final VoidCallback onProfile;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool firstLevel = kAppShellDestinations.any((AppShellDestination destination) => destination.route == path);
    return Scaffold(
      body: SafeArea(child: Column(children: <Widget>[
        if (firstLevel) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: M24AppHeader(initials: initials, hasUnreadAlerts: unreadAlerts > 0, bellTooltip: context.l10n.t('alertsTitle'), avatarTooltip: context.l10n.t('navProfile'), onBellPressed: onAlerts, onAvatarPressed: onProfile)),
        Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 20), child: child)),
      ])),
      floatingActionButton: const AppAddFloatingButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: M24BottomBar(currentIndex: currentIndex, unreadAlerts: unreadAlerts, onDestinationSelected: onDestinationSelected),
    );
  }
}

class M24BottomBar extends StatelessWidget {
  const M24BottomBar({super.key, required this.currentIndex, required this.unreadAlerts, required this.onDestinationSelected});
  final int currentIndex;
  final int unreadAlerts;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    const List<int> phoneDestinationIndices = <int>[0, 1, 2, 3];
    return BottomAppBar(
      height: 64 + MediaQuery.paddingOf(context).bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      color: context.m24.colors.surface,
      surfaceTintColor: context.m24.colors.surface,
      elevation: 0,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: context.m24.colors.border))),
        child: Row(children: <Widget>[
          for (final int index in phoneDestinationIndices.take(2)) Expanded(child: M24BottomBarItem(destination: kAppShellDestinations[index], selected: currentIndex == index, alertCount: index == 1 ? unreadAlerts : 0, onTap: () => onDestinationSelected(index))),
          const SizedBox(width: 72),
          for (final int index in phoneDestinationIndices.skip(2)) Expanded(child: M24BottomBarItem(destination: kAppShellDestinations[index], selected: currentIndex == index, onTap: () => onDestinationSelected(index))),
        ]),
      ),
    );
  }
}

class M24BottomBarItem extends StatelessWidget {
  const M24BottomBarItem({super.key, required this.destination, required this.selected, required this.onTap, this.alertCount = 0});
  final AppShellDestination destination;
  final bool selected;
  final VoidCallback onTap;
  final int alertCount;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? context.m24.colors.primary : context.m24.colors.inkSecondary;
    return Semantics(selected: selected, button: true, label: context.l10n.t(destination.labelKey), child: InkWell(
      onTap: onTap,
      hoverColor: context.m24.colors.surfaceAlt,
      focusColor: context.m24.colors.focusRing,
      child: SizedBox(height: 64, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        Container(width: 44, height: 32, alignment: Alignment.center, decoration: BoxDecoration(color: selected ? context.m24.colors.primarySoft : context.m24.colors.surface, borderRadius: BorderRadius.circular(10)), child: ShellNavigationIcon(icon: destination.icon, count: alertCount, child: Icon(destination.icon, size: 24, color: color))),
        Text(context.l10n.t(destination.labelKey), maxLines: 1, overflow: TextOverflow.ellipsis, style: context.m24.text.navLabel.copyWith(color: color)),
      ])),
    ));
  }
}

class TabletAppShell extends StatelessWidget {
  const TabletAppShell({super.key, required this.currentIndex, required this.onDestinationSelected, required this.path, required this.unreadAlerts, required this.initials, required this.onAlerts, required this.onProfile, required this.child});
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final String path;
  final int unreadAlerts;
  final String initials;
  final VoidCallback onAlerts;
  final VoidCallback onProfile;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool firstLevel = kAppShellDestinations.any((AppShellDestination destination) => destination.route == path);
    return Scaffold(
      body: SafeArea(child: Row(children: <Widget>[
        Container(width: 80, decoration: BoxDecoration(color: context.m24.colors.surface, border: Border(right: BorderSide(color: context.m24.colors.border))), child: NavigationRail(
          minWidth: 80,
          selectedIndex: currentIndex,
          leading: const Padding(padding: EdgeInsets.only(bottom: 16), child: AppAddFloatingButton()),
          labelType: NavigationRailLabelType.all,
          onDestinationSelected: onDestinationSelected,
          destinations: <NavigationRailDestination>[
            for (final AppShellDestination destination in kAppShellDestinations) NavigationRailDestination(icon: ShellNavigationIcon(icon: destination.icon, count: destination.route == AppRoutes.health ? unreadAlerts : 0), selectedIcon: ShellNavigationIcon(icon: destination.icon, count: destination.route == AppRoutes.health ? unreadAlerts : 0), label: Text(context.l10n.t(destination.labelKey))),
          ],
        )),
        Expanded(child: Column(children: <Widget>[
          if (firstLevel) Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: M24AppHeader(initials: initials, hasUnreadAlerts: unreadAlerts > 0, bellTooltip: context.l10n.t('alertsTitle'), avatarTooltip: context.l10n.t('navProfile'), onBellPressed: onAlerts, onAvatarPressed: onProfile)),
          Expanded(child: child),
        ])),
      ])),
    );
  }
}

class DesktopAppShell extends StatelessWidget {
  const DesktopAppShell({super.key, required this.currentIndex, required this.onDestinationSelected, required this.path, required this.unreadAlerts, required this.initials, required this.onAlerts, required this.onProfile, required this.child});
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final String path;
  final int unreadAlerts;
  final String initials;
  final VoidCallback onAlerts;
  final VoidCallback onProfile;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(body: Shortcuts(
    shortcuts: <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.digit1, alt: true): const GoToSectionIntent(0),
      const SingleActivator(LogicalKeyboardKey.digit2, alt: true): const GoToSectionIntent(1),
      const SingleActivator(LogicalKeyboardKey.digit3, alt: true): const GoToSectionIntent(2),
      const SingleActivator(LogicalKeyboardKey.digit4, alt: true): const GoToSectionIntent(3),
      const SingleActivator(LogicalKeyboardKey.digit5, alt: true): const GoToSectionIntent(4),
    },
    child: Actions(actions: <Type, Action<Intent>>{GoToSectionIntent: CallbackAction<GoToSectionIntent>(onInvoke: (GoToSectionIntent intent) { onDestinationSelected(intent.index); return null; })}, child: Focus(autofocus: true, child: Row(children: <Widget>[
      M24Sidebar(currentIndex: currentIndex, path: path, onDestinationSelected: onDestinationSelected),
        Expanded(child: Column(children: <Widget>[
        M24TopBar(unreadAlerts: unreadAlerts, initials: initials, onAlerts: onAlerts, onProfile: onProfile),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: child)),
      ])),
    ]))),
  ));
}

class GoToSectionIntent extends Intent {
  const GoToSectionIntent(this.index);
  final int index;
}

class M24Sidebar extends ConsumerWidget {
  const M24Sidebar({super.key, required this.currentIndex, required this.path, required this.onDestinationSelected});
  final int currentIndex;
  final String path;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    width: 220,
    decoration: BoxDecoration(color: context.m24.colors.surface, border: Border(right: BorderSide(color: context.m24.colors.border))),
    child: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
      const Align(alignment: Alignment.centerLeft, child: M24Logo()),
      const SizedBox(height: 20),
      const AppAddActionButton(extended: true),
      const SizedBox(height: 20),
      for (int i = 0; i < kAppShellDestinations.length; i++) ...<Widget>[
        M24SidebarItem(icon: kAppShellDestinations[i].icon, label: context.l10n.t(kAppShellDestinations[i].desktopLabelKey), selected: i == currentIndex && (i != 1 || !path.startsWith(AppRoutes.prevention)), onTap: () => onDestinationSelected(i)),
        if (i == 1) M24SidebarItem(icon: M24Icons.prevention, label: context.l10n.preventionNav, selected: path.startsWith(AppRoutes.prevention), indent: 24, onTap: () => context.go(AppRoutes.prevention)),
      ],
      if (ref.watch(isAdminProvider).value == true) M24SidebarItem(icon: M24Icons.government, label: context.l10n.adminGovernment, onTap: () => context.go(AppRoutes.adminOverview)),
      const Spacer(),
      Divider(color: context.m24.colors.divider),
      M24SidebarItem(icon: M24Icons.help, label: context.l10n.t('navHelp'), onTap: () => context.push(AppRoutes.settings)),
      M24SidebarItem(icon: M24Icons.settings, label: context.l10n.t('navSettings'), onTap: () => context.push(AppRoutes.settings)),
    ]))),
  );
}

class M24SidebarItem extends StatelessWidget {
  const M24SidebarItem({super.key, required this.icon, required this.label, required this.onTap, this.selected = false, this.indent = 0});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final double indent;

  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(bottom: 4, left: indent), child: Material(
    color: selected ? context.m24.colors.primarySoft : context.m24.colors.surface,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(onTap: onTap, hoverColor: context.m24.colors.surfaceAlt, focusColor: context.m24.colors.focusRing, borderRadius: BorderRadius.circular(12), child: SizedBox(height: 44, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: <Widget>[
      Icon(icon, size: 20, color: selected ? context.m24.colors.primary : context.m24.colors.inkSecondary),
      const SizedBox(width: 12),
      Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: context.m24.text.navLabel.copyWith(color: selected ? context.m24.colors.primary : context.m24.colors.inkSecondary))),
    ])))),
  ));
}

class M24TopBar extends StatelessWidget {
  const M24TopBar({super.key, required this.unreadAlerts, required this.initials, required this.onAlerts, required this.onProfile});
  final int unreadAlerts;
  final String initials;
  final VoidCallback onAlerts;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) => SizedBox(height: 64, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child: Row(children: <Widget>[
    const Expanded(child: AppBreadcrumb()),
    ShellNavigationIcon(icon: M24Icons.bell, count: unreadAlerts, child: M24IconButton(icon: M24Icons.bell, tooltip: context.l10n.t('alertsTitle'), onPressed: onAlerts)),
    const SizedBox(width: 8),
    Tooltip(message: context.l10n.t('navProfile'), child: M24Avatar(initials: initials, onPressed: onProfile)),
  ])));
}

class ShellNavigationIcon extends StatelessWidget {
  const ShellNavigationIcon({super.key, required this.icon, this.count = 0, this.child});
  final IconData icon;
  final int count;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: <Widget>[
    child ?? Icon(icon, size: 24),
    if (count > 0) Positioned(right: -8, top: -6, child: Container(constraints: const BoxConstraints(minWidth: 16, minHeight: 16), padding: const EdgeInsets.symmetric(horizontal: 3), decoration: BoxDecoration(color: context.m24.colors.warning, borderRadius: BorderRadius.circular(999)), alignment: Alignment.center, child: Text(count > 99 ? '99+' : '$count', style: context.m24.text.caption.copyWith(fontSize: 11, height: 1, fontWeight: FontWeight.w600, color: M24Colors.white)))),
  ]);
}