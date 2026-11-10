import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/theme_controller.dart';
import '../../core/theme/app_theme.dart';

/// Appearance choices: follow the phone (null), or a fixed light/dark theme.
const _choices = <AppThemeVariant?>[null, ...availableAppThemeVariants];

String _label(AppThemeVariant? variant) => variant?.label ?? 'Match phone';
IconData _icon(AppThemeVariant? variant) =>
    variant?.icon ?? Icons.brightness_auto_outlined;

class ThemeSwitcher extends ConsumerWidget {
  const ThemeSwitcher({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeControllerProvider);
    if (compact) {
      return Semantics(
        label: 'Theme selection. Current theme ${_label(selected)}',
        button: true,
        child: PopupMenuButton<int>(
          key: const ValueKey('theme-switcher-compact'),
          tooltip: 'Choose appearance',
          icon: Icon(_icon(selected)),
          onSelected: (index) => ref
              .read(themeControllerProvider.notifier)
              .select(_choices[index]),
          itemBuilder: (context) => _choices.indexed
              .map(
                (entry) => PopupMenuItem(
                  value: entry.$1,
                  child: Row(
                    children: [
                      Icon(_icon(entry.$2)),
                      const SizedBox(width: 10),
                      Text(_label(entry.$2)),
                      const Spacer(),
                      if (entry.$2 == selected)
                        const Icon(Icons.check, semanticLabel: 'Selected'),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      );
    }
    return Semantics(
      label: 'Choose app theme',
      child: LayoutBuilder(
        key: const ValueKey('theme-switcher'),
        builder: (context, constraints) {
          const gap = 10.0;
          final columns = constraints.maxWidth >= 520 ? 2 : 1;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: _choices
                .map(
                  (variant) => SizedBox(
                    width: width,
                    child: _ThemeOption(
                      variant: variant,
                      selected: selected == variant,
                      onTap: () => ref
                          .read(themeControllerProvider.notifier)
                          .select(variant),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.variant,
    required this.selected,
    required this.onTap,
  });

  final AppThemeVariant? variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Theme(
    data: variant == null ? Theme.of(context) : AppTheme.forVariant(variant!),
    child: Builder(
      builder: (context) {
        final product = context.product;
        return Semantics(
          button: true,
          selected: selected,
          label: '${_label(variant)} theme',
          child: Material(
            color: product.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(product.radius.clamp(2, 14)),
              side: BorderSide(
                color: selected ? product.action : product.border,
                width: selected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('theme-option-${variant?.name ?? 'system'}'),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: product.subtle,
                        borderRadius: BorderRadius.circular(
                          product.panelTreatment == PanelTreatment.flat
                              ? 999
                              : product.radius.clamp(2, 10),
                        ),
                        border: Border.all(color: product.border),
                      ),
                      child: Icon(
                        _icon(variant),
                        size: 19,
                        color: product.action,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _label(variant),
                            style: TextStyle(
                              color: product.ink,
                              fontFamily: product.headingFontFamily,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            variant?.description ??
                                'Light or dark, following your phone setting',
                            style: TextStyle(
                              color: product.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected ? Icons.check_circle : Icons.circle_outlined,
                      size: 20,
                      color: selected ? product.action : product.muted,
                      semanticLabel: selected ? 'Selected' : 'Not selected',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
