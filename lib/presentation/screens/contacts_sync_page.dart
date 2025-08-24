import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contacts_sync_provider.dart';

class ContactsSyncPage extends StatefulWidget {
  const ContactsSyncPage({super.key});

  @override
  State<ContactsSyncPage> createState() => _ContactsSyncPageState();
}

class _ContactsSyncPageState extends State<ContactsSyncPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final viewModel = Provider.of<ContactSyncProvider>(context, listen: false);
      viewModel.fetchCacheContacts();
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Contacts"),
      ),
      body: Consumer<ContactSyncProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(child: Text(provider.error!));
          }

          if (provider.contacts.isEmpty) {
            return const Center(child: Text("No contacts found"));
          }

          return RefreshIndicator(
            onRefresh: () async => provider.fetchContacts(),
            child: ListView.builder(
              itemCount: provider.contacts.length,
              itemBuilder: (context, index) {
                final user = provider.contacts[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(user.userName ?? "Unknown"),
                  subtitle: Text(user.phone ?? ""),
                  trailing: IconButton(
                    icon: const Icon(Icons.chat),
                    onPressed: () {
                      // TODO: start chat with this user
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.read<ContactSyncProvider>().fetchContacts(),
        child: const Icon(Icons.sync),
      ),
    );
  }
}

