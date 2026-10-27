import 'package:flutter/material.dart';
import '../../../core/models/affiliate_offer.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy and terms')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            Text(
              'RevoCred local / pre-release notice',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'This notice describes the current software. The operator must publish its legal identity, jurisdiction, contact details and approved retention/backup policy before a public launch.',
            ),
            SizedBox(height: 24),
            Text(
              'Data and purpose',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Supabase handles your email, password and authentication sessions. RevoCred stores your profile, entered spending preferences, wallet card names and terms, questionnaire answers, recommendations and chat messages to provide the service. Do not enter card numbers, security codes, bank credentials or sensitive information in chat. The application does not need those details.',
            ),
            SizedBox(height: 24),
            Text(
              'Storage and your choices',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Sessions and appearance preferences are stored on your device. Account settings let you request a JSON export or permanently delete your account from the live service. The live service retains up to 1,000 chat messages and 100 recommendation runs per account; older history is removed as new records arrive. Operational backups may retain deleted data until they expire. Backup periods must be confirmed by the deployment operator. Authenticated clients report error categories, without message text or stack traces, for reliability monitoring.',
            ),
            SizedBox(height: 12),
            Text(
              'When external AI is enabled, production REVO uses OpenAI; developer testing may use OpenCode Go with DeepSeek. Before each message, the sharing notice identifies the configured service and model. Only choosing Agree and send permits external AI for that message. Choosing Use basic reply keeps the explanation on the RevoCred server without external AI, and Cancel sends nothing. No ongoing AI permission is saved. If you agree, your question and, when signed in, first name, life stage, credit band, spending, wallet card details, strategy, recommendation ranking and up to eight recent chat messages are sent to explain your plan. Guest chat uses demo context, but your message is still shared if you agree. OpenCode Go testing also sends an account-linked session identifier. With your permission for that message, the AI may choose to send minimal public product/topic queries to DuckDuckGo, and RevoCred may read public HTTPS sources, including non-issuer pages and readable PDFs. Profile and chat history are not sent wholesale to search or source sites; tool requests are instructed to omit personal information and clear sensitive identifiers are blocked. Sources may be incomplete or outdated and never change app scores, rankings or strategy. Provider retention depends on the actual service agreement; zero retention is not promised. Recommendations are selected by the RevoCred server, not the AI. Do not enter card numbers, CVV, PINs or bank credentials.',
            ),
            SizedBox(height: 24),
            Text(
              'Educational estimates',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'RevoCred is an educational planning tool, not financial, tax or legal advice. Estimates do not predict approval or guarantee rewards. Ongoing wallet value includes spending rewards, reviewed relevant credits at a conditional 70% usage assumption and anniversary rewards after eligible renewal, minus annual fees. Spending alone does not establish use of a credit; eligible merchants, portals, enrollment and benefit limits still apply. Points are valued at one cent. Housing rewards, welcome bonuses and conditional earning-rate uplift are excluded. Application rankings use a separate conservative rewards-minus-fees model that excludes conditional credits and anniversary rewards. See the yearly-value breakdown for assumptions and sources. Verify current issuer terms and never borrow or spend more solely to earn rewards.',
            ),
            SizedBox(height: 24),
            Text(
              'Use of the service',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Use only your own account and information you are authorized to provide. Do not attempt to access other accounts or disrupt the service. Keep your credentials secure. Public availability, support commitments, dispute terms and any commercial disclosures must be set by the operator before release.',
            ),
            SizedBox(height: 24),
            Text(
              'Affiliate links',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Official issuer links do not earn RevoCred a commission. If we add partner links, they will be labeled separately. $affiliateDisclosure',
            ),
            SizedBox(height: 12),
            Text(
              'Guest previews send your questionnaire to the API for a deterministic calculation without creating server-side account records. This device stores a short-lived draft so you can save the plan after confirming your email. Drafts expire after 24 hours and can be cleared from the preview. Use a private device when entering financial preferences.',
            ),
            SizedBox(height: 8),
            Text(
              'An Apply button opens an issuer or affiliate partner website. RevoCred counts redirects by offer, day and screen, without storing a user ID, cookie, IP address or device identifier in affiliate analytics. Counts are not applications or approvals. External sites have their own privacy policies and may use cookies. We do not send your wallet, spending or chat data with the link. Cards without a partner offer remain eligible for the same recommendations.',
            ),
          ],
        ),
      ),
    ),
  );
}
