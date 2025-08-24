import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
            // You need to fetch otherUser data (name, phone) from users collection
            return FutureBuilder(
              future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return const SizedBox();
                final userDoc = userSnapshot.data!;
                final otherUser = UserModel.fromMap(userDoc.id, userDoc.data()!);
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(otherUser.userName ?? "Unknown"),
                  subtitle: Text(chat.lastMessage),
                  trailing: Text(
                    chat.lastMessageTime.toDate().hour.toString().padLeft(2, '0') +
                        ":" +
                        chat.lastMessageTime.toDate().minute.toString().padLeft(2, '0'),
                  ),
                  onTap: () {
                    context.pushNamed(
                      RouteNames.chat,
                      extra: otherUser, // pass the full UserModel
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
