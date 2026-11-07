import 'dart:convert';

/// Display-only formatting. Never changes source records or calculation inputs.
String cardDetailText(String text) {
  final marker = RegExp(
    r'\s*·\s*cap:\s*',
    caseSensitive: false,
  ).firstMatch(text);
  if (marker == null) return text.trim();
  final description = text.substring(0, marker.start).trim();
  String limit = 'see issuer terms';
  try {
    final cap = jsonDecode(text.substring(marker.end));
    if (cap is Map &&
        cap['amount'] is num &&
        cap['currency'] is String &&
        cap['period'] is String &&
        (cap['period'] as String).isNotEmpty) {
      final money = _money(cap['amount'] as num, cap['currency'] as String);
      if (money != null) limit = '$money ${_period(cap['period'] as String)}';
    }
  } on FormatException {
    // Do not expose malformed upstream JSON or invent an unlimited allowance.
  }
  return '$description · Spending limit: $limit';
}

String? _money(num amount, String currency) {
  if (!amount.isFinite ||
      amount < 0 ||
      !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
    return null;
  }
  final fixed = amount.toStringAsFixed(2);
  final parts = fixed.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final decimal = parts.last == '00' ? '' : '.${parts.last}';
  return currency == 'USD' ? '\$$whole$decimal' : '$currency $whole$decimal';
}

String _period(String value) {
  final normalized = value.replaceAll('_', ' ').trim();
  return switch (normalized) {
    'quarter' => 'per quarter',
    'calendar year' => 'per calendar year',
    'year' => 'per year',
    'month' => 'per month',
    'first 6 months' => 'in the first 6 months',
    'first 3 months' => 'in the first 3 months',
    _ => normalized,
  };
}

/// Reassembles display-only travel fields without exposing schema plumbing.
/// Null/missing visit limits do not become unlimited lounge access.
List<String> cardTravelPerkText(Iterable<String> lines) {
  final groups = <String, List<(String, String)>>{};
  for (final raw in lines) {
    final line = cardDetailText(raw);
    final separator = line.indexOf(': ');
    if (separator < 0) {
      groups.putIfAbsent(line, () => []);
      continue;
    }
    final path = line.substring(0, separator).split(' · ');
    final value = line.substring(separator + 2);
    final group = path.length == 1
        ? path.first
        : path.sublist(0, path.length - 1).join(' · ');
    groups.putIfAbsent(group, () => []).add((
      path.length == 1 ? '' : path.last,
      value,
    ));
  }

  final result = <String>[];
  for (final entry in groups.entries) {
    final group = entry.key;
    final fields = entry.value;
    if (fields.isEmpty) {
      if (group.isNotEmpty) result.add(group);
      continue;
    }
    if (group == 'Other') {
      result.addAll(fields.map((f) => _scalar(f.$2)));
      continue;
    }
    String? field(String name) =>
        fields.where((f) => f.$1 == name).firstOrNull?.$2;
    final amount = num.tryParse(field('Amount') ?? '');
    final currency = field('Currency');
    final cadence = field('Period');
    final money = amount != null && currency != null
        ? _money(amount, currency)
        : null;
    final details = <String>[];
    if (money != null) {
      details.add(cadence == null ? money : '$money ${_period(cadence)}');
    } else {
      if (field('Amount') != null) details.add('Amount: ${field('Amount')}');
      if (cadence != null) {
        final period = _period(cadence);
        details.add(period == 'see issuer terms' ? 'See issuer terms' : period);
      }
    }
    for (final (name, value) in fields) {
      if (['Amount', 'Currency', 'Period'].contains(name)) continue;
      details.add(switch (name) {
        '' => _scalar(value),
        'Notes' || 'Program' => _scalar(value),
        _ => '$name: ${_scalar(value, booleanStatus: false)}',
      });
    }
    if (details.isEmpty) details.add('See issuer terms');
    result.add('$group — ${details.join(' · ')}');
  }
  return result;
}

String _scalar(String value, {bool booleanStatus = true}) => switch (value) {
  'true' => booleanStatus ? 'Included' : 'Yes',
  'false' => booleanStatus ? 'Not included' : 'No',
  _ => value,
};
