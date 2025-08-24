import 'package:contacts_service_plus/contacts_service_plus.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/user_model.dart';

class ContactSyncProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<UserModel> _contacts = [];
  bool _isLoading = false;
  String? _error;

  List<UserModel> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch contacts only if permission is granted
  Future<void> fetchContacts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Request permission
      var status = await Permission.contacts.status;
      if (status.isDenied || status.isRestricted) {
        status = await Permission.contacts.request();
      }

      if (!status.isGranted) {
        _error = "Contact permission denied";
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 2. Get phone contacts
      Iterable<Contact> phoneContacts = await ContactsService.getContacts();
      final phoneNumbers = phoneContacts
          .expand((c) => c.phones ?? [])
          .map((p) => p.value?.replaceAll(RegExp(r'\D'), "")) // normalize
          .whereType<String>()
          .toSet();

      if (phoneNumbers.isEmpty) {
        _error = "No phone contacts found";
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 3. Fetch users from Firestore
      final snapshot = await _firestore.collection('users').get();

      _contacts = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .where((user) =>
      user.phone != null &&
          phoneNumbers.contains(user.phone!.replaceAll(RegExp(r'\D'), "")))
          .toList();

    } catch (e) {
      _error = "Failed to fetch contacts: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
