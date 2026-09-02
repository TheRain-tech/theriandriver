import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Driver-side view of the server-created, ride-scoped chat.
class RideChatScreen extends StatefulWidget {
  const RideChatScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final _composer = TextEditingController();
  bool _sending = false;

  DocumentReference<Map<String, dynamic>> get _chat =>
      FirebaseFirestore.instance.collection('ride_chats').doc(widget.rideId);

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
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
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message ?? 'Message could not be sent.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Chat with Rider')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _chat.snapshots(),
      builder: (context, chatSnapshot) {
        if (chatSnapshot.hasError) {
          return const _ChatNotice(
            'This chat is unavailable for your account.',
          );
        }
        if (!chatSnapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        if (!chatSnapshot.data!.exists) {
          return const _ChatNotice('Chat is being prepared. Please try again.');
        }
        return Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _chat
                    .collection('messages')
                    .orderBy('createdAt', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, messagesSnapshot) {
                  if (messagesSnapshot.hasError) {
                    return const _ChatNotice('Messages could not be loaded.');
                  }
                  if (!messagesSnapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final messages = messagesSnapshot.data!.docs;
                  if (messages.isEmpty) {
                    return const _ChatNotice('You can now message this rider.');
                  }
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final data = messages[index].data();
                      final mine = data['senderId']?.toString() == uid;
                      final sentAt = data['createdAt'] as Timestamp?;
                      final time = sentAt?.toDate();
                      final timeLabel = time == null
                          ? 'Sending…'
                          : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 300),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                          decoration: BoxDecoration(
                            color: mine
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['text']?.toString() ?? '',
                                style: TextStyle(
                                  color: mine
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                timeLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: mine
                                      ? Theme.of(context).colorScheme.onPrimary
                                            .withValues(alpha: .75)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
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
                        decoration: const InputDecoration(
                          hintText: 'Type a message',
                          counterText: '',
                          border: OutlineInputBorder(),
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
