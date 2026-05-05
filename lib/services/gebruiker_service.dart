import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:verhuurapp/models/gebruiker.dart';

class GebruikerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectie = 'gebruikers';

  // Gebruikersprofiel opslaan (bij registratie)
  Future<void> profielOpslaan(Gebruiker gebruiker) async {
    await _firestore
        .collection(_collectie)
        .doc(gebruiker.uid)
        .set(gebruiker.toFirestore(), SetOptions(merge: true));
  }

  // Gebruikersprofiel ophalen
  Future<Gebruiker?> getProfiel(String uid) async {
    final doc = await _firestore.collection(_collectie).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return Gebruiker.fromFirestore(doc.data()!, uid);
  }

  // Profiel bijwerken
  Future<void> profielUpdaten(String uid, Map<String, dynamic> data) async {
    await _firestore.collection(_collectie).doc(uid).update(data);
  }
}
