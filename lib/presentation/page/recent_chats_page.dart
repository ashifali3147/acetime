import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../model/chat_model.dart';
import '../../model/user_model.dart';
import '../navigation/route_names.dart';

class RecentChatsPage extends StatelessWidget {
  const RecentChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('users', arrayContains: currentUser.uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final chats = snapshot.data!.docs
            .map((doc) => ChatModel.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList();

        if (chats.isEmpty) return const Center(child: Text("No chats yet"));

        return ListView.builder(
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final otherUserId = chat.users.firstWhere((uid) => uid != currentUser.uid);

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const SizedBox();
                final userDoc = userSnapshot.data!;
                final userData = userDoc.data() as Map<String, dynamic>?; // safe cast
                if (userData == null) return const SizedBox();

                final otherUser = UserModel.fromMap(userDoc.id, userData);

                // WhatsApp-style info
                final unreadCount = chat.unreadCounts?[currentUser.uid] ?? 0;
                final isLastMessageByMe = chat.lastMessageSenderId == currentUser.uid;

                print("[ChatData] - UnreadCount ${unreadCount}");
                print("[ChatData] - isLastMessageByMe ${isLastMessageByMe}");
                print("[ChatData] - LastSender ${chat.lastMessageSenderId}");
                print("[ChatData] - ME ${currentUser.uid}");

                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(otherUser.userName ?? "Unknown"),
                  subtitle: Row(
                    children: [
                      if (isLastMessageByMe)
                        Icon(
                          chat.lastMessageSeen ? Icons.done_all : Icons.done,
                          size: 16,
                          color: chat.lastMessageSeen ? Colors.blue : Colors.grey,
                        ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isLastMessageByMe
                              ? "You: ${chat.lastMessage}"
                              : "${otherUser.userName}: ${chat.lastMessage}",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  trailing: unreadCount > 0
                      ? CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.green,
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                      : null,
                  onTap: () {
                    context.pushNamed(
                      RouteNames.chat,
                      extra: otherUser,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
