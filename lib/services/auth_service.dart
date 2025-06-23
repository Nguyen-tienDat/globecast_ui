// lib/services/auth_service.dart - FIXED WITH MISSING METHODS
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  bool _isLoading = false;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get userId => _user?.uid;
  String? get userEmail => _user?.email;
  String? get displayName => _user?.displayName;

  // 🎯 ADDED: Check if user is logged in
  bool get isLoggedIn {
    try {
      // Check if Firebase user exists and is authenticated
      final user = _auth.currentUser;
      return user != null && !user.isAnonymous;
    } catch (e) {
      print('Error checking login state: $e');
      return false;
    }
  }

  // 🎯 ADDED: Get current user info
  Map<String, String>? get currentUserInfo {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return {
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? 'User',
          'photoURL': user.photoURL ?? '',
        };
      }
      return null;
    } catch (e) {
      print('Error getting user info: $e');
      return null;
    }
  }

  AuthService() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      print('🔐 Auth state changed: ${user != null ? "Logged in (${user.email})" : "Logged out"}');
      notifyListeners();
    });

    // Initialize current user
    _user = _auth.currentUser;
    if (_user != null) {
      print('🔐 Auth service initialized with user: ${_user!.email}');
    } else {
      print('🔐 Auth service initialized - no user logged in');
    }
  }

  // Sign up with email and password
  Future<User?> signUpWithEmailAndPassword(
      String email,
      String password,
      String displayName,
      ) async {
    try {
      _setLoading(true);
      print('📝 Attempting sign up for: $email');

      // Create user account
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;

      if (user != null) {
        // Update display name
        await user.updateDisplayName(displayName);
        await user.reload();
        _user = _auth.currentUser;

        // Create user profile in Firestore
        await _createUserProfile(user, displayName);

        print('✅ Sign up successful for: $email');
        notifyListeners();
        return user;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      print('❌ Sign up error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Sign up failed: $e');
      throw Exception('Sign up failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      _setLoading(true);
      print('🔑 Attempting sign in for: $email');

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;

      if (user != null) {
        _user = user;

        // Update last login time
        await _updateUserLastLogin(user.uid);

        print('✅ Sign in successful for: $email');
        notifyListeners();
        return user;
      }

      return null;
    } on FirebaseAuthException catch (e) {
      print('❌ Sign in error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Sign in failed: $e');
      throw Exception('Sign in failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // 🎯 ENHANCED: Sign out with better logging
  Future<void> signOut() async {
    try {
      _setLoading(true);
      final userEmail = _user?.email;

      await _auth.signOut();
      _user = null;

      print('👋 Sign out successful for: $userEmail');
      notifyListeners();
    } catch (e) {
      print('❌ Sign out error: $e');
      throw Exception('Sign out failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // 🎯 ADDED: Logout alias for consistency
  Future<void> logout() async {
    await signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      _setLoading(true);
      print('📧 Sending password reset email to: $email');

      await _auth.sendPasswordResetEmail(email: email);

      print('✅ Password reset email sent to: $email');
    } on FirebaseAuthException catch (e) {
      print('❌ Password reset error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Password reset failed: $e');
      throw Exception('Password reset failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      if (_user == null) throw Exception('No user signed in');

      _setLoading(true);
      print('👤 Updating profile for: ${_user!.email}');

      if (displayName != null) {
        await _user!.updateDisplayName(displayName);
      }

      if (photoURL != null) {
        await _user!.updatePhotoURL(photoURL);
      }

      await _user!.reload();
      _user = _auth.currentUser;

      // Update Firestore profile
      await _firestore.collection('users').doc(_user!.uid).update({
        if (displayName != null) 'displayName': displayName,
        if (photoURL != null) 'photoURL': photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Profile updated successfully');
      notifyListeners();
    } catch (e) {
      print('❌ Profile update failed: $e');
      throw Exception('Profile update failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Delete user account
  Future<void> deleteAccount() async {
    try {
      if (_user == null) throw Exception('No user signed in');

      _setLoading(true);
      final String uid = _user!.uid;
      final String email = _user!.email ?? 'unknown';

      print('🗑️ Deleting account for: $email');

      // Delete user data from Firestore
      await _deleteUserData(uid);

      // Delete the user account
      await _user!.delete();

      _user = null;
      print('✅ Account deleted successfully for: $email');
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      print('❌ Account deletion error: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      print('❌ Account deletion failed: $e');
      throw Exception('Account deletion failed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Create user profile in Firestore
  Future<void> _createUserProfile(User user, String displayName) async {
    try {
      print('📄 Creating user profile in Firestore...');

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName,
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'preferences': {
          'speakingLanguage': 'vi', // Default Vietnamese
          'displayLanguage': 'en',  // Default English
          'notificationsEnabled': true,
          'theme': 'dark',
        },
      });

      print('✅ User profile created in Firestore');
    } catch (e) {
      print('⚠️ Error creating user profile: $e');
      // Don't throw here as user creation was successful
    }
  }

  // Update user last login time
  Future<void> _updateUserLastLogin(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
      print('✅ Last login time updated');
    } catch (e) {
      print('⚠️ Error updating last login: $e');
      // Don't throw here as sign in was successful
    }
  }

  // Delete user data from Firestore
  Future<void> _deleteUserData(String uid) async {
    try {
      print('🗑️ Deleting user data from Firestore...');

      final batch = _firestore.batch();

      // Delete user profile
      batch.delete(_firestore.collection('users').doc(uid));

      // Delete user meetings (where user is host)
      final userMeetings = await _firestore
          .collection('meetings')
          .where('hostId', isEqualTo: uid)
          .get();

      for (var doc in userMeetings.docs) {
        batch.delete(doc.reference);
      }

      // Remove user from user_meetings collection
      final userMeetingDocs = await _firestore
          .collection('user_meetings')
          .where('userId', isEqualTo: uid)
          .get();

      for (var doc in userMeetingDocs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✅ User data deleted from Firestore');
    } catch (e) {
      print('⚠️ Error deleting user data: $e');
      // Continue with account deletion even if this fails
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'user-not-found':
        return 'No user found for this email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign in again.';
      case 'invalid-credential':
        return 'The provided credentials are invalid or expired.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Get user profile from Firestore
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (_user == null) return null;

      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }

  // Update user preferences
  Future<void> updateUserPreferences(Map<String, dynamic> preferences) async {
    try {
      if (_user == null) throw Exception('No user signed in');

      await _firestore.collection('users').doc(_user!.uid).update({
        'preferences': preferences,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ User preferences updated');
    } catch (e) {
      print('❌ Failed to update preferences: $e');
      throw Exception('Failed to update preferences: ${e.toString()}');
    }
  }

  // 🎯 ADDED: Check if user email is verified
  bool get isEmailVerified {
    return _user?.emailVerified ?? false;
  }

  // 🎯 ADDED: Send email verification
  Future<void> sendEmailVerification() async {
    try {
      if (_user == null) throw Exception('No user signed in');

      await _user!.sendEmailVerification();
      print('✅ Email verification sent');
    } catch (e) {
      print('❌ Error sending email verification: $e');
      throw Exception('Failed to send email verification: ${e.toString()}');
    }
  }

  // 🎯 ADDED: Reload user data
  Future<void> reloadUser() async {
    try {
      if (_user != null) {
        await _user!.reload();
        _user = _auth.currentUser;
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error reloading user: $e');
    }
  }

  @override
  void dispose() {
    print('🧹 Disposing AuthService...');
    super.dispose();
  }
}