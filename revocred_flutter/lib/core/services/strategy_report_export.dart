import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../logic/strategy_digest.dart';
import '../logic/strategy_report_copy.dart';
import '../logic/card_art.dart';
import '../models/app_models.dart';
import '../models/affiliate_offer.dart';
import 'strategy_report_delivery.dart';

const _purple = PdfColor.fromInt(0xff6400ed);
const _ink = PdfColor.fromInt(0xff15182d);
const _pale = PdfColor.fromInt(0xfff5f3ff);

/// One portrait strategy sheet, in the same order as StrategyRoadmapView.
/// Content-measured height accommodates larger wallets without dropping roles
/// or leaving a guessed amount of blank space below the branded footer.
Future<Uint8List> buildStrategyReportPdf(
  AppData data, {
  ApplicationLink? application,
}) async {
  final plan = data.strategyPlan;
  if (plan == null) {
    throw StateError('Complete a questionnaire before exporting a report.');
  }
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/SpaceGrotesk.ttf'),
  );
  final headingFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Anton-Regular.ttf'),
  );
  final brandFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/SpaceGrotesk-Bold.ttf'),
  );
  final document = pw.Document(
    title: 'RevoCred ${plan.code} Strategy Report',
    author: 'RevoCred',
    subject: 'Personalized credit card strategy',
    theme: pw.ThemeData.withFont(base: font, bold: headingFont),
  );
  final slots = strategyRoadmapSlots(data);
  final art = <String, pw.MemoryImage>{};
  for (final slot in slots) {
    final path = _slotArtAsset(data, slot);
    if (!art.containsKey(path)) {
      art[path] = pw.MemoryImage(
        (await rootBundle.load(path)).buffer.asUint8List(),
      );
    }
  }
  final digest = strategyDigest(data);
  final targets = strategyTargetCards(data);
  final feesKnown =
      targets.length == slots.length &&
      targets.every((card) => !card.termsUnknown);
  final fees = targets.fold<int>(
    0,
    (sum, card) =>
        sum +
        (int.tryParse(card.annualFee.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0),
  );
  document.addPage(
    pw.Page(
      pageFormat: const PdfPageFormat(650, double.infinity),
      margin: const pw.EdgeInsets.all(20),
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: 'REVO',
                            style: pw.TextStyle(
                              color: _ink,
                              fontSize: 36,
                              font: brandFont,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.TextSpan(
                            text: 'CRED',
                            style: pw.TextStyle(
                              color: _purple,
                              fontSize: 36,
                              font: brandFont,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _text('CREDIT CARD STRATEGY', size: 9),
                    _text(
                      'Smart strategies. Bigger rewards. A brighter financial future.',
                      size: 8,
                    ),
                  ],
                ),
              ),
              _pdfScore(data),
            ],
          ),
          pw.Divider(color: _purple),
          pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.centerLeft,
            child: pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(font: headingFont, fontSize: 32),
                children: [
                  pw.TextSpan(
                    text: digest.title
                        .replaceFirst('Credit Card Strategy', '')
                        .toUpperCase(),
                  ),
                  const pw.TextSpan(
                    text: 'CREDIT CARD STRATEGY',
                    style: pw.TextStyle(color: _purple),
                  ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 4),
          _text(
            'A ${slots.length}-role plan to maximize your rewards and reach your goals',
            size: 11,
          ),
          pw.SizedBox(height: 12),
          _columns([
            _summary('Your goal', plan.goal, 'goal'),
            _summary(
              'Annual fee preference',
              strategyFeePreference(data),
              'fees',
            ),
            _summary('Travel focus', plan.travelScope, 'travel'),
            _summary(
              'Top spending categories',
              digest.spending.isEmpty
                  ? data.profile.topSpendCategories
                  : digest.spending.take(3).map((entry) => entry.$1).join(', '),
              'spending',
            ),
          ]),
          pw.SizedBox(height: 12),
          for (var start = 0; start < slots.length; start += 4) ...[
            if (start == 0) ...[
              _text(strategyRolesExplanation, size: 9),
              pw.SizedBox(height: 4),
              _text(strategyEligibilityExplanation, size: 9),
              pw.SizedBox(height: 10),
            ],
            _columns([
              for (var i = start; i < slots.length && i < start + 4; i++)
                _card(
                  data,
                  slots[i],
                  i + 1,
                  art,
                  math.min(
                    220,
                    (610 - 8 * (math.min(4, slots.length - start) - 1)) /
                            math.min(4, slots.length - start) -
                        16,
                  ),
                ),
            ]),
            pw.SizedBox(height: 10),
          ],
          _box(
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _iconHeading('Application timeline', 'calendar'),
                pw.SizedBox(height: 8),
                if (slots.isEmpty)
                  _text(
                    'No new application recommended. Keep using your current wallet.',
                  ),
                for (var start = 0; start < slots.length; start += 4) ...[
                  _columns([
                    for (var i = start; i < slots.length && i < start + 4; i++)
                      pw.Column(
                        children: [
                          pw.Stack(
                            alignment: pw.Alignment.center,
                            children: [
                              if (slots.length > 1)
                                pw.SvgImage(
                                  svg:
                                      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 130 26"><path d="M0 13h130m-6-4 5 4-5 4" fill="none" stroke="#15182d" stroke-width="1"/></svg>',
                                  width: 130,
                                  height: 26,
                                ),
                              pw.Container(
                                width: 26,
                                height: 26,
                                alignment: pw.Alignment.center,
                                decoration: const pw.BoxDecoration(
                                  color: _purple,
                                  shape: pw.BoxShape.circle,
                                ),
                                child: _text(
                                  '${i + 1}',
                                  size: 13,
                                  color: PdfColors.white,
                                  bold: true,
                                ),
                              ),
                            ],
                          ),
                          pw.SizedBox(height: 6),
                          _text(slots[i].timing, color: _purple, bold: true),
                          pw.SizedBox(height: 5),
                          _text(slots[i].displayName, bold: true),
                          pw.SizedBox(height: 5),
                          _text(slots[i].timingNote, size: 8),
                          if (slots[i].status == StrategySlotStatus.substituted)
                            _text(
                              'Owned substitute for ${slots[i].targetName}',
                              size: 8,
                            ),
                        ],
                      ),
                  ]),
                  pw.SizedBox(height: 8),
                ],
              ],
            ),
          ),
          if (data.wallet.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _text(
              'CURRENT WALLET (${data.wallet.length} CARDS): ${data.wallet.map((card) => card.name).join(' • ')}',
              size: 8,
            ),
          ],
          pw.SizedBox(height: 10),
          _columns([
            _box(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _iconHeading('How they work together', 'gear'),
                  pw.SizedBox(height: 8),
                  for (var start = 0; start < slots.length; start += 3) ...[
                    _columns([
                      for (
                        var i = start;
                        i < slots.length && i < start + 3;
                        i++
                      )
                        pw.Column(
                          children: [
                            _text(
                              strategyCardFor(
                                    data,
                                    slots[i].displayName,
                                  )?.bestUse ??
                                  slots[i].use,
                              size: 8,
                              bold: true,
                            ),
                            pw.SizedBox(height: 5),
                            pw.SizedBox(
                              width: 85,
                              height: 54,
                              child: pw.Image(
                                art[_slotArtAsset(data, slots[i])]!,
                                fit: pw.BoxFit.contain,
                              ),
                            ),
                            pw.SizedBox(height: 5),
                            _text(slots[i].displayName, size: 8, bold: true),
                            _text(
                              slots[i].isCovered
                                  ? 'Ready to use'
                                  : slots[i].status ==
                                        StrategySlotStatus.unavailable
                                  ? 'Not currently recommended'
                                  : 'Use after acquisition',
                              size: 7,
                              color: _purple,
                            ),
                          ],
                        ),
                    ]),
                    pw.SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            _box(
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _iconHeading('Your potential rewards', 'bars'),
                  pw.SizedBox(height: 8),

                  _rewardLine(
                    'travel',
                    'Travel redemption uplift',
                    'Not modeled',
                  ),
                  _rewardLine(
                    'wallet',
                    'Target annual fees',
                    feesKnown ? '\$$fees' : 'Not verified',
                  ),
                  pw.SizedBox(height: 8),
                  _text(strategyValueExplanation(data), size: 8),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _purple),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: _rewardLine(
                      'trophy',
                      'ESTIMATED ONGOING YEARLY VALUE',
                      '\$${data.projectedYearlyValue}/year',
                    ),
                  ),
                ],
              ),
            ),
          ]),
          pw.SizedBox(height: 10),
          if (application != null && application.isCurrent) ...[
            pw.UrlLink(
              destination: application.uri.toString(),
              child: _text(
                'View offer: ${application.cardName}',
                color: _purple,
              ),
            ),
            _text(
              '${application.disclosure} External site. Approval is not guaranteed.',
              size: 7,
            ),
            pw.SizedBox(height: 6),
          ],
          _text(
            'Educational guidance, not approval advice. Pay statements in full, verify current issuer terms, and check account history before applying. Interest can erase rewards. Demo terms, if present, are unverified.',
            size: 8,
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            color: _ink,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _text('REVOCRED', size: 18, color: PdfColors.white, bold: true),
                pw.Column(
                  children: [
                    _text(
                      'SAME SPENDING. MORE REWARDS.',
                      color: PdfColors.white,
                      bold: true,
                    ),
                    _text(
                      'PLAN TODAY. TRAVEL TOMORROW.',
                      size: 8,
                      color: PdfColors.white,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  return document.save();
}

pw.Widget _text(
  String text, {
  double size = 9,
  PdfColor color = _ink,
  bool bold = false,
}) => pw.Text(
  text,
  style: pw.TextStyle(
    fontSize: size,
    color: color,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  ),
);

pw.Widget _heading(String text) =>
    _text(text.toUpperCase(), size: 16, bold: true);

pw.Widget _pdfIcon(String kind, double size) {
  final path = switch (kind) {
    'goal' =>
      '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><path d="M12 12L22 2m-5 0h5v5"/>',
    'fees' =>
      '<ellipse cx="12" cy="5" rx="7" ry="3"/><path d="M5 5v13c0 4 14 4 14 0V5M5 10c0 4 14 4 14 0M5 15c0 4 14 4 14 0"/>',
    'travel' =>
      '<path d="M2 14l8-3L8 3l3-1 5 8 6-2 1 3-7 3-1 8-3 1-1-8-7 2z"/>',
    'spending' =>
      '<path d="M2 3h3l3 13h11l3-10H6"/><circle cx="9" cy="21" r="1"/><circle cx="18" cy="21" r="1"/>',
    'calendar' =>
      '<rect x="3" y="5" width="18" height="17" rx="1"/><path d="M7 2v6m10-6v6M3 11h18m-14 4h2m3 0h2m3 0h2m-12 4h2m3 0h2"/>',
    'bars' => '<path d="M4 22V14h3v8zm7 0V8h3v14zm7 0V2h3v20z"/>',
    'wallet' =>
      '<rect x="2" y="6" width="20" height="15" rx="2"/><path d="M3 6V3h16v3m-4 7h7v5h-7z"/>',
    'trophy' =>
      '<path d="M7 3h10v5c0 9-10 9-10 0zM7 5H3v3c0 4 4 5 5 5m9-8h4v3c0 4-4 5-5 5m-4 2v6m-5 0h10"/>',
    _ =>
      '<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3"/><path d="M12 0v5m0 14v5M0 12h5m14 0h5M3 3l4 4m10 10l4 4M3 21l4-4M17 7l4-4"/>',
  };
  return pw.SvgImage(
    svg:
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g fill="none" stroke="#6400ed" stroke-width="2" stroke-linejoin="round" stroke-linecap="round">$path</g></svg>',
    width: size,
    height: size,
  );
}

pw.Widget _iconHeading(String text, String icon) => pw.Row(
  children: [
    _pdfIcon(icon, 22),
    pw.SizedBox(width: 8),
    pw.Expanded(child: _heading(text)),
  ],
);

pw.Widget _rewardLine(String icon, String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 8),
  child: pw.Row(
    children: [
      _pdfIcon(icon, 20),
      pw.SizedBox(width: 7),
      pw.Expanded(flex: 3, child: _text(label, size: 8)),
      pw.SizedBox(width: 5),
      pw.Expanded(
        flex: 2,
        child: _text(value, size: 13, bold: true, color: _purple),
      ),
    ],
  ),
);

pw.Widget _pdfScore(AppData data) {
  String points(double fraction) => List.generate(61, (i) {
    final theta = math.pi + math.pi * fraction * i / 60;
    return '${60 + 52 * math.cos(theta)},${62 + 52 * math.sin(theta)}';
  }).join(' ');
  final svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 70"><polyline points="${points(1)}" fill="none" stroke="#ded8ec" stroke-width="10" stroke-linecap="round"/><polyline points="${points(data.pointsValue.clamp(0, 100) / 100)}" fill="none" stroke="#6400ed" stroke-width="10" stroke-linecap="round"/></svg>';
  return pw.SizedBox(
    width: 230,
    child: _box(
      pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Column(
              children: [
                _text('YOUR WALLET SCORE', size: 12, bold: true),
                pw.SizedBox(height: 4),
                pw.Stack(
                  alignment: pw.Alignment.bottomCenter,
                  children: [
                    pw.SvgImage(svg: svg, width: 106, height: 63),
                    pw.Column(
                      children: [
                        _text('${data.pointsValue}', size: 25, bold: true),
                        _text('/100', size: 8),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _text(
                  data.pointsValue >= 80
                      ? 'Strong foundation!'
                      : 'Room to grow!',
                  size: 12,
                  color: _purple,
                  bold: true,
                ),
                pw.SizedBox(height: 4),
                _text(
                  'Follow your ${strategyRoadmapSlots(data).length}-role strategy to make more of your spending.',
                  size: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _box(pw.Widget child) => pw.Container(
  padding: const pw.EdgeInsets.all(10),
  decoration: pw.BoxDecoration(
    color: _pale,
    borderRadius: pw.BorderRadius.circular(8),
  ),
  child: child,
);

pw.Widget _columns(List<pw.Widget> children) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    for (final entry in children.indexed) ...[
      if (entry.$1 > 0) pw.SizedBox(width: 8),
      pw.Expanded(child: entry.$2),
    ],
  ],
);

pw.Widget _summary(String label, String value, String icon) => _box(
  pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _pdfIcon(icon, 24),
      pw.SizedBox(height: 5),
      _text(label.toUpperCase(), size: 12, bold: true),
      pw.SizedBox(height: 5),
      _text(value),
    ],
  ),
);

pw.Widget _card(
  AppData data,
  StrategyRoadmapSlot slot,
  int number,
  Map<String, pw.MemoryImage> art,
  double artWidth,
) {
  final card = strategyCardFor(data, slot.displayName);
  final status = switch (slot.status) {
    StrategySlotStatus.completed => 'IN YOUR WALLET',
    StrategySlotStatus.substituted => 'OWNED SUBSTITUTE',
    StrategySlotStatus.next => 'RECOMMENDED NEXT',
    StrategySlotStatus.later => 'APPLY LATER',
    StrategySlotStatus.unavailable => 'DO NOT APPLY NOW',
  };
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _pale),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          height: 48,
          color: slot.isCovered || slot.status == StrategySlotStatus.next
              ? _purple
              : _ink,
          child: pw.Column(
            children: [
              _text(
                'ROLE $number: $status',
                size: 12,
                color: PdfColors.white,
                bold: true,
              ),
              _text(
                strategyTimingCaption(slot),
                size: 8,
                color: PdfColors.white,
              ),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.SizedBox(
                  width: artWidth,
                  height: artWidth / 1.586,
                  child: pw.Image(
                    art[_slotArtAsset(data, slot)]!,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              _text(slot.displayName.toUpperCase(), size: 14, bold: true),
              if (slot.status == StrategySlotStatus.substituted)
                _text('Covers ${slot.targetName}', size: 8),
              pw.SizedBox(height: 5),
              if (slot.status == StrategySlotStatus.unavailable ||
                  slot.status == StrategySlotStatus.substituted)
                _text(slot.note, size: 8),
              if (card != null) ...[
                for (final benefit in card.benefits.take(3))
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 6),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 12,
                          height: 12,
                          alignment: pw.Alignment.center,
                          decoration: const pw.BoxDecoration(
                            color: _purple,
                            shape: pw.BoxShape.circle,
                          ),
                          child: pw.SvgImage(
                            svg:
                                '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M5 12l5 5 9-11" fill="none" stroke="white" stroke-width="3"/></svg>',
                            width: 9,
                            height: 9,
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Expanded(child: _text(benefit, size: 10)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

int strategyReportYearOneValue(AppData data) => data.projectedYearlyValue;

String _slotArtAsset(AppData data, StrategyRoadmapSlot slot) {
  final card = strategyCardFor(data, slot.displayName);
  return card == null
      ? cardArtAssetForName(slot.displayName)
      : cardArtAsset(card);
}

Future<void> downloadStrategyReport(
  AppData data, {
  ApplicationLink? application,
}) async {
  await deliverStrategyReportDownload(
    await buildStrategyReportPdf(data, application: application),
    'revocred-${data.strategyPlan?.code.toLowerCase() ?? 'personal'}-strategy-report.pdf',
  );
}

Future<void> shareStrategyReport(
  AppData data, {
  ApplicationLink? application,
}) async {
  await deliverStrategyReportShare(
    await buildStrategyReportPdf(data, application: application),
    'revocred-${data.strategyPlan?.code.toLowerCase() ?? 'personal'}-strategy-report.pdf',
  );
}
