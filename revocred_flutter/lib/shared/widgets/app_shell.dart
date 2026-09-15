import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'app_logo.dart';
import 'theme_switcher.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  static const destinations = [
    (label: 'Home', shortLabel: 'Home', icon: Icons.home_outlined),
    (label: 'Cards', shortLabel: 'Cards', icon: Icons.credit_card_outlined),
    (label: 'Strategy', shortLabel: 'Plan', icon: Icons.route_outlined),
    (label: 'Ask REVO', shortLabel: 'REVO', icon: Icons.auto_awesome_outlined),
    (label: 'Profile', shortLabel: 'Profile', icon: Icons.person_outline),
  ];

  void _select(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final extendedRail = MediaQuery.sizeOf(context).width >= 1180;
    final narrow = MediaQuery.sizeOf(context).width < 360;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final product = context.product;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (desktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
              extended: extendedRail,
              leading: Padding(
                padding: EdgeInsets.fromLTRB(12, 18, 12, product.sectionGap),
                child: AppLogo(compact: !extendedRail),
              ),
              trailing: const Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 18),
                    child: ThemeSwitcher(compact: true),
                  ),
                ),
              ),
              destinations: destinations
                  .map(
                    (item) => NavigationRailDestination(
                      icon: _NavigationIcon(label: item.label, icon: item.icon),
                      selectedIcon: _NavigationIcon(
                        label: item.label,
                        icon: item.icon,
                        selected: true,
                      ),
                      label: Text(item.label),
                    ),
                  )
                  .toList(),
            ),
            VerticalDivider(width: 1, color: product.border),
            Expanded(
              child: _BranchTransition(
                index: navigationShell.currentIndex,
                child: navigationShell,
              ),
            ),
          ],
        ),
      );
    }
    final navigation = NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: _select,
      destinations: destinations
          .map(
            (item) => NavigationDestination(
              icon: _NavigationIcon(label: item.label, icon: item.icon),
              selectedIcon: _NavigationIcon(
                label: item.label,
                icon: item.icon,
                selected: true,
              ),
              label: narrow ? item.shortLabel : item.label,
            ),
          )
          .toList(),
    );
    final bottomNavigation = switch (product.navigationTreatment) {
      NavigationTreatment.floating => Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: navigation,
        ),
      ),
      NavigationTreatment.editorial => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: product.ink, width: 2),
            bottom: BorderSide(color: product.border),
          ),
        ),
        child: navigation,
      ),
      NavigationTreatment.technical => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: product.action, width: 1)),
        ),
        child: navigation,
      ),
      NavigationTreatment.wallet => DecoratedBox(
        decoration: BoxDecoration(
          color: product.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .3 : .06),
              blurRadius: 14,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: navigation,
      ),
      NavigationTreatment.understated => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: product.border)),
        ),
        child: navigation,
      ),
    };
    return Scaffold(
      body: _BranchTransition(
        index: navigationShell.currentIndex,
        child: navigationShell,
      ),
      bottomNavigationBar: keyboardOpen ? null : bottomNavigation,
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({
    required this.label,
    required this.icon,
    this.selected = false,
  });

  final String label;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final color = selected
        ? product.navigationTreatment == NavigationTreatment.floating
              ? product.actionInk
              : product.action
        : product.muted;
    final markerWidth = switch (product.navigationTreatment) {
      NavigationTreatment.editorial => 22.0,
      NavigationTreatment.technical => 5.0,
      NavigationTreatment.wallet => 0.0,
      _ => 12.0,
    };
    return SizedBox(
      key: ValueKey(
        'nav-${label.toLowerCase().replaceAll(' ', '-')}-${selected ? 'selected' : 'idle'}',
      ),
      width: 30,
      height: 29,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 21, color: color),
          const SizedBox(height: 3),
          SizedBox(
            width: markerWidth,
            height: 2,
            child: selected
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(
                        product.navigationTreatment ==
                                NavigationTreatment.technical
                            ? 0
                            : 1,
                      ),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _BranchTransition extends StatelessWidget {
  const _BranchTransition({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey('branch-transition-$index'),
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 150),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 5 * (1 - value)),
        child: child,
      ),
    ),
  );
}
