import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
class ChatService extends ChangeNotifier{
  /// get instance of auth and firestore
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
}