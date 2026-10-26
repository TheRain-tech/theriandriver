import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/driver_copy.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../data/repositories/fleet_chat_repository.dart';
import '../../../services/driver_realtime_service.dart';
import '../widgets/driver_bottom_nav.dart';

class DriverFleetChatScreen extends StatefulWidget {
  const DriverFleetChatScreen({super.key});

  @override
  State<DriverFleetChatScreen> createState() => _DriverFleetChatScreenState();
}

class _DriverFleetChatScreenState extends State<DriverFleetChatScreen> {
  final _repository = FleetChatRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _refreshTimer;
  FleetChatConversation? _conversation;
  List<FleetChatMessage> _messages = const [];
  String? _error;
  String? _realtimeError;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshMessages(),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conversations = await _repository.listConversations();
      if (!mounted) return;
      if (conversations.isEmpty) {
        setState(() {
          _conversation = null;
          _messages = const [];
          _loading = false;
        });
        return;
      }
      final conversation = conversations.first;
      final messages = await _repository.listMessages(conversation.id);
      if (!mounted) return;
      setState(() {
        _conversation = conversation;
        _messages = messages;
        _loading = false;
      });
      unawaited(_repository.markRead(conversation.id));
      await _connectRealtime(conversation.id);
      _scrollToLatest();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _connectRealtime(String threadId) async {
    try {
      await DriverRealtimeService.instance.connect();
      if (!mounted) return;
      DriverRealtimeService.instance
        ..listen('fleet-chat:message', _handleRealtimeMessage)
        ..joinFleetChat(threadId);
      setState(() => _realtimeError = null);
    } catch (error) {
      if (!mounted) return;
      setState(() => _realtimeError = error.toString());
    }
  }

  void _handleRealtimeMessage(dynamic payload) {
    if (payload is! Map) return;
    final data = payload['data'];
    final rawMessage = data is Map ? data['message'] : null;
    if (rawMessage is! Map) return;
    final message = FleetChatMessage.fromMap(
      rawMessage.map((key, value) => MapEntry(key.toString(), value)),
    );
    _appendMessage(message);
  }

  void _appendMessage(FleetChatMessage message) {
    if (!mounted || _messages.any((item) => item.id == message.id)) return;
    setState(() {
      _messages = [..._messages, message]
        ..sort((a, b) {
          final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return left.compareTo(right);
        });
    });
    final conversation = _conversation;
    if (conversation != null &&
        message.senderId != FirebaseAuth.instance.currentUser?.uid) {
      unawaited(_repository.markRead(conversation.id));
    }
    _scrollToLatest();
  }

  Future<void> _deleteMessage(FleetChatMessage message, bool mine) async {
    final conversation = _conversation;
    if (conversation == null) return;
    final copy = DriverCopy.of(context);
    final scope = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(copy.t('Delete for me', 'Supprimer pour moi')),
              onTap: () => Navigator.pop(sheetContext, 'me'),
            ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded),
                title: Text(
                  copy.t('Delete for everyone', 'Supprimer pour tout le monde'),
                ),
                onTap: () => Navigator.pop(sheetContext, 'everyone'),
              ),
          ],
        ),
      ),
    );
    if (scope == null || !mounted) return;
    try {
      await _repository.deleteMessage(
        conversation.id,
        message.id,
        scope: scope,
      );
      await _refreshMessages();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            copy.t(
              'Could not delete this message.',
              'Impossible de supprimer ce message.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _refreshMessages() async {
    final conversation = _conversation;
    if (conversation == null || _loading) return;
    try {
      final messages = await _repository.listMessages(conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  Future<void> _send() async {
    final conversation = _conversation;
    final text = _messageController.text.trim();
    if (conversation == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final message = await _repository.sendMessage(conversation.id, text);
      if (!mounted) return;
      _messageController.clear();
      _appendMessage(message);
      unawaited(SystemSound.play(SystemSoundType.click));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    DriverRealtimeService.instance
      ..stopListening('fleet-chat:message')
      ..leaveFleetChat(_conversation?.id ?? '');
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = DriverCopy.of(context);
    final conversation = _conversation;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: Text(conversation?.displayName ?? copy.chat),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: copy.refreshMessages,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(child: _chatBody(copy, conversation, currentUserId)),
      bottomNavigationBar: const DriverBottomNav(currentIndex: 2),
    );
  }

  Widget _chatBody(
    DriverCopy copy,
    FleetChatConversation? conversation,
    String? currentUserId,
  ) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && conversation == null) {
      return _LoadError(message: _error!, onRetry: _load);
    }
    if (conversation == null) {
      return EmptyState(
        title: copy.t('No fleet chat yet', 'Aucune conversation de flotte'),
        message: copy.fleetChatUnavailable,
        icon: Icons.chat_bubble_outline_rounded,
      );
    }
    final visibleMessages = _messages
        .where((message) => !message.hiddenFor.contains(currentUserId))
        .toList(growable: false);
    return Column(
      children: [
        if (_error != null || _realtimeError != null)
          _StatusBanner(
            message: _error ?? _realtimeError!,
            onRetry: _refreshMessages,
          ),
        Expanded(
          child: visibleMessages.isEmpty
              ? EmptyState(
                  title: copy.startFleetConversation,
                  message: copy.t(
                    'Send a message to your fleet owner.',
                    'Envoyez un message au responsable de votre flotte.',
                  ),
                  icon: Icons.forum_outlined,
                )
              : ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: visibleMessages.length,
                  itemBuilder: (context, index) {
                    final message =
                        visibleMessages[visibleMessages.length - 1 - index];
                    final isMine = message.senderId == currentUserId;
                    return GestureDetector(
                      onLongPress: message.deletedForEveryone
                          ? null
                          : () => _deleteMessage(message, isMine),
                      child: _MessageBubble(message: message, isMine: isMine),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 2000,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: copy.messageFleetOwner,
                      counterText: '',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  tooltip: copy.send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final FleetChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;
    final color = isMine
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final textColor = isMine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final time = message.createdAt;
    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine && message.senderName.isNotEmpty)
              Text(
                message.senderName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor.withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            Text(
              message.deletedForEveryone
                  ? DriverCopy.of(
                      context,
                    ).t('This message was deleted', 'Ce message a été supprimé')
                  : message.text,
              style: TextStyle(
                color: textColor,
                fontStyle: message.deletedForEveryone
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
            if (time != null)
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(DriverCopy.of(context).tryAgain),
          ),
        ],
      ),
    ),
  );
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          TextButton(
            onPressed: onRetry,
            child: Text(DriverCopy.of(context).retry),
          ),
        ],
      ),
    ),
  );
}
