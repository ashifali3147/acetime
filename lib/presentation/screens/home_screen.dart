import 'package:acetime/presentation/navigation/route_names.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../style/app_color.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ChatListPage(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        title: Text(
          _selectedIndex == 0 ? "Chats" : "Profile",
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: _pages[_selectedIndex],
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
        onPressed: () {
          context.pushNamed(RouteNames.contactSync);
        },
        backgroundColor: AppColors.themeColor,
        child: const Icon(Icons.message, color: Colors.white),
      )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: AppColors.backgroundColor,
        selectedItemColor: AppColors.themeColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: "Chats",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

/// Chat List Page (placeholder for now)
class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: 10,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.grey,
            child: Icon(Icons.person, color: Colors.white),
          ),
          title: Text("Chat $index",
              style: const TextStyle(color: Colors.white)),
          subtitle: const Text("Last message...",
              style: TextStyle(color: Colors.grey)),
          onTap: () {
            // TODO: Navigate to ChatScreen
          },
        );
      },
    );
  }
}

/// Profile Page (placeholder for now)
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Profile Page",
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }
}
