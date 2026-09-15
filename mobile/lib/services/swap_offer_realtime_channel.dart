import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../models/swap_message.dart';
import '../models/swap_offer.dart';

/// A live connection to a single swap offer's private chat channel, over
/// Laravel Reverb (self-hosted, Pusher-protocol-compatible WebSocket
/// server) — real push delivery, not polling: new messages and status
/// changes from the other party arrive the moment
/// `App\Events\MessageSent`/`SwapStatusUpdated` broadcast them.
///
/// Scoped to one swap offer / one screen lifetime: create, [connect], read
/// events via [onMessage]/[onStatusUpdated], then [dispose] when the thread
/// screen closes.
class SwapOfferRealtimeChannel {
  SwapOfferRealtimeChannel({required Dio dio, required this.swapOfferId})
    : _dio = dio;

  final Dio _dio;
  final int swapOfferId;

  void Function(SwapMessage message)? onMessage;
  void Function(SwapOfferStatus status)? onStatusUpdated;
  void Function(Object error)? onError;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  String? _socketId;
  bool _subscribed = false;
  bool _disposed = false;
  Timer? _inactivityTimer;
  Timer? _reconnectTimer;

  static const _activityTimeout = Duration(seconds: 25);
  static const _pongGrace = Duration(seconds: 10);

  String get _channelName => 'private-swap.$swapOfferId';

  String get _httpOrigin => Uri.parse(AppConfig.apiBaseUrl).origin;

  String get _wsUrl {
    final origin = _httpOrigin;
    final wsOrigin = origin.startsWith('https://')
        ? origin.replaceFirst('https://', 'wss://')
        : origin.replaceFirst('http://', 'ws://');
    return '$wsOrigin/app/${AppConfig.reverbAppKey}'
        '?protocol=7&client=agrohub-flutter&version=1.0';
  }

  Future<void> connect() async {
    if (_disposed) return;

    try {
      final channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      await channel.ready;
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleRaw,
        onError: (Object e) {
          onError?.call(e);
          _scheduleReconnect();
        },
        onDone: _scheduleReconnect,
      );
    } catch (e) {
      onError?.call(e);
      _scheduleReconnect();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _inactivityTimer?.cancel();
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _subscribed = false;
    _socketId = null;
    _inactivityTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), connect);
  }

  void _handleRaw(dynamic raw) {
    _resetInactivityTimer();

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    final event = decoded['event'] as String?;
    final rawData = decoded['data'];
    final data = rawData is String
        ? jsonDecode(rawData) as Map<String, dynamic>
        : (rawData as Map<String, dynamic>?);

    switch (event) {
      case 'pusher:connection_established':
        _socketId = data?['socket_id'] as String?;
        _subscribeToChannel();
      case 'pusher:ping':
        _send({'event': 'pusher:pong', 'data': {}});
      case 'pusher:error':
        onError?.call(data?['message'] ?? 'Realtime connection error');
      case 'message.sent':
        if (data != null) onMessage?.call(SwapMessage.fromJson(data));
      case 'swap.status-updated':
        final statusValue = data?['status'] as String?;
        if (statusValue != null) {
          onStatusUpdated?.call(SwapOfferStatus.fromValue(statusValue));
        }
    }
  }

  Future<void> _subscribeToChannel() async {
    if (_subscribed || _socketId == null) return;

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_httpOrigin/broadcasting/auth',
        data: {'channel_name': _channelName, 'socket_id': _socketId},
      );
      final auth = response.data?['auth'] as String?;
      if (auth == null) return;

      _send({
        'event': 'pusher:subscribe',
        'data': {'auth': auth, 'channel': _channelName},
      });
      _subscribed = true;
    } catch (e) {
      onError?.call(e);
    }
  }

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  /// Defends against a "zombie" connection some mobile networks leave open
  /// without a clean TCP close: if nothing at all has arrived (not even the
  /// server's own keepalive ping) within the activity timeout, proactively
  /// ping, then reconnect if that goes unanswered too.
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_activityTimeout, () {
      _send({'event': 'pusher:ping', 'data': {}});
      _inactivityTimer = Timer(_pongGrace, _scheduleReconnect);
    });
  }
}
