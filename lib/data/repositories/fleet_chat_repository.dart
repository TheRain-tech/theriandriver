import '../../services/api_client.dart';

class FleetChatConversation {
  const FleetChatConversation({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageAt,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  factory FleetChatConversation.fromMap(Map<String, dynamic> map) {
    return FleetChatConversation(
      id: _requiredString(map, 'id'),
      displayName: _optionalString(map['displayName']) ?? 'Fleet',
      avatarUrl: _optionalString(map['avatarUrl']),
      lastMessage: _optionalString(map['lastMessage']),
      lastMessageAt: _dateTime(map['lastMessageAt']),
    );
  }
}

class FleetChatMessage {
  const FleetChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String senderId;
  final String senderRole;
  final String senderName;
  final String text;
  final DateTime? createdAt;

  factory FleetChatMessage.fromMap(Map<String, dynamic> map) {
    return FleetChatMessage(
      id: _requiredString(map, 'id'),
      senderId: _optionalString(map['senderId']) ?? '',
      senderRole: _optionalString(map['senderRole']) ?? '',
      senderName: _optionalString(map['senderName']) ?? '',
      text: _optionalString(map['text']) ?? '',
      createdAt: _dateTime(map['createdAt']),
    );
  }
}

class FleetChatRepository {
  FleetChatRepository({ApiClient? client})
    : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  Future<List<FleetChatConversation>> listConversations() async {
    final result = await _client.get('/api/fleet-chat/conversations');
    if (result is! List) {
      throw const FormatException(
        'Fleet chat returned an invalid conversation list.',
      );
    }
    return result
        .whereType<Map>()
        .map(
          (row) => FleetChatConversation.fromMap(
            row.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<List<FleetChatMessage>> listMessages(String threadId) async {
    final result = await _client.get(
      '/api/fleet-chat/conversations/$threadId/messages',
    );
    if (result is! List) {
      throw const FormatException(
        'Fleet chat returned an invalid message list.',
      );
    }
    return result
        .whereType<Map>()
        .map(
          (row) => FleetChatMessage.fromMap(
            row.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<FleetChatMessage> sendMessage(String threadId, String text) async {
    final result = await _client.post(
      '/api/fleet-chat/conversations/$threadId/messages',
      body: {'text': text},
    );
    if (result is! Map) {
      throw const FormatException('Fleet chat returned an invalid message.');
    }
    return FleetChatMessage.fromMap(
      result.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = _optionalString(map[key]);
  if (value == null)
    throw FormatException('Fleet chat field "$key" is missing.');
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

DateTime? _dateTime(Object? value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
