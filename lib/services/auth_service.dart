import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import 'fcm_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Sign in with email & password
  Future<UserCredential> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    // Refresh FCM token now that user is signed in
    await FcmService().refreshTokenForCurrentUser();
    return cred;
  }

  /// Register with email & password, then create Firestore profile
  Future<UserProfile> register({
    required String email,
    required String password,
    required String displayName,
    UserType userType = UserType.general,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user!.updateDisplayName(displayName);

    final profile = UserProfile(
      uid: cred.user!.uid,
      email: email.trim(),
      displayName: displayName,
      userType: userType,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(profile.uid)
        .set(profile.toJson());

    return profile;
  }

  /// Send password reset email
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Fetch user profile from Firestore
  Future<UserProfile?> fetchUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromJson(doc.data()!);
  }

  /// Update user profile in Firestore
  Future<void> updateUserProfile(UserProfile profile) async {
    await _firestore
        .collection('users')
        .doc(profile.uid)
        .set(profile.toJson(), SetOptions(merge: true));
  }
}
