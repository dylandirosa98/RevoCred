import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/affiliate_offer.dart';
import '../../../core/models/chat_disclosure.dart';
import '../../../core/state/app_controller.dart';

// Reads only the public notice; opening legal information never grants consent.
final legalChatDisclosureProvider = FutureProvider.autoDispose<ChatDisclosure>(
  (ref) => ref.watch(appRepositoryProvider).loadChatDisclosure(),
);

class LegalScreen extends ConsumerWidget {
  const LegalScreen({
    super.key,
    this.config = const AppConfig.fromEnvironment(),
  });
  final AppConfig config;
  String value(String configured, String demo) =>
      config.useMocks ? 'Demo: $demo' : configured;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Privacy & Terms')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(value(config.legalEntity, 'RevoCred demonstration operator')),
            Text(
              'Effective date: ${value(config.legalEffectiveDate, "demonstration only")}',
            ),
            Text(
              'Governing jurisdiction: ${value(config.legalJurisdiction, "no production jurisdiction")}',
            ),
            const SizedBox(height: 16),
            const Text(
              'Data and your choices',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'We use your account email and name, questionnaire answers (life stage, credit band and spending), wallet cards, saved recommendations and REVO chat messages to provide and personalize the service. Supabase manages authentication. We do not pull your credit or collect card numbers. Do not enter card numbers, security codes or bank credentials in chat. Optional marketing emails require your opt-in; contact support to withdraw it.',
            ),
            const Text(
              'The server keeps the latest 1,000 chat messages and up to 100 recommendation runs per account. Account settings provide data export and account deletion. Sessions and appearance preferences are stored on your device. Deleted data may remain in operational backups until they expire. Contact support for retention questions. Reliability reports contain error categories rather than chat text or stack traces.',
            ),
            const SizedBox(height: 16),
            const Text(
              'REVO and external services',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ref
                .watch(legalChatDisclosureProvider)
                .when(
                  loading: () =>
                      const Text('Loading the current AI sharing notice…'),
                  error: (_, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'The current AI sharing notice is unavailable. Review the notice in REVO before enabling external AI. Opening this page does not enable AI sharing.',
                      ),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(legalChatDisclosureProvider),
                        child: const Text('Retry AI sharing notice'),
                      ),
                    ],
                  ),
                  data: (notice) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notice.external
                            ? 'Current AI service: ${notice.recipient}. Model: ${notice.model}.'
                            : 'REVO currently uses basic replies from our server without external AI.',
                      ),
                      if (notice.external) ...[
                        Text(notice.dataUse),
                        if (notice.searchProvider.isNotEmpty)
                          Text('Search service: ${notice.searchProvider}.'),
                        const Text(
                          'External AI is used only after your explicit permission. Permission lasts until you turn it off in Profile or the sharing notice changes. Guests always get basic replies, which use our server without external AI. Provider retention follows its service agreement; zero retention is not promised.',
                        ),
                      ],
                    ],
                  ),
                ),
            const Text(
              'Do not enter card numbers, security codes or bank credentials in chat. Public sources may be incomplete or outdated. Recommendations and scores are selected deterministically by our server, never by AI.',
            ),
            const SizedBox(height: 16),
            const Text(
              'Using RevoCred',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Text(
              'RevoCred is for adults 18 or older in the United States. It provides educational estimates, not financial, tax or legal advice. Approval, rewards and savings are not guaranteed. Verify current issuer terms and never spend or borrow solely for rewards. Use only your own account and information you are authorized to provide. Protect your credentials and do not access other accounts or disrupt the service.',
            ),
            const Text(
              'Ongoing wallet value includes spending rewards, reviewed relevant credits at a conditional 70% usage assumption and anniversary rewards after eligible renewal, minus annual fees. Eligible merchants, portals, enrollment and limits apply. Points are valued at one cent. Housing rewards, welcome bonuses and conditional earning-rate uplift are excluded. Application rankings use a separate conservative rewards-minus-fees model excluding conditional credits and anniversary rewards. See the yearly-value breakdown for assumptions and sources.',
            ),
            const Text(affiliateDisclosure),
            const Text(
              'Apply links open external issuer or partner websites with their own privacy policies. Official issuer links are identified separately. Redirect counts are aggregated by offer, day and screen without account IDs, cookies, IP addresses or device identifiers. Wallet, spending and chat data are not sent with application links. Partner availability does not determine recommendations.',
            ),
            TextButton(
              onPressed: config.useMocks
                  ? null
                  : () => _openLegalLink(context, config.privacyUrl),
              child: Text(
                config.useMocks
                    ? 'Full privacy policy (demo)'
                    : 'Full privacy policy',
              ),
            ),
            TextButton(
              onPressed: config.useMocks
                  ? null
                  : () => _openLegalLink(context, config.termsUrl),
              child: Text(config.useMocks ? 'Full terms (demo)' : 'Full terms'),
            ),
            TextButton(
              onPressed: config.useMocks
                  ? null
                  : () => _openLegalLink(context, config.supportUrl),
              child: Text(
                config.useMocks ? 'Support page (demo)' : 'Support page',
              ),
            ),
            Text(value(config.supportEmail, 'support@example.invalid')),
            TextButton(
              onPressed: config.useMocks
                  ? null
                  : () => _openLegalLink(
                      context,
                      Uri(
                        scheme: 'mailto',
                        path: config.supportEmail,
                      ).toString(),
                      mail: true,
                    ),
              child: const Text('Contact support'),
            ),
            const _CardDataCredit(),
          ],
        ),
      ),
    ),
  );
}

class _CardDataCredit extends StatelessWidget {
  const _CardDataCredit();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Data credits', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text(
        'Some card information is provided by OpenCard DB under the Creative Commons Attribution 4.0 International license (CC BY 4.0). RevoCred has adapted for display the original data, including formatting terms and combining them with separately reviewed issuer information. This credit does not imply endorsement. Card terms may be incomplete or outdated; verify current terms with the issuer.',
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: () => _openLegalLink(
              context,
              'https://github.com/thedavidweng/opencard-db',
            ),
            child: const Text('Original card data'),
          ),
          TextButton(
            onPressed: () => _openLegalLink(
              context,
              'https://creativecommons.org/licenses/by/4.0/',
            ),
            child: const Text('CC BY 4.0 license'),
          ),
        ],
      ),
    ],
  );
}

Future<void> _openLegalLink(
  BuildContext context,
  String url, {
  bool mail = false,
}) async {
  try {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (mail
            ? uri.scheme != 'mailto' || uri.path.trim().isEmpty
            : uri.scheme != 'https' || uri.host.isEmpty)) {
      throw const FormatException('Unavailable link');
    }
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {
    // Show the same actionable failure for platform errors and invalid config.
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Could not open this link. Please try again later.'),
    ),
  );
}
