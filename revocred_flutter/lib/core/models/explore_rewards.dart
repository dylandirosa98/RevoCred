/// Illustrative flight and hotel redemptions for the Explore Rewards screen.
/// These are example prices, not live fares or award availability, and they
/// never affect card selection.
class ExploreRewards {
  const ExploreRewards({
    required this.version,
    required this.airports,
    required this.regions,
    required this.fares,
    required this.flightDisclaimer,
    required this.hotelDisclaimer,
    required this.estimateDisclaimer,
  });

  factory ExploreRewards.fromJson(Map<String, dynamic> json) {
    final disclaimers = _map(json['disclaimers']);
    final fares = <String, Map<String, ExploreFare>>{};
    _map(json['fares']).forEach((origin, byDestination) {
      fares[origin] = {
        for (final entry in _map(byDestination).entries)
          entry.key: ExploreFare.fromJson(_map(entry.value)),
      };
    });
    final rewards = ExploreRewards(
      version: (json['version'] ?? '').toString(),
      airports: _list(json['airports'], ExploreAirport.fromJson),
      regions: _list(json['regions'], ExploreRegion.fromJson),
      fares: fares,
      flightDisclaimer: (disclaimers['flights'] ?? '').toString(),
      hotelDisclaimer: (disclaimers['hotels'] ?? '').toString(),
      estimateDisclaimer: (disclaimers['estimate'] ?? '').toString(),
    );
    if (rewards.airports.isEmpty ||
        rewards.regions.isEmpty ||
        rewards.flightDisclaimer.isEmpty ||
        rewards.hotelDisclaimer.isEmpty) {
      throw const FormatException('Reward examples are incomplete.');
    }
    return rewards;
  }

  final String version;
  final List<ExploreAirport> airports;
  final List<ExploreRegion> regions;

  /// Fares by departure airport, then arrival airport code.
  final Map<String, Map<String, ExploreFare>> fares;
  final String flightDisclaimer;
  final String hotelDisclaimer;
  final String estimateDisclaimer;

  /// Destinations in [region] reachable from [origin]; never the origin itself.
  List<ExploreDestination> destinations(
    ExploreRegion region,
    String origin,
  ) => [
    for (final flight in region.flights)
      if (flight.code != origin && fares[origin]?[flight.code] != null) flight,
  ];

  ExploreFare? fare(String origin, String destination) =>
      fares[origin]?[destination];
}

class ExploreAirport {
  const ExploreAirport({required this.code, required this.city});
  factory ExploreAirport.fromJson(Map<String, dynamic> json) => ExploreAirport(
    code: (json['code'] ?? '').toString(),
    city: (json['city'] ?? '').toString(),
  );
  final String code;
  final String city;
}

class ExploreDestination {
  const ExploreDestination({required this.code, required this.name});
  factory ExploreDestination.fromJson(Map<String, dynamic> json) =>
      ExploreDestination(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
      );
  final String code;
  final String name;
}

class ExploreHotel {
  const ExploreHotel({
    required this.name,
    required this.place,
    required this.program,
    required this.cash,
    required this.points,
  });
  factory ExploreHotel.fromJson(Map<String, dynamic> json) => ExploreHotel(
    name: (json['name'] ?? '').toString(),
    place: (json['place'] ?? '').toString(),
    program: (json['program'] ?? '').toString(),
    cash: _int(json['cash']),
    points: _int(json['points']),
  );
  final String name;
  final String place;
  final String program;

  /// Cash price per night in whole dollars.
  final int cash;

  /// Award points per night.
  final int points;
}

class ExploreRegion {
  const ExploreRegion({
    required this.name,
    required this.flights,
    required this.hotels,
  });
  factory ExploreRegion.fromJson(Map<String, dynamic> json) => ExploreRegion(
    name: (json['name'] ?? '').toString(),
    flights: _list(json['flights'], ExploreDestination.fromJson),
    hotels: _list(json['hotels'], ExploreHotel.fromJson),
  );
  final String name;
  final List<ExploreDestination> flights;
  final List<ExploreHotel> hotels;
}

class ExploreFare {
  const ExploreFare({
    required this.cash,
    required this.points,
    required this.fees,
    required this.airline,
  });
  factory ExploreFare.fromJson(Map<String, dynamic> json) => ExploreFare(
    cash: _int(json['cash']),
    points: _int(json['points']),
    fees: _int(json['fees']),
    airline: (json['airline'] ?? '').toString(),
  );

  /// One-way cash fare in whole dollars.
  final int cash;
  final int points;

  /// Taxes and fees still paid when booking with points, in whole dollars.
  final int fees;
  final String airline;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

List<T> _list<T>(Object? value, T Function(Map<String, dynamic>) parse) => [
  if (value is List)
    for (final item in value)
      if (item is Map) parse(item.cast<String, dynamic>()),
];

int _int(Object? value) => value is num ? value.round() : 0;
