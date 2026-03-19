import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../model/user_model.dart';
import '../../providers/chat_provider.dart';
import '../../service/call_service.dart';
import '../../service/meeting_service.dart';
import '../../service/notification_service.dart';
import '../../utils/storage_helper.dart';
import 'outgoing_call_screen.dart';
import '../../utils/utils.dart';

class ChatScreen extends StatefulWidget {
  final UserModel receiver;

  const ChatScreen({super.key, required this.receiver});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late String chatId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final currentUser = FirebaseAuth.instance.currentUser!;
      chatId = context.read<ChatProvider>().getChatId(
        currentUser.uid,
        widget.receiver.uid,
      );
      context.read<ChatProvider>().listenMessages(chatId);
      context.read<ChatProvider>().markMessagesAsSeen(chatId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiver.userName ?? 'Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () async {
              {
                final meetingId = await MeetingService.createMeeting(
                  hostName: StorageHelper().getUserName(),
                  hostEmail: "test@gmail.com",
                  onError: (err) {
                    Utils.showSnackBar(context, message: err);
                  },
                );

                if (meetingId != null && context.mounted) {
                  final senderModel = FirebaseAuth.instance.currentUser == null
                      ? null
                      : UserModel(
                          uid: FirebaseAuth.instance.currentUser!.uid,
                          phone: FirebaseAuth.instance.currentUser!.phoneNumber,
                          userName: Utils.getSenderName(),
                          fcmToken: StorageHelper().getFCMToken(),
                          voipToken: StorageHelper().getVoipToken().isEmpty
                              ? null
                              : StorageHelper().getVoipToken(),
                        );
                  if (senderModel == null) return;

                  await CallService().createOutgoingCall(
                    callId: meetingId,
                    caller: senderModel,
                    receiver: widget.receiver,
                  );

                  NotificationService().sendPushNotification(
                    deviceToken: widget.receiver.fcmToken ?? "",
                    title: senderModel.userName ?? 'Call',
                    body: "Incoming call",
                    data: {
                      'type': 'incoming_call',
                      'callId': meetingId,
                      'sender': jsonEncode(senderModel.toJson()),
                      'callerId': senderModel.uid,
                      'receiverId': widget.receiver.uid,
                      'callTimestamp': DateTime.now().toUtc().toIso8601String(),
                    },
                  );

                  if (!context.mounted) return;
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OutgoingCallScreen(
                        callId: meetingId,
                        receiver: widget.receiver,
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true,
                    itemCount: provider.messages.length,
                    itemBuilder: (context, index) {
                      final msg = provider.messages[index];
                      final isMe = msg['senderId'] == currentUser.uid;

                      return Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  msg['text'],
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              if (isMe)
                                Icon(
                                  msg['seen'] ? Icons.done_all : Icons.done,
                                  size: 16,
                                  color: msg['seen']
                                      ? Colors.lightGreenAccent
                                      : Colors.white70,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Type a message",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    if (_controller.text.trim().isEmpty) return;
                    provider.sendMessage(
                      chatId,
                      widget.receiver,
                      _controller.text.trim(),
                    );
                    _controller.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
