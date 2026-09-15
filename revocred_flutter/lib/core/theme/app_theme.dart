import 'package:flutter/material.dart';

enum AppThemeVariant {
  clear,
  marketPulse,
  editorialWealth,
  dataTerminal,
  walletFlow,
  walletStudio,
  decisionFlow,
  decisionFlowDark,
}

const availableAppThemeVariants = [
  AppThemeVariant.decisionFlow,
  AppThemeVariant.decisionFlowDark,
];

enum PanelTreatment { outlined, flat, paper, technical, wallet }

enum HeroTreatment {
  balanced,
  market,
  editorial,
  terminal,
  wallet,
  walletStudio,
  decision,
}

enum NavigationTreatment { understated, floating, editorial, technical, wallet }

enum ChatTreatment { document, bubbles, editorial, console, wallet }

extension AppThemeVariantDetails on AppThemeVariant {
  String get label => switch (this) {
    AppThemeVariant.clear => 'Revo Current',
    AppThemeVariant.marketPulse => 'Market Pulse',
    AppThemeVariant.editorialWealth => 'Editorial Wealth',
    AppThemeVariant.dataTerminal => 'Data Terminal',
    AppThemeVariant.walletFlow => 'Wallet Flow',
    AppThemeVariant.walletStudio => 'Wallet Studio',
    AppThemeVariant.decisionFlow => 'Light',
    AppThemeVariant.decisionFlowDark => 'Dark',
  };

  String get description => switch (this) {
    AppThemeVariant.clear => 'The balanced RevoCred interface you know',
    AppThemeVariant.marketPulse => 'Fast, bold, and market-driven',
    AppThemeVariant.editorialWealth => 'Warm, considered, and premium',
    AppThemeVariant.dataTerminal => 'Dense, technical, and analytical',
    AppThemeVariant.walletFlow => 'Bright, compact, and wallet-first',
    AppThemeVariant.walletStudio => 'Refined, branded, and card-first',
    AppThemeVariant.decisionFlow => 'Bright, focused, and action-oriented',
    AppThemeVariant.decisionFlowDark =>
      'Low-glare focus with the same workflow',
  };

  String get previewLine => switch (this) {
    AppThemeVariant.clear => 'Clear financial decisions without the noise',
    AppThemeVariant.marketPulse => 'Your wallet, moving at market speed',
    AppThemeVariant.editorialWealth =>
      'A considered view of your financial life',
    AppThemeVariant.dataTerminal =>
      'Deterministic signals. Transparent output.',
    AppThemeVariant.walletFlow => 'Your complete card strategy at a glance',
    AppThemeVariant.walletStudio => 'A sharper home for every card decision',
    AppThemeVariant.decisionFlow =>
      'Know which card to use and what comes next',
    AppThemeVariant.decisionFlowDark =>
      'The same decisions in a focused dark interface',
  };

  IconData get icon => switch (this) {
    AppThemeVariant.clear => Icons.dashboard_customize_outlined,
    AppThemeVariant.marketPulse => Icons.show_chart,
    AppThemeVariant.editorialWealth => Icons.auto_stories_outlined,
    AppThemeVariant.dataTerminal => Icons.terminal,
    AppThemeVariant.walletFlow => Icons.account_balance_wallet_outlined,
    AppThemeVariant.walletStudio => Icons.style_outlined,
    AppThemeVariant.decisionFlow => Icons.light_mode_outlined,
    AppThemeVariant.decisionFlowDark => Icons.dark_mode_outlined,
  };
}

@immutable
class ProductTheme extends ThemeExtension<ProductTheme> {
  const ProductTheme({
    required this.variant,
    required this.canvas,
    required this.surface,
    required this.subtle,
    required this.raised,
    required this.ink,
    required this.muted,
    required this.border,
    required this.action,
    required this.actionInk,
    required this.brightAccent,
    required this.secondary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.userQuery,
    required this.pagePadding,
    required this.sectionGap,
    required this.panelPadding,
    required this.radius,
    required this.cardStackOffset,
    required this.compact,
    required this.bodyFontFamily,
    required this.headingFontFamily,
    required this.panelTreatment,
    required this.heroTreatment,
    required this.navigationTreatment,
    required this.chatTreatment,
  });

  final AppThemeVariant variant;
  final Color canvas;
  final Color surface;
  final Color subtle;
  final Color raised;
  final Color ink;
  final Color muted;
  final Color border;
  final Color action;
  final Color actionInk;
  final Color brightAccent;
  final Color secondary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color userQuery;
  final double pagePadding;
  final double sectionGap;
  final double panelPadding;
  final double radius;
  final double cardStackOffset;
  final bool compact;
  final String bodyFontFamily;
  final String headingFontFamily;
  final PanelTreatment panelTreatment;
  final HeroTreatment heroTreatment;
  final NavigationTreatment navigationTreatment;
  final ChatTreatment chatTreatment;

  @override
  ProductTheme copyWith({
    AppThemeVariant? variant,
    Color? canvas,
    Color? surface,
    Color? subtle,
    Color? raised,
    Color? ink,
    Color? muted,
    Color? border,
    Color? action,
    Color? actionInk,
    Color? brightAccent,
    Color? secondary,
    Color? success,
    Color? warning,
    Color? danger,
    Color? userQuery,
    double? pagePadding,
    double? sectionGap,
    double? panelPadding,
    double? radius,
    double? cardStackOffset,
    bool? compact,
    String? bodyFontFamily,
    String? headingFontFamily,
    PanelTreatment? panelTreatment,
    HeroTreatment? heroTreatment,
    NavigationTreatment? navigationTreatment,
    ChatTreatment? chatTreatment,
  }) => ProductTheme(
    variant: variant ?? this.variant,
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    subtle: subtle ?? this.subtle,
    raised: raised ?? this.raised,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
    border: border ?? this.border,
    action: action ?? this.action,
    actionInk: actionInk ?? this.actionInk,
    brightAccent: brightAccent ?? this.brightAccent,
    secondary: secondary ?? this.secondary,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    userQuery: userQuery ?? this.userQuery,
    pagePadding: pagePadding ?? this.pagePadding,
    sectionGap: sectionGap ?? this.sectionGap,
    panelPadding: panelPadding ?? this.panelPadding,
    radius: radius ?? this.radius,
    cardStackOffset: cardStackOffset ?? this.cardStackOffset,
    compact: compact ?? this.compact,
    bodyFontFamily: bodyFontFamily ?? this.bodyFontFamily,
    headingFontFamily: headingFontFamily ?? this.headingFontFamily,
    panelTreatment: panelTreatment ?? this.panelTreatment,
    heroTreatment: heroTreatment ?? this.heroTreatment,
    navigationTreatment: navigationTreatment ?? this.navigationTreatment,
    chatTreatment: chatTreatment ?? this.chatTreatment,
  );

  @override
  ProductTheme lerp(covariant ProductTheme? other, double t) {
    if (other == null) return this;
    return ProductTheme(
      variant: t < .5 ? variant : other.variant,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      raised: Color.lerp(raised, other.raised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      border: Color.lerp(border, other.border, t)!,
      action: Color.lerp(action, other.action, t)!,
      actionInk: Color.lerp(actionInk, other.actionInk, t)!,
      brightAccent: Color.lerp(brightAccent, other.brightAccent, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      userQuery: Color.lerp(userQuery, other.userQuery, t)!,
      pagePadding: _lerpDouble(pagePadding, other.pagePadding, t),
      sectionGap: _lerpDouble(sectionGap, other.sectionGap, t),
      panelPadding: _lerpDouble(panelPadding, other.panelPadding, t),
      radius: _lerpDouble(radius, other.radius, t),
      cardStackOffset: _lerpDouble(cardStackOffset, other.cardStackOffset, t),
      compact: t < .5 ? compact : other.compact,
      bodyFontFamily: t < .5 ? bodyFontFamily : other.bodyFontFamily,
      headingFontFamily: t < .5 ? headingFontFamily : other.headingFontFamily,
      panelTreatment: t < .5 ? panelTreatment : other.panelTreatment,
      heroTreatment: t < .5 ? heroTreatment : other.heroTreatment,
      navigationTreatment: t < .5
          ? navigationTreatment
          : other.navigationTreatment,
      chatTreatment: t < .5 ? chatTreatment : other.chatTreatment,
    );
  }

  static double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
}

extension ProductThemeContext on BuildContext {
  ProductTheme get product => Theme.of(this).extension<ProductTheme>()!;
}

abstract final class AppTheme {
  static const _current = ProductTheme(
    variant: AppThemeVariant.clear,
    canvas: Color(0xFFF7F8FC),
    surface: Color(0xFFFFFFFF),
    subtle: Color(0xFFEEF2FF),
    raised: Color(0xFFE5EBFA),
    ink: Color(0xFF10182B),
    muted: Color(0xFF53617D),
    border: Color(0xFFD7DEEF),
    action: Color(0xFF3F57C4),
    actionInk: Colors.white,
    brightAccent: Color(0xFF6F8BFF),
    secondary: Color(0xFF6842C2),
    success: Color(0xFF08785D),
    warning: Color(0xFF8C5000),
    danger: Color(0xFFB4232D),
    userQuery: Color(0xFFE7ECFF),
    pagePadding: 20,
    sectionGap: 24,
    panelPadding: 20,
    radius: 16,
    cardStackOffset: 34,
    compact: false,
    bodyFontFamily: 'SpaceGrotesk',
    headingFontFamily: 'SpaceGrotesk',
    panelTreatment: PanelTreatment.outlined,
    heroTreatment: HeroTreatment.balanced,
    navigationTreatment: NavigationTreatment.understated,
    chatTreatment: ChatTreatment.document,
  );

  static const _marketPulse = ProductTheme(
    variant: AppThemeVariant.marketPulse,
    canvas: Color(0xFF070907),
    surface: Color(0xFF121510),
    subtle: Color(0xFF1B2117),
    raised: Color(0xFF232A1E),
    ink: Color(0xFFF4F7F0),
    muted: Color(0xFFA0AA9B),
    border: Color(0xFF2B3327),
    action: Color(0xFFC7F464),
    actionInk: Color(0xFF0A0D08),
    brightAccent: Color(0xFFC7F464),
    secondary: Color(0xFF59D991),
    success: Color(0xFFC7F464),
    warning: Color(0xFFFFCA64),
    danger: Color(0xFFFF7474),
    userQuery: Color(0xFF202A1A),
    pagePadding: 18,
    sectionGap: 22,
    panelPadding: 18,
    radius: 18,
    cardStackOffset: 31,
    compact: true,
    bodyFontFamily: 'SpaceGrotesk',
    headingFontFamily: 'SpaceGrotesk',
    panelTreatment: PanelTreatment.flat,
    heroTreatment: HeroTreatment.market,
    navigationTreatment: NavigationTreatment.floating,
    chatTreatment: ChatTreatment.bubbles,
  );

  static const _editorialWealth = ProductTheme(
    variant: AppThemeVariant.editorialWealth,
    canvas: Color(0xFFF2EDE3),
    surface: Color(0xFFFCF9F2),
    subtle: Color(0xFFE7DFD0),
    raised: Color(0xFFDDD2C0),
    ink: Color(0xFF262019),
    muted: Color(0xFF71675B),
    border: Color(0xFFCFC2AF),
    action: Color(0xFF1F5C49),
    actionInk: Colors.white,
    brightAccent: Color(0xFFC66543),
    secondary: Color(0xFF9B5B3D),
    success: Color(0xFF376B53),
    warning: Color(0xFF9B5A2D),
    danger: Color(0xFFA13F34),
    userQuery: Color(0xFFE8DFD0),
    pagePadding: 22,
    sectionGap: 30,
    panelPadding: 24,
    radius: 3,
    cardStackOffset: 38,
    compact: false,
    bodyFontFamily: 'SpaceGrotesk',
    headingFontFamily: 'Fraunces',
    panelTreatment: PanelTreatment.paper,
    heroTreatment: HeroTreatment.editorial,
    navigationTreatment: NavigationTreatment.editorial,
    chatTreatment: ChatTreatment.editorial,
  );

  static const _dataTerminal = ProductTheme(
    variant: AppThemeVariant.dataTerminal,
    canvas: Color(0xFF050A0F),
    surface: Color(0xFF081219),
    subtle: Color(0xFF0B1C23),
    raised: Color(0xFF102730),
    ink: Color(0xFFD8F4EF),
    muted: Color(0xFF7EA8A2),
    border: Color(0xFF1A4548),
    action: Color(0xFF38F1CD),
    actionInk: Color(0xFF03110E),
    brightAccent: Color(0xFF38F1CD),
    secondary: Color(0xFF62B9FF),
    success: Color(0xFF57E39B),
    warning: Color(0xFFFFCB5C),
    danger: Color(0xFFFF7180),
    userQuery: Color(0xFF0C2929),
    pagePadding: 15,
    sectionGap: 18,
    panelPadding: 15,
    radius: 2,
    cardStackOffset: 26,
    compact: true,
    bodyFontFamily: 'IBMPlexMono',
    headingFontFamily: 'IBMPlexMono',
    panelTreatment: PanelTreatment.technical,
    heroTreatment: HeroTreatment.terminal,
    navigationTreatment: NavigationTreatment.technical,
    chatTreatment: ChatTreatment.console,
  );

  static const _walletFlow = ProductTheme(
    variant: AppThemeVariant.walletFlow,
    canvas: Color(0xFFF6F6F8),
    surface: Color(0xFFFFFFFF),
    subtle: Color(0xFFF0ECFF),
    raised: Color(0xFFE6DFFF),
    ink: Color(0xFF17151B),
    muted: Color(0xFF77717F),
    border: Color(0xFFE7E3EB),
    action: Color(0xFF8267E8),
    actionInk: Colors.white,
    brightAccent: Color(0xFFA58AF5),
    secondary: Color(0xFFFF9D5C),
    success: Color(0xFF55BECE),
    warning: Color(0xFFFFB166),
    danger: Color(0xFFF04472),
    userQuery: Color(0xFFEFEBFF),
    pagePadding: 16,
    sectionGap: 22,
    panelPadding: 16,
    radius: 16,
    cardStackOffset: 30,
    compact: true,
    bodyFontFamily: 'SpaceGrotesk',
    headingFontFamily: 'SpaceGrotesk',
    panelTreatment: PanelTreatment.wallet,
    heroTreatment: HeroTreatment.wallet,
    navigationTreatment: NavigationTreatment.wallet,
    chatTreatment: ChatTreatment.wallet,
  );

  static const _walletStudio = ProductTheme(
    variant: AppThemeVariant.walletStudio,
    canvas: Color(0xFFF4F3F7),
    surface: Color(0xFFFFFFFF),
    subtle: Color(0xFFEDE9FA),
    raised: Color(0xFFE2DCF7),
    ink: Color(0xFF18151F),
    muted: Color(0xFF716B7B),
    border: Color(0xFFE3DFE8),
    action: Color(0xFF6E50D9),
    actionInk: Colors.white,
    brightAccent: Color(0xFF9A7FF0),
    secondary: Color(0xFFFF9466),
    success: Color(0xFF258A77),
    warning: Color(0xFFB56A28),
    danger: Color(0xFFD93F69),
    userQuery: Color(0xFFEDE8FB),
    pagePadding: 18,
    sectionGap: 24,
    panelPadding: 17,
    radius: 18,
    cardStackOffset: 31,
    compact: true,
    bodyFontFamily: 'SpaceGrotesk',
    headingFontFamily: 'SpaceGrotesk',
    panelTreatment: PanelTreatment.wallet,
    heroTreatment: HeroTreatment.walletStudio,
    navigationTreatment: NavigationTreatment.wallet,
    chatTreatment: ChatTreatment.wallet,
  );

  static const _decisionFlow = ProductTheme(
    variant: AppThemeVariant.decisionFlow,
    canvas: Color(0xFFF5F5F3),
    surface: Color(0xFFFFFFFF),
    subtle: Color(0xFFEFECFA),
    raised: Color(0xFFE3DCF7),
    ink: Color(0xFF15141A),
    muted: Color(0xFF6A6672),
    border: Color(0xFFE2DFE5),
    action: Color(0xFF6648D8),
    actionInk: Colors.white,
    brightAccent: Color(0xFF8C72EA),
    secondary: Color(0xFFF17E50),
    success: Color(0xFF238372),
    warning: Color(0xFFAD6529),
    danger: Color(0xFFD83F67),
    userQuery: Color(0xFFECE7FB),
    pagePadding: 18,
    sectionGap: 24,
    panelPadding: 17,
    radius: 18,
    cardStackOffset: 31,
    compact: true,
    bodyFontFamily: 'SpaceGrotesk',
    headingFontFamily: 'SpaceGrotesk',
    panelTreatment: PanelTreatment.wallet,
    heroTreatment: HeroTreatment.decision,
    navigationTreatment: NavigationTreatment.wallet,
    chatTreatment: ChatTreatment.wallet,
  );

  static const _decisionFlowDark = ProductTheme(
    variant: AppThemeVariant.decisionFlowDark,
    canvas: Color(0xFF0D0C11),
    surface: Color(0xFF17151D),
    subtle: Color(0xFF24202F),
    raised: Color(0xFF2E293A),
    ink: Color(0xFFF4F1F8),
    muted: Color(0xFFA9A2B3),
    border: Color(0xFF383240),
    action: Color(0xFFA78BFA),
    actionInk: Color(0xFF17121F),
    brightAccent: Color(0xFFC5B5FF),
    secondary: Color(0xFFFF9B70),
    success: Color(0xFF62D2BA),
    warning: Color(0xFFFFB66E),
    danger: Color(0xFFFF7296),
    userQuery: Color(0xFF2A2340),
    pagePadding: 18,
    sectionGap: 24,
    panelPadding: 17,
    radius: 18,
    cardStackOffset: 31,
    compact: true,
    bodyFontFamily: 'SpaceGrotesk',
    headingFontFamily: 'SpaceGrotesk',
    panelTreatment: PanelTreatment.wallet,
    heroTreatment: HeroTreatment.decision,
    navigationTreatment: NavigationTreatment.wallet,
    chatTreatment: ChatTreatment.wallet,
  );

  static final ThemeData clear = _build(_current, Brightness.light);
  static final ThemeData marketPulse = _build(_marketPulse, Brightness.dark);
  static final ThemeData editorialWealth = _build(
    _editorialWealth,
    Brightness.light,
  );
  static final ThemeData dataTerminal = _build(_dataTerminal, Brightness.dark);
  static final ThemeData walletFlow = _build(_walletFlow, Brightness.light);
  static final ThemeData walletStudio = _build(_walletStudio, Brightness.light);
  static final ThemeData decisionFlow = _build(_decisionFlow, Brightness.light);
  static final ThemeData decisionFlowDark = _build(
    _decisionFlowDark,
    Brightness.dark,
  );

  static ThemeData forVariant(AppThemeVariant variant) => switch (variant) {
    AppThemeVariant.clear => clear,
    AppThemeVariant.marketPulse => marketPulse,
    AppThemeVariant.editorialWealth => editorialWealth,
    AppThemeVariant.dataTerminal => dataTerminal,
    AppThemeVariant.walletFlow => walletFlow,
    AppThemeVariant.walletStudio => walletStudio,
    AppThemeVariant.decisionFlow => decisionFlow,
    AppThemeVariant.decisionFlowDark => decisionFlowDark,
  };

  static ThemeData _build(ProductTheme product, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: product.action,
      onPrimary: product.actionInk,
      secondary: product.secondary,
      onSecondary: product.actionInk,
      error: product.danger,
      onError: Colors.white,
      surface: product.surface,
      onSurface: product.ink,
      surfaceContainerHighest: product.raised,
      outline: product.border,
      outlineVariant: product.border,
    );
    final buttonRadius = switch (product.panelTreatment) {
      PanelTreatment.flat => 999.0,
      PanelTreatment.paper => 2.0,
      PanelTreatment.technical => 2.0,
      PanelTreatment.wallet => 12.0,
      PanelTreatment.outlined => product.radius * .7,
    };
    final inputRadius = BorderRadius.circular(
      product.panelTreatment == PanelTreatment.flat ? 14 : buttonRadius,
    );
    final border = OutlineInputBorder(
      borderRadius: inputRadius,
      borderSide: BorderSide(color: product.border),
    );
    final displaySize = switch (product.heroTreatment) {
      HeroTreatment.market => 48.0,
      HeroTreatment.editorial => 46.0,
      HeroTreatment.terminal => 34.0,
      HeroTreatment.wallet => 38.0,
      HeroTreatment.walletStudio => 40.0,
      HeroTreatment.decision => 40.0,
      HeroTreatment.balanced => 40.0,
    };
    final headingWeight = product.heroTreatment == HeroTreatment.editorial
        ? FontWeight.w600
        : FontWeight.w700;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: product.canvas,
      canvasColor: product.canvas,
      fontFamily: product.bodyFontFamily,
      extensions: [product],
      dividerColor: product.border,
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontFamily: product.headingFontFamily,
          fontSize: displaySize,
          height: 1.02,
          fontWeight: headingWeight,
          letterSpacing: product.heroTreatment == HeroTreatment.terminal
              ? -1
              : -1.4,
          color: product.ink,
        ),
        headlineMedium: TextStyle(
          fontFamily: product.headingFontFamily,
          fontSize: product.compact ? 25 : 30,
          height: 1.1,
          fontWeight: headingWeight,
          letterSpacing: product.heroTreatment == HeroTreatment.editorial
              ? -.2
              : -.8,
          color: product.ink,
        ),
        titleLarge: TextStyle(
          fontFamily: product.headingFontFamily,
          fontSize: product.compact ? 18 : 21,
          fontWeight: headingWeight,
          color: product.ink,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: product.ink),
        bodyMedium: TextStyle(
          fontSize: product.compact ? 13.5 : 14,
          height: 1.45,
          color: product.muted,
        ),
        labelLarge: TextStyle(fontWeight: FontWeight.w700, color: product.ink),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: product.canvas,
        foregroundColor: product.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: product.ink,
          fontFamily: product.headingFontFamily,
          fontSize: 20,
          fontWeight: headingWeight,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: switch (product.panelTreatment) {
          PanelTreatment.paper => 1,
          PanelTreatment.wallet => 2,
          _ => 0,
        },
        color: product.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(product.radius),
          side: BorderSide(color: product.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: product.panelTreatment == PanelTreatment.technical
            ? product.subtle
            : product.surface,
        hintStyle: TextStyle(color: product.muted),
        labelStyle: TextStyle(color: product.muted),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: product.compact ? 13 : 16,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: product.action, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: product.action,
          foregroundColor: product.actionInk,
          minimumSize: Size(48, product.compact ? 48 : 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: TextStyle(
            fontFamily: product.bodyFontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: product.action,
          minimumSize: Size(48, product.compact ? 48 : 52),
          side: BorderSide(color: product.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: TextStyle(
            fontFamily: product.bodyFontFamily,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: product.subtle,
        side: BorderSide(color: product.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        labelStyle: TextStyle(
          color: product.ink,
          fontFamily: product.bodyFontFamily,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: product.compact ? 64 : 68,
        elevation: 0,
        backgroundColor: product.surface,
        indicatorColor: switch (product.navigationTreatment) {
          NavigationTreatment.floating => product.action,
          NavigationTreatment.wallet => Colors.transparent,
          _ => product.subtle,
        },
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            product.navigationTreatment == NavigationTreatment.floating
                ? 999
                : product.radius,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? product.action
                : product.muted,
            fontFamily: product.bodyFontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? product.navigationTreatment == NavigationTreatment.floating
                      ? product.actionInk
                      : product.action
                : product.muted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: product.surface,
        indicatorColor: switch (product.navigationTreatment) {
          NavigationTreatment.floating => product.action,
          NavigationTreatment.wallet => Colors.transparent,
          _ => product.subtle,
        },
        selectedIconTheme: IconThemeData(
          color: product.navigationTreatment == NavigationTreatment.floating
              ? product.actionInk
              : product.action,
        ),
        unselectedIconTheme: IconThemeData(color: product.muted),
        selectedLabelTextStyle: TextStyle(
          color: product.action,
          fontFamily: product.bodyFontFamily,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: product.muted,
          fontFamily: product.bodyFontFamily,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: product.raised,
        contentTextStyle: TextStyle(color: product.ink),
      ),
    );
  }
}
