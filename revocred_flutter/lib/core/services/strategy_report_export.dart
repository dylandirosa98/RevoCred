import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/app_models.dart';

Future<Uint8List> buildStrategyReportPdf(AppData data) async {
  final plan = data.strategyPlan;
  if (plan == null) {
    throw StateError('Complete a questionnaire before exporting a report.');
  }
  final reportFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/SpaceGrotesk.ttf'),
  );
  final document = pw.Document(
    title: 'RevoCred ${plan.code} Strategy Report',
    author: 'RevoCred',
    subject: 'Personalized credit card strategy',
    theme: pw.ThemeData.withFont(base: reportFont, bold: reportFont),
  );
  final value = strategyReportYearOneValue(data);

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(42),
      header: (context) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColor.fromInt(0xffd9ddef)),
          ),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'REVOCRED',
              style: pw.TextStyle(
                color: const PdfColor.fromInt(0xff5b5ce2),
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.8,
              ),
            ),
            pw.Text(
              '${plan.code}  •  PERSONAL STRATEGY',
              style: const pw.TextStyle(
                color: PdfColor.fromInt(0xff667085),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Educational guidance • Verify current issuer terms before applying',
              style: const pw.TextStyle(
                fontSize: 8,
                color: PdfColor.fromInt(0xff667085),
              ),
            ),
            pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ),
      build: (context) => [
        pw.SizedBox(height: 22),
        pw.Text(
          'Your Personalized Credit Card Strategy',
          style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          '${data.profile.name} • ${plan.title}',
          style: const pw.TextStyle(
            fontSize: 13,
            color: PdfColor.fromInt(0xff667085),
          ),
        ),
        _section('Your credit profile', [
          _row('Strategy', '${plan.code} — ${plan.title}'),
          _row('Profile band', plan.userType),
          _row('Primary goal', plan.goal),
          _row('Annual fee comfort', plan.feeLevel),
          _row('Travel focus', plan.travelScope),
        ]),
        _section(
          'Cards you already have',
          data.wallet.isEmpty
              ? [pw.Text('No active cards were added during onboarding.')]
              : data.wallet
                    .map((card) => _bullet('${card.name} — ${card.bestUse}'))
                    .toList(),
        ),
        _section('Recommended strategy', [
          pw.Text(
            'Build around the ${plan.ecosystem} ecosystem, keeping each card only when its rewards and benefits outweigh its cost.',
          ),
          if (plan.debitCard.isNotEmpty) ...[
            pw.SizedBox(height: 7),
            _bullet('Optional banking foundation: ${plan.debitCard}'),
          ],
        ]),
        _section(
          'How to use your wallet',
          data.wallet.isEmpty
              ? [
                  pw.Text(
                    'Start with the first roadmap card, pay every statement in full, and use it for normal budgeted purchases while building history.',
                  ),
                ]
              : data.wallet
                    .map(
                      (card) => _bullet(
                        'Use ${card.name} for ${card.bestUse.toLowerCase()} when issuer terms and merchant coding qualify.',
                      ),
                    )
                    .toList(),
        ),
        _section(
          'Application roadmap',
          data.roadmap.indexed
              .map(
                (entry) => _numbered(
                  entry.$1 + 1,
                  entry.$2.cardId,
                  '${entry.$2.stage}: ${entry.$2.note}',
                ),
              )
              .toList(),
        ),
        _section('Current wallet annual value', [
          pw.Text(
            '\$$value',
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: const PdfColor.fromInt(0xff087f5b),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Current wallet estimate after annual fees. One cent per point; excludes housing rewards, bonuses, conditional credits and conditional reward uplift. Not guaranteed value.',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColor.fromInt(0xff667085),
            ),
          ),
        ]),
        _section('Important notes', [
          _bullet(
            'Pay statement balances in full; interest can erase rewards value.',
          ),
          _bullet(
            'Approval, welcome offers, benefits, annual fees, and issuer rules can change.',
          ),
          _bullet(
            'Do not apply only for rewards if the account does not fit your budget and credit profile.',
          ),
          _bullet(
            'This report is educational guidance, not financial, tax, legal, or approval advice.',
          ),
        ]),
      ],
    ),
  );
  return document.save();
}

Future<void> downloadStrategyReport(AppData data) async {
  final code = data.strategyPlan?.code.toLowerCase() ?? 'personal';
  await Printing.layoutPdf(
    name: 'revocred-$code-strategy-report.pdf',
    onLayout: (_) => buildStrategyReportPdf(data),
  );
}

Future<void> shareStrategyReport(AppData data) async {
  final code = data.strategyPlan?.code.toLowerCase() ?? 'personal';
  await Printing.sharePdf(
    bytes: await buildStrategyReportPdf(data),
    filename: 'revocred-$code-strategy-report.pdf',
  );
}

int strategyReportYearOneValue(AppData data) {
  return data.projectedYearlyValue;
}

pw.Widget _section(String title, List<pw.Widget> children) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 22),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 9,
          letterSpacing: 1.2,
          fontWeight: pw.FontWeight.bold,
          color: const PdfColor.fromInt(0xff5b5ce2),
        ),
      ),
      pw.SizedBox(height: 9),
      ...children,
    ],
  ),
);

pw.Widget _row(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 5),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 118,
        child: pw.Text(
          label,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
      ),
      pw.Expanded(child: pw.Text(value)),
    ],
  ),
);

pw.Widget _bullet(String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 6),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('•  '),
      pw.Expanded(child: pw.Text(text)),
    ],
  ),
);

pw.Widget _numbered(int number, String title, String note) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 10),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 22,
        height: 22,
        alignment: pw.Alignment.center,
        decoration: const pw.BoxDecoration(
          color: PdfColor.fromInt(0xff5b5ce2),
          shape: pw.BoxShape.circle,
        ),
        child: pw.Text(
          '$number',
          style: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 9,
          ),
        ),
      ),
      pw.SizedBox(width: 9),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text(
              note,
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColor.fromInt(0xff667085),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);
