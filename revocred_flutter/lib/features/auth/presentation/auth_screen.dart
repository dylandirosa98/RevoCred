import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/demo_seed.dart';
import '../../../core/state/app_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../../shared/widgets/credit_card_view.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({this.savePlan = false, super.key});
  final bool savePlan;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool submitting = false;
  bool showForm = false;
  bool signingUp = true;
  bool obscurePassword = true;
  String? message;

  @override
  void initState() {
    super.initState();
    showForm = widget.savePlan;
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.product.canvas,
    body: _AuthBackdrop(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: showForm
                    ? _AuthFormPage(
                        key: ValueKey('auth-form-$signingUp'),
                        email: email,
                        password: password,
                        signingUp: signingUp,
                        name: name,
                        submitting: submitting,
                        obscurePassword: obscurePassword,
                        message: message,
                        onBack: () => setState(() {
                          showForm = false;
                          message = null;
                        }),
                        onTogglePassword: () =>
                            setState(() => obscurePassword = !obscurePassword),
                        onSubmit: () => _submit(signUp: signingUp),
                        onSwitchMode: () => setState(() {
                          signingUp = !signingUp;
                          message = null;
                        }),
                      )
                    : _WelcomePage(
                        key: const ValueKey('auth-welcome'),
                        onCreateAccount: () => context.go('/questionnaire'),
                        onSignIn: () => _openForm(signUp: false),
                      ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => context.push('/account-recovery'),
                  child: const Text('Forgot password / confirm email'),
                ),
                TextButton(
                  onPressed: () => context.push('/legal'),
                  child: const Text('Privacy and terms'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  void _openForm({required bool signUp}) {
    if (ref.read(appConfigProvider).useMocks) {
      context.go(signUp ? '/questionnaire' : '/home');
      return;
    }
    setState(() {
      showForm = true;
      signingUp = signUp;
      message = null;
    });
  }

  Future<void> _submit({required bool signUp}) async {
    if (email.text.trim().isEmpty || password.text.length < (signUp ? 12 : 6)) {
      setState(
        () => message = signUp
            ? 'Enter an email and a password of at least 12 characters.'
            : 'Enter your email and password.',
      );
      return;
    }
    // Ask for a name up front so the greeting is never a placeholder, and so it
    // survives the email-confirmation round trip with the saved plan.
    final displayName = name.text.trim();
    if (signUp && displayName.isEmpty) {
      setState(() => message = 'Enter the name you want to see in RevoCred.');
      return;
    }
    if (signUp && displayName.runes.length > 60) {
      setState(() => message = 'That name is too long.');
      return;
    }
    setState(() {
      submitting = true;
      message = null;
    });
    try {
      final controller = ref.read(appControllerProvider.notifier);
      final result = signUp
          ? await controller.signUp(
              email.text.trim(),
              password.text,
              displayName: displayName,
            )
          : await controller.signIn(email.text.trim(), password.text);
      if (mounted) {
        final authenticated = ref.read(appControllerProvider).isAuthenticated;
        setState(() {
          message =
              result.message ??
              (result.success ? 'Signed in.' : 'Authentication failed.');
        });
        if (result.success && authenticated) {
          final data = ref.read(appControllerProvider).data;
          context.go(
            data?.questionnaireAnswers == null ? '/questionnaire' : '/home',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Authentication failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.onCreateAccount,
    required this.onSignIn,
    super.key,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1180,
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 48 : 20,
                vertical: wide ? 42 : 22,
              ),
              child: wide
                  ? Row(
                      children: [
                        Expanded(
                          child: _WelcomeCopy(
                            wide: true,
                            onCreateAccount: onCreateAccount,
                            onSignIn: onSignIn,
                          ),
                        ),
                        const SizedBox(width: 48),
                        const Expanded(child: _HeroCards(wide: true)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WelcomeCopy(
                          wide: false,
                          onCreateAccount: onCreateAccount,
                          onSignIn: onSignIn,
                          showActions: false,
                        ),
                        const SizedBox(height: 16),
                        const _HeroCards(),
                        const SizedBox(height: 14),
                        _WelcomeActions(
                          onCreateAccount: onCreateAccount,
                          onSignIn: onSignIn,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    },
  );
}

class _WelcomeCopy extends StatelessWidget {
  const _WelcomeCopy({
    required this.wide,
    required this.onCreateAccount,
    required this.onSignIn,
    this.showActions = true,
  });

  final bool wide;
  final bool showActions;
  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final headline = switch (product.heroTreatment) {
      HeroTreatment.market => 'Make every\ncard move\ncount.\n',
      HeroTreatment.editorial =>
        'A more thoughtful\nway to build\nyour wallet.\n',
      HeroTreatment.terminal => 'OPTIMIZE_WALLET\nMAXIMIZE_VALUE\n',
      HeroTreatment.wallet => 'Your wallet.\nOne clear\nstrategy.\n',
      HeroTreatment.walletStudio => 'Every card.\nOne smarter\nwallet.\n',
      HeroTreatment.decision => 'The right card.\nRight when\nyou need it.\n',
      HeroTreatment.balanced =>
        wide
            ? 'Smarter credit card\nstrategy.\n'
            : 'Smarter\ncredit card\nstrategy.\n',
    };
    final accent = switch (product.heroTreatment) {
      HeroTreatment.market => 'Own your upside.',
      HeroTreatment.editorial => 'Clarity, beautifully considered.',
      HeroTreatment.terminal => 'SIGNAL_READY.',
      HeroTreatment.wallet => 'Everything in view.',
      HeroTreatment.walletStudio => 'Designed around you.',
      HeroTreatment.decision => 'Decide with confidence.',
      HeroTreatment.balanced => 'More value for you.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppLogo(onDark: dark, markSize: 46),
        SizedBox(height: wide ? 64 : 34),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: headline),
              TextSpan(
                text: accent,
                style: TextStyle(color: product.brightAccent),
              ),
            ],
          ),
          style: TextStyle(
            color: product.ink,
            fontFamily: product.headingFontFamily,
            fontSize: wide
                ? product.heroTreatment == HeroTreatment.terminal
                      ? 50
                      : 62
                : product.heroTreatment == HeroTreatment.terminal
                ? 34
                : 43,
            height: product.heroTreatment == HeroTreatment.editorial
                ? 1.05
                : .98,
            fontWeight: product.heroTreatment == HeroTreatment.editorial
                ? FontWeight.w600
                : FontWeight.w800,
            letterSpacing: product.heroTreatment == HeroTreatment.terminal
                ? -1
                : wide
                ? -2.8
                : -2,
          ),
        ),
        SizedBox(height: wide ? 28 : 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Text(
            'Personalized recommendations built around your goals, spending, and wallet.',
            style: TextStyle(color: product.muted, fontSize: 17, height: 1.5),
          ),
        ),
        if (showActions) ...[
          const SizedBox(height: 38),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: _WelcomeActions(
              onCreateAccount: onCreateAccount,
              onSignIn: onSignIn,
            ),
          ),
        ],
      ],
    );
  }
}

class _WelcomeActions extends StatelessWidget {
  const _WelcomeActions({
    required this.onCreateAccount,
    required this.onSignIn,
  });

  final VoidCallback onCreateAccount;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _GradientAction(
        key: const ValueKey('build-strategy-action'),
        label: 'Build my strategy',
        onPressed: onCreateAccount,
        trailing: Icons.arrow_forward,
      ),
      const SizedBox(height: 8),
      TextButton(
        key: const ValueKey('existing-account-action'),
        onPressed: onSignIn,
        style: TextButton.styleFrom(
          foregroundColor: context.product.action,
          minimumSize: const Size.fromHeight(48),
        ),
        child: const Text('I already have an account'),
      ),
    ],
  );
}

class _HeroCards extends StatelessWidget {
  const _HeroCards({this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final cardWidth = (width * (wide ? .66 : .68)).clamp(200.0, 330.0);
      final cardHeight = cardWidth / 1.62;
      final frontCardTop = wide ? 210.0 : 105.0;
      final height = wide ? 410.0 : frontCardTop + cardHeight + 10;
      final amex = demoCatalog.firstWhere((card) => card.id == 'amex-gold');
      final sapphire = demoCatalog.firstWhere(
        (card) => card.id == 'sapphire-preferred',
      );
      final freedom = demoCatalog.firstWhere(
        (card) => card.id == 'freedom-unlimited',
      );
      return IgnorePointer(
        child: SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: wide ? 40 : 8,
                left: wide ? 18 : 5,
                child: Transform.rotate(
                  angle: -.1,
                  child: CreditCardArt(
                    card: amex,
                    width: cardWidth,
                    height: cardHeight,
                  ),
                ),
              ),
              Positioned(
                top: wide ? 102 : 44,
                right: wide ? 0 : 4,
                child: Transform.rotate(
                  angle: .07,
                  child: CreditCardArt(
                    card: sapphire,
                    width: cardWidth,
                    height: cardHeight,
                  ),
                ),
              ),
              Positioned(
                top: frontCardTop,
                left: width * .15,
                child: Transform.rotate(
                  angle: -.03,
                  child: CreditCardArt(
                    card: freedom,
                    width: cardWidth,
                    height: cardHeight,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AuthFormPage extends StatelessWidget {
  const _AuthFormPage({
    required this.email,
    required this.password,
    required this.signingUp,
    required this.name,
    required this.submitting,
    required this.obscurePassword,
    required this.onBack,
    required this.onTogglePassword,
    required this.onSubmit,
    required this.onSwitchMode,
    this.message,
    super.key,
  });

  final TextEditingController email;
  final TextEditingController password;
  final bool signingUp;
  final TextEditingController name;
  final bool submitting;
  final bool obscurePassword;
  final String? message;
  final VoidCallback onBack;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchMode;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 900;
      return SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 1080,
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: EdgeInsets.all(wide ? 48 : 20),
              child: wide
                  ? Row(
                      children: [
                        const Expanded(child: _AuthSideNote()),
                        const SizedBox(width: 70),
                        SizedBox(width: 460, child: _buildForm(context)),
                      ],
                    )
                  : _buildForm(context),
            ),
          ),
        ),
      );
    },
  );

  Widget _buildForm(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          key: const ValueKey('auth-back'),
          onPressed: onBack,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      const SizedBox(height: 12),
      AppLogo(
        onDark: Theme.of(context).brightness == Brightness.dark,
        markSize: 46,
      ),
      const SizedBox(height: 34),
      Text(
        signingUp ? 'Build your strategy' : 'Welcome back',
        style: TextStyle(
          color: context.product.ink,
          fontFamily: context.product.headingFontFamily,
          fontSize: 34,
          height: 1.05,
          fontWeight: context.product.heroTreatment == HeroTreatment.editorial
              ? FontWeight.w600
              : FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
      const SizedBox(height: 9),
      Text(
        signingUp
            ? 'Create your account to save your wallet and recommendations.'
            : 'Sign in to continue where you left off.',
        style: TextStyle(color: context.product.muted, height: 1.5),
      ),
      const SizedBox(height: 26),
      if (signingUp) ...[
        TextField(
          key: const ValueKey('auth-name'),
          controller: name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => FocusScope.of(context).nextFocus(),
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'First name or full name',
            helperText: 'Used for your greeting. Never shown publicly.',
          ),
        ),
        const SizedBox(height: 12),
      ],
      TextField(
        key: const ValueKey('auth-email'),
        controller: email,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => FocusScope.of(context).nextFocus(),
        autocorrect: false,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const ValueKey('auth-password'),
        controller: password,
        obscureText: obscurePassword,
        textInputAction: TextInputAction.done,
        autofillHints: signingUp
            ? const [AutofillHints.newPassword]
            : const [AutofillHints.password],
        onSubmitted: (_) => submitting ? null : onSubmit(),
        decoration: InputDecoration(
          labelText: 'Password',
          suffixIcon: IconButton(
            onPressed: onTogglePassword,
            tooltip: obscurePassword ? 'Show password' : 'Hide password',
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
      if (message != null) ...[
        const SizedBox(height: 14),
        Text(
          message!,
          style: TextStyle(
            color: _isError(message!)
                ? context.product.danger
                : context.product.muted,
          ),
        ),
      ],
      const SizedBox(height: 20),
      _GradientAction(
        key: const ValueKey('auth-submit'),
        label: signingUp ? 'Create account' : 'Sign in',
        onPressed: submitting ? null : onSubmit,
        loading: submitting,
        trailing: Icons.arrow_forward,
      ),
      const SizedBox(height: 10),
      TextButton(
        key: const ValueKey('auth-switch-mode'),
        onPressed: submitting ? null : onSwitchMode,
        child: Text(
          signingUp
              ? 'Already have an account? Sign in'
              : 'New to RevoCred? Create an account',
        ),
      ),
      if (signingUp) ...[
        const SizedBox(height: 14),
        Text(
          'By continuing, you agree to RevoCred’s terms and acknowledge that recommendations are educational estimates.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.product.muted,
            fontSize: 11,
            height: 1.45,
          ),
        ),
      ],
    ],
  );

  static bool _isError(String value) {
    final text = value.toLowerCase();
    return text.contains('requires') ||
        text.contains('failed') ||
        text.contains('enter an email');
  }
}

class _AuthSideNote extends StatelessWidget {
  const _AuthSideNote();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'A clearer next move\nfor every card.',
        style: TextStyle(
          color: context.product.ink,
          fontFamily: context.product.headingFontFamily,
          fontSize: 48,
          height: 1.03,
          fontWeight: context.product.heroTreatment == HeroTreatment.editorial
              ? FontWeight.w600
              : FontWeight.w800,
          letterSpacing: -2,
        ),
      ),
      const SizedBox(height: 18),
      Text(
        'Compare value, fill wallet gaps, and understand every recommendation.',
        style: TextStyle(
          color: context.product.muted,
          fontSize: 16,
          height: 1.55,
        ),
      ),
      const SizedBox(height: 30),
      for (final item in const [
        'Deterministic card rankings',
        'Transparent value estimates',
        'Strategy grounded in your wallet',
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Icon(Icons.check, size: 17, color: context.product.action),
              const SizedBox(width: 10),
              Text(item, style: TextStyle(color: context.product.ink)),
            ],
          ),
        ),
    ],
  );
}

class _GradientAction extends StatelessWidget {
  const _GradientAction({
    required this.label,
    required this.onPressed,
    super.key,
    this.trailing,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? trailing;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    final radius = product.panelTreatment == PanelTreatment.flat
        ? 999.0
        : product.panelTreatment == PanelTreatment.outlined
        ? 18.0
        : product.panelTreatment == PanelTreatment.wallet
        ? 16.0
        : 2.0;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Opacity(
        opacity: onPressed == null ? .55 : 1,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: product.panelTreatment == PanelTreatment.outlined
                  ? null
                  : product.action,
              gradient: product.panelTreatment == PanelTreatment.outlined
                  ? LinearGradient(colors: [product.action, product.secondary])
                  : null,
              border: product.panelTreatment == PanelTreatment.technical
                  ? Border.all(color: product.brightAccent)
                  : null,
              borderRadius: BorderRadius.circular(radius),
              boxShadow: product.panelTreatment == PanelTreatment.technical
                  ? null
                  : [
                      BoxShadow(
                        color: product.action.withValues(alpha: .2),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(radius),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 58),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 24),
                      Expanded(
                        child: Center(
                          child: loading
                              ? SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: product.actionInk,
                                  ),
                                )
                              : Text(
                                  label,
                                  style: TextStyle(
                                    color: product.actionInk,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        child: trailing == null
                            ? null
                            : Icon(
                                trailing,
                                color: product.actionInk,
                                size: 21,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final product = context.product;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [product.canvas, product.subtle, product.canvas],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _SignalPainter(
                color: product.action,
                technical: product.panelTreatment == PanelTreatment.technical,
              ),
            ),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _SignalPainter extends CustomPainter {
  const _SignalPainter({required this.color, required this.technical});

  final Color color;
  final bool technical;

  @override
  void paint(Canvas canvas, Size size) {
    if (technical) {
      final paint = Paint()
        ..color = color.withValues(alpha: .08)
        ..strokeWidth = .7;
      for (var x = 0.0; x < size.width; x += 32) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (var y = 0.0; y < size.height; y += 32) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
      return;
    }
    for (var index = 0; index < 18; index++) {
      final progress = index / 17;
      final path = Path()
        ..moveTo(size.width * (.48 + progress * .03), size.height * 1.02)
        ..cubicTo(
          size.width * (.5 + progress * .18),
          size.height * .72,
          size.width * (.82 + progress * .12),
          size.height * (.68 - progress * .18),
          size.width * 1.04,
          size.height * (.42 - progress * .06),
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: .025 + progress * .018)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .7,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SignalPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.technical != technical;
}

class BrandedLoadingScreen extends StatelessWidget {
  const BrandedLoadingScreen({super.key, this.error, this.onRetry});

  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.product.canvas,
    body: _AuthBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 56,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppLogo(
                        onDark: Theme.of(context).brightness == Brightness.dark,
                        markSize: 72,
                      ),
                      const SizedBox(height: 34),
                      if (error == null) ...[
                        LinearProgressIndicator(
                          minHeight: 3,
                          color: context.product.action,
                          backgroundColor: context.product.border,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Building your strategy',
                          style: TextStyle(
                            color: context.product.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.product.danger,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: 180,
                          child: _GradientAction(
                            label: 'Try again',
                            onPressed: onRetry,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
