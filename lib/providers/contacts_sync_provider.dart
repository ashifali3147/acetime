import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/user_model.dart';

class ContactSyncProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<UserModel> _contacts = [];
  bool _isLoading = false;
  String? _error;

  List<UserModel> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch all users (you can later filter by phone contacts if needed)
  Future<void> fetchContacts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _firestore.collection('users').get();

      _contacts = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.id, doc.data()))
          .toList();

    } catch (e) {
      _error = "Failed to fetch contacts: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
