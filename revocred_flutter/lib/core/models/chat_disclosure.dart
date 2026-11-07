class ChatDisclosure {
  const ChatDisclosure.basic()
    : external = false,
      version = '',
      recipient = '',
      model = '',
      dataUse = '',
      dataUsePoints = const [],
      searchProvider = '';

  const ChatDisclosure({
    required this.version,
    required this.recipient,
    required this.model,
    required this.dataUse,
    this.dataUsePoints = const [],
    this.searchProvider = '',
  }) : external = true;

  factory ChatDisclosure.fromJson(Map<String, dynamic> json) {
    if (json['external'] == false) return const ChatDisclosure.basic();
    if (json['external'] != true ||
        !['version', 'recipient', 'model', 'data_use'].every(
          (key) => json[key] is String && (json[key] as String).isNotEmpty,
        ) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(json['version'] as String)) {
      throw const FormatException('AI sharing notice is unavailable.');
    }
    return ChatDisclosure(
      version: json['version'] as String,
      recipient: json['recipient'] as String,
      model: json['model'] as String,
      dataUse: json['data_use'] as String,
      dataUsePoints: json['data_use_points'] == null
          ? [json['data_use'] as String]
          : (json['data_use_points'] as List).cast<String>(),
      searchProvider: (json['search_provider'] as String?) ?? '',
    );
  }

  final bool external;
  final String version;
  final String recipient;
  final String model;
  final String dataUse;
  final List<String> dataUsePoints;
  final String searchProvider;
}
