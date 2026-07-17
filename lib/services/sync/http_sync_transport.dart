import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/v2/timing_event.dart';
import 'sync_transport.dart';

class HttpSyncTransport implements SyncTransport {
  HttpSyncTransport({
    required this.baseUrl,
    required this.sessionId,
    required this.accessToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String sessionId;
  final String accessToken;
  final http.Client _client;
  int _cursor = 0;

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
        baseUrl.replaceFirst(RegExp(r'/$'), '') + path,
      ).replace(queryParameters: query);

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'authorization': 'Bearer $accessToken',
      };

  @override
  Future<List<SyncPushReceipt>> push(List<TimingEvent> events) async {
    if (events.isEmpty) return const [];
    final response = await _client.post(
      _uri('/api/events/push'),
      headers: _headers,
      body: jsonEncode({
        'sessionId': sessionId,
        'events': events.map((event) => event.canonicalPayload()).toList(),
      }),
    );
    final body = _decode(response);
    return (body['receipts']! as List)
        .map((raw) {
          final item = Map<String, Object?>.from(raw as Map);
          return SyncPushReceipt(
            eventId: item['eventId']! as String,
            decision: SyncPushDecision.values.byName(item['decision']! as String),
            reason: item['reason'] as String?,
            serverReceivedAt: item['serverReceivedAt'] == null
                ? null
                : DateTime.parse(item['serverReceivedAt']! as String),
          );
        })
        .toList();
  }

  @override
  Future<List<TimingEvent>> pull({required String deviceId}) async {
    final response = await _client.get(
      _uri('/api/events/pull', {
        'sessionId': sessionId,
        'after': _cursor.toString(),
        'deviceId': deviceId,
      }),
      headers: _headers,
    );
    final body = _decode(response);
    _cursor = (body['cursor'] as num?)?.toInt() ?? _cursor;
    return (body['events']! as List)
        .map((raw) => TimingEvent.fromJson({
              ...Map<String, Object?>.from(raw as Map),
              'syncState': 'synced',
              'schemaVersion': 2,
            }))
        .toList();
  }

  Map<String, Object?> _decode(http.Response response) {
    final body = response.body.isEmpty
        ? <String, Object?>{}
        : Map<String, Object?>.from(jsonDecode(response.body) as Map);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(body['error'] as String? ??
          'Synchronisationsserver meldet ${response.statusCode}.');
    }
    return body;
  }
}
