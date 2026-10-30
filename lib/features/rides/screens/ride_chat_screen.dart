import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/firebase_config.dart';
import '../../../core/localization/driver_copy.dart';

/// Driver-side view of the server-created, ride-scoped chat.
class RideChatScreen extends StatefulWidget {
  const RideChatScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final _composer = TextEditingController();
  final _functions = FirebaseFunctions.instanceFor(
    region: FirebaseConfig.functionsRegion,
  );
  bool _sending = false;

  // All three created once (not fetched fresh inside build()): build() reruns on every _sending
  // toggle (i.e. every time a message is sent) and _chatStream's own emissions (e.g. the other
  // party's read receipt updating the parent doc) drove the nested messages StreamBuilder too -
  // each fresh Stream object made StreamBuilder tear down and resubscribe, flashing the whole
  // chat back to its loading spinner on nearly every message sent or read on either side.
  late final DocumentReference<Map<String, dynamic>> _chat = FirebaseFirestore
      .instance
      .collection('ride_chats')
      .doc(widget.rideId);
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _chatStream =
      _chat.snapshots();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messagesStream =
      _chat
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(includeMetadataChanges: true);

  @override
  void initState() {
    super.initState();
    // Opening the chat is the only thing that should ever clear its own unread count - the
    // parent doc is "allow update, delete: if false" in firestore.rules (every client write to
    // it or its messages is create-only, by deliberate design), so this goes through the
    // markRideChatRead callable (Admin SDK) rather than a direct Firestore write, which the
    // rules would refuse anyway.
    _markRead();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    try {
      await _functions.httpsCallable('markRideChatRead').call<dynamic>({
        'rideId': widget.rideId,
      });
    } catch (_) {
      // Best-effort - an unread badge staying on one message longer than it should is a much
      // smaller problem than blocking the chat screen itself over this.
    }
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (text.isEmpty || uid == null || _sending) return;
    setState(() => _sending = true);
    try {
      await _chat.collection('messages').add({
        'senderId': uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _composer.clear();
      unawaited(SystemSound.play(SystemSoundType.click));
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message ??
                  DriverCopy.current.t(
                    'Message could not be sent.',
                    "Le message n'a pas pu être envoyé.",
                  ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteMessage({
    required String messageId,
    required bool mine,
  }) async {
    final l = DriverCopy.current;
    final scope = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(l.t('Delete for me', 'Supprimer pour moi')),
              onTap: () => Navigator.pop(sheetContext, 'me'),
            ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_forever_rounded),
                title: Text(
                  l.t('Delete for everyone', 'Supprimer pour tout le monde'),
                ),
                onTap: () => Navigator.pop(sheetContext, 'everyone'),
              ),
          ],
        ),
      ),
    );
    if (scope == null || !mounted) return;
    try {
      await _functions.httpsCallable('deleteRideChatMessage').call<dynamic>({
        'rideId': widget.rideId,
        'messageId': messageId,
        'scope': scope,
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.t(
              'Could not delete this message.',
              "Impossible de supprimer ce message.",
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = DriverCopy.of(context);
    return Scaffold(
    appBar: AppBar(title: Text(l.t('Chat with Rider', 'Discuter avec le passager'))),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _chatStream,
      builder: (context, chatSnapshot) {
        if (chatSnapshot.hasError) {
          return _ChatNotice(
            l.t(
              'This chat is unavailable for your account.',
              'Cette discussion n\'est pas disponible pour votre compte.',
            ),
          );
        }
        if (!chatSnapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        if (!chatSnapshot.data!.exists) {
          return _ChatNotice(
            l.t(
              'Chat is being prepared. Please try again.',
              'La discussion est en cours de préparation. Veuillez réessayer.',
            ),
          );
        }
        final chatData = chatSnapshot.data!.data() ?? const {};
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        // The other participant's own last-read timestamp, written by their own
        // markRideChatRead call - used below to show a read (vs. merely sent) tick on my own
        // messages. Never written by me; reading my own write back here would say nothing about
        // whether they have actually seen it.
        final otherUid = chatData['riderAuthUid']?.toString() == currentUid
            ? chatData['driverId']?.toString()
            : chatData['riderAuthUid']?.toString();
        final lastReadAtRaw = chatData['lastReadAt'];
        final otherLastReadAt =
            (lastReadAtRaw is Map && otherUid != null
                    ? lastReadAtRaw[otherUid]
                    : null)
                as Timestamp?;
        return Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, messagesSnapshot) {
                  if (messagesSnapshot.hasError) {
                    return _ChatNotice(
                      l.t(
                        'Messages could not be loaded.',
                        'Les messages n\'ont pas pu être chargés.',
                      ),
                    );
                  }
                  if (!messagesSnapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final messages = messagesSnapshot.data!.docs.where((doc) {
                    final hiddenFor = doc.data()['hiddenFor'];
                    return hiddenFor is! List || !hiddenFor.contains(currentUid);
                  }).toList();
                  if (messages.isEmpty) {
                    return _ChatNotice(
                      l.t(
                        'You can now message this rider.',
                        'Vous pouvez maintenant envoyer un message à ce passager.',
                      ),
                    );
                  }
                  // A message that just arrived from the other party while this screen is
                  // already open (initState's own _markRead only fires once, on mount) should
                  // still clear the badge live rather than leaving it stuck at 1 until the
                  // driver leaves and reopens the screen.
                  final newestIsIncoming =
                      messages.first.data()['senderId']?.toString() !=
                      currentUid;
                  if (newestIsIncoming &&
                      messagesSnapshot.data!.metadata.isFromCache == false) {
                    _markRead();
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final doc = messages[index];
                      final data = doc.data();
                      final mine = data['senderId']?.toString() == currentUid;
                      final createdAt = data['createdAt'] as Timestamp?;
                      final deleted = data['deletedForEveryone'] == true;
                      return GestureDetector(
                        onLongPress: deleted
                            ? null
                            : () => _deleteMessage(
                                messageId: doc.id,
                                mine: mine,
                              ),
                        child: _MessageBubble(
                          text: data['text']?.toString() ?? '',
                          mine: mine,
                          timestamp: createdAt,
                          sendingLabel: l.t('Sending…', 'Envoi en cours…'),
                          deletedLabel: l.t(
                            'This message was deleted',
                            'Ce message a été supprimé',
                          ),
                          deleted: deleted,
                          // A message I just sent reads back with hasPendingWrites true until
                          // Firestore confirms the server actually has it - the one real "sent"
                          // vs "still sending" signal available without a second field.
                          pending: mine && doc.metadata.hasPendingWrites,
                          read: mine &&
                              createdAt != null &&
                              otherLastReadAt != null &&
                              !otherLastReadAt.toDate().isBefore(
                                createdAt.toDate(),
                              ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _composer,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: l.t('Type a message', 'Écrivez un message'),
                          counterText: '',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
  }
}

class _ChatNotice extends StatelessWidget {
  const _ChatNotice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.mine,
    required this.timestamp,
    required this.sendingLabel,
    required this.deletedLabel,
    this.pending = false,
    this.read = false,
    this.deleted = false,
  });

  final String text;
  final bool mine;
  final Timestamp? timestamp;
  final String sendingLabel;
  final String deletedLabel;
  // True while this message exists only in the local Firestore cache, not yet confirmed by the
  // server (doc.metadata.hasPendingWrites) - shown as a single tick, same convention as WhatsApp/
  // most chat apps use for "sent, not yet confirmed".
  final bool pending;
  // True once the other participant's own lastReadAt (written by their markRideChatRead call) is
  // at or after this message's createdAt - shown as a double tick.
  final bool read;
  // True once the sender has deleted this message for everyone (deleteRideChatMessage) - the
  // record and its real timestamp stay, only the text is replaced, matching every participant's
  // conversation seeing the same deleted placeholder in real time.
  final bool deleted;

  @override
  Widget build(BuildContext context) {
    final time = timestamp?.toDate();
    final timeLabel = time == null
        ? sendingLabel
        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final colors = Theme.of(context).colorScheme;
    final tickColor = mine
        ? (read ? Colors.lightBlueAccent : colors.onPrimary.withValues(alpha: .75))
        : colors.onSurfaceVariant;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? colors.primary : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              deleted ? deletedLabel : text,
              style: TextStyle(
                color: mine ? colors.onPrimary : colors.onSurface,
                fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: mine
                        ? colors.onPrimary.withValues(alpha: .75)
                        : colors.onSurfaceVariant,
                  ),
                ),
                if (mine && !pending) ...[
                  const SizedBox(width: 4),
                  Icon(
                    read ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 14,
                    color: tickColor,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
