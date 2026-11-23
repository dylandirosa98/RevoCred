import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/pwa_install.dart';
import '../../core/state/theme_controller.dart';
import '../../core/theme/app_theme.dart';
import 'content_layout.dart';

const pwaInstallHintDismissedKey = 'pwa_install_hint_dismissed';

class PwaInstallBanner extends ConsumerStatefulWidget {
  const PwaInstallBanner({super.key});

  @override
  ConsumerState<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends ConsumerState<PwaInstallBanner> {
  late PwaInstallStatus _status;
  StreamSubscription<PwaInstallStatus>? _subscription;
  bool _dismissed = false;
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    final client = ref.read(pwaInstallClientProvider);
    _status = client.readStatus();
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      _dismissed = prefs.getBool(pwaInstallHintDismissedKey) ?? false;
    } catch (_) {
      _dismissed = false;
    }
    _subscription = client.statusChanges.listen((status) {
      if (mounted) {
        setState(() => _status = status);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(pwaInstallHintDismissedKey, true);
    } catch (_) {
      // Dismissal still holds for the current session when preferences are absent.
    }
  }

  Future<void> _install() async {
    if (_prompting) return;
    setState(() => _prompting = true);
    final accepted = await ref.read(pwaInstallClientProvider).promptInstall();
    if (!mounted) return;
    setState(() {
      _prompting = false;
      if (accepted) _dismissed = true;
    });
    if (accepted) {
      await _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !_status.shouldShowHint) {
      return const SizedBox.shrink();
    }
    final product = context.product;
    final subtitle = _status.canPrompt
        ? 'Add RevoCred to your home screen for one-tap access at checkout.'
        : _status.isIos
        ? 'Tap Share in Safari, then "Add to Home Screen" for full-screen access.'
        : 'Open your browser menu and tap "Add to Home Screen" for quick access.';
    return Padding(
      key: const ValueKey('pwa-install-banner'),
      padding: const EdgeInsets.only(top: 14),
      child: AppPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: product.subtle,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                _status.isIos
                    ? Icons.ios_share_rounded
                    : Icons.install_mobile_rounded,
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
                    'Install RevoCred',
                    style: TextStyle(
                      color: product.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: product.muted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  if (_status.canPrompt) ...[
                    const SizedBox(height: 10),
                    FilledButton(
                      key: const ValueKey('pwa-install-button'),
                      onPressed: _prompting ? null : _install,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 38),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      child: Text(_prompting ? 'Installing…' : 'Install app'),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              key: const ValueKey('pwa-install-dismiss'),
              onPressed: _dismiss,
              tooltip: 'Dismiss install hint',
              icon: Icon(Icons.close, size: 18, color: product.muted),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
