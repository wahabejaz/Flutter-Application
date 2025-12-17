import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import 'db/sqlite_service.dart';

/// Authentication Service
/// Handles user authentication with Firebase Auth and Google Sign In
class AuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final SQLiteService dbService = SQLiteService();

  /// Get current user
  firebase_auth.User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<firebase_auth.User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password
  Future<firebase_auth.UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Save user data to local database
    await _saveUserToLocalDatabase(userCredential.user);

    return userCredential;
  }

  /// Sign up with email and password
  Future<firebase_auth.UserCredential> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Save user data to local database
    await _saveUserToLocalDatabase(userCredential.user);

    return userCredential;
  }

  /// Sign in with Google
  Future<firebase_auth.UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Save user data to local database
      await _saveUserToLocalDatabase(userCredential.user);

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Save user data to local SQLite database
  Future<void> _saveUserToLocalDatabase(firebase_auth.User? firebaseUser) async {
    if (firebaseUser == null) return;

    final db = await dbService.database;

    final user = User(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      fullName: firebaseUser.displayName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Insert or update user data
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get user data from local database
  Future<User?> getUserFromLocalDatabase(String uid) async {
    final db = await dbService.database;
    final maps = await db.query(
      'users',
      where: 'uid = ?',
      whereArgs: [uid],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }
}