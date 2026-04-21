import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Huidige gebruiker ophalen
  User? get currentUser => _auth.currentUser;

  // Stream om loginstate bij te houden
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Registreren met email en wachtwoord
  Future<User?> register(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e.code);
    }
  }

  // Inloggen met email en wachtwoord
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e.code);
    }
  }

  // Uitloggen
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Foutmeldingen in het Nederlands
  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Dit e-mailadres is al in gebruik.';
      case 'invalid-email':
        return 'Ongeldig e-mailadres.';
      case 'weak-password':
        return 'Wachtwoord moet minstens 6 tekens bevatten.';
      case 'user-not-found':
        return 'Geen account gevonden met dit e-mailadres.';
      case 'wrong-password':
        return 'Ongeldig wachtwoord.';
      default:
        return 'Er is een fout opgetreden. Probeer opnieuw.';
    }
  }
}