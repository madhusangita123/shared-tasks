import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_tasks/app.dart';
import 'package:shared_tasks/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Firestore already enables offline persistence by default on mobile
  // (iOS/Android) — this line changes nothing at runtime. It's here purely
  // to make that fact explicit and traceable to issue #11 (US-08), which
  // calls out persistence as part of its acceptance criteria.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  runApp(const ProviderScope(child: App()));
}
