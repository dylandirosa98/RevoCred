import 'package:flutter/material.dart';

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
               'Sessions and appearance preferences are stored on your device. Account settings let you request a JSON export or permanently delete your account from the live service. The live service retains up to 1,000 chat messages and 100 recommendation runs per account; older history is removed as new records arrive. Operational backups may retain deleted data until they expire. Backup periods must be confirmed by the deployment operator. Authenticated clients report error categories, without message text or stack traces, for reliability monitoring. REVO chat sends your current question plus a snapshot of your wallet, spend, strategy, and server ranking to OpenCode Go (DeepSeek V4.1 Flash) so it can explain those facts. The model cannot select cards. Do not enter card numbers, CVV, PINs, or bank credentials.',
            ),
            SizedBox(height: 24),
            Text(
              'Educational estimates',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'RevoCred is an educational planning tool, not financial, tax or legal advice. Estimates do not predict approval or guarantee rewards. The conservative model values points at one cent and excludes housing rewards, bonuses, conditional credits and conditional reward uplift. Fees, caps, merchant categories and eligibility affect actual results. Verify current issuer terms and never borrow or spend more solely to earn rewards.',
            ),
            SizedBox(height: 24),
            Text(
              'Use of the service',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Use only your own account and information you are authorized to provide. Do not attempt to access other accounts or disrupt the service. Keep your credentials secure. Public availability, support commitments, dispute terms and any commercial disclosures must be set by the operator before release.',
            ),
          ],
        ),
      ),
    ),
  );
}
