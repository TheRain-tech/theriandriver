import 'package:firebase_auth/firebase_auth.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/env_config.dart';

class DriverRealtimeService {
  DriverRealtimeService._();

  static final instance = DriverRealtimeService._();

  io.Socket? _socket;
  String? _joinedFleetChatThreadId;

  bool get isConnected => _socket?.connected == true;

  Future<void> connect() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in to connect to live updates.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('A valid sign-in token is required for live updates.');
    }
    if (_socket?.connected == true) return;

    _socket?.dispose();
    final socket = io.io(
      EnvConfig.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;
    socket.on('connect', (_) {
      final threadId = _joinedFleetChatThreadId;
      if (threadId != null) {
        socket.emit('fleet-chat:join', {'threadId': threadId});
      }
    });
    socket.connect();
  }

  void listen(String event, void Function(dynamic payload) listener) {
    _socket?.on(event, listener);
  }

  void stopListening(String event) {
    _socket?.off(event);
  }

  void joinFleetChat(String threadId) {
    _joinedFleetChatThreadId = threadId;
    _socket?.emit('fleet-chat:join', {'threadId': threadId});
  }

  void leaveFleetChat(String threadId) {
    if (_joinedFleetChatThreadId != threadId) return;
    _socket?.emit('fleet-chat:leave', {'threadId': threadId});
    _joinedFleetChatThreadId = null;
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _joinedFleetChatThreadId = null;
  }
}
