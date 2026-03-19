import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contacts_service_plus/contacts_service_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../model/user_model.dart';
import '../service/firestore_service.dart';

class ContactSyncProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  List<UserModel> _contacts = [];
  bool _isLoading = false;
  String? _error;

  List<UserModel> get contacts => _contacts;

  bool get isLoading => _isLoading;

  String? get error => _error;

  Future<bool> _ensureContactsPermission() async {
    var status = await Permission.contacts.status;

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isRestricted) {
      _error =
          "Contacts permission is restricted on this device. Check Screen Time or device restrictions.";
      return false;
    }

    if (status.isPermanentlyDenied) {
      _error =
          "Contacts permission is permanently denied. Enable it from iPhone Settings > Acetime > Contacts.";
      return false;
    }

    status = await Permission.contacts.request();

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      _error =
          "Contacts permission is permanently denied. Enable it from iPhone Settings > Acetime > Contacts.";
      return false;
    }

    if (status.isRestricted) {
      _error =
          "Contacts permission is restricted on this device. Check Screen Time or device restrictions.";
      return false;
    }

    _error = "Contacts permission denied";
    return false;
  }

  Future<void> fetchCacheContacts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // 1️⃣ Load cached contacts first
      _contacts = await _firestoreService.getUserContacts();
      notifyListeners();
    } catch (e) {
      _error = "Failed to fetch contacts: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Main entry point: load cached + sync
  Future<void> fetchContacts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1️⃣ Load cached contacts first
      _contacts = await _firestoreService.getUserContacts();
      notifyListeners();

      // 2️⃣ Request device contact permission
      final hasPermission = await _ensureContactsPermission();
      if (!hasPermission) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      // 3️⃣ Get device contacts
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

      // 4️⃣ Fetch all app users from Firestore
      final snapshot = await _firestore.collection('users').get();
      final availableContacts = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .where(
            (user) =>
                user.phone != null &&
                phoneNumbers.contains(
                  user.phone!.replaceAll(RegExp(r'\D'), ""),
                ),
          )
          .toList();

      // 5️⃣ Update Firestore cache
      await _firestoreService.syncContactsToFirestore(availableContacts);

      // 6️⃣ Update provider state
      _contacts = availableContacts;
    } catch (e) {
      _error = "Failed to fetch contacts: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
