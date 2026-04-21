import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:verhuurapp/models/toestel.dart';

class ToestelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectie = 'toestellen';

  // Toestel toevoegen
  Future<void> toestelToevoegen(Toestel toestel) async {
    await _firestore.collection(_collectie).add(toestel.toFirestore());
  }

  // Alle toestellen ophalen
  Stream<List<Toestel>> getAlleToestellen() {
    return _firestore
        .collection(_collectie)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Toestel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Toestellen per categorie ophalen
  Stream<List<Toestel>> getToestellenPerCategorie(String categorie) {
    return _firestore
        .collection(_collectie)
        .where('categorie', isEqualTo: categorie)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Toestel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Toestellen van een specifieke verhuurder ophalen
  Stream<List<Toestel>> getMijnToestellen(String uid) {
    return _firestore
        .collection(_collectie)
        .where('verhuurderUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Toestel.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Toestel verwijderen
  Future<void> toestelVerwijderen(String id) async {
    await _firestore.collection(_collectie).doc(id).delete();
  }

  // Toestel updaten
  Future<void> toestelUpdaten(String id, Map<String, dynamic> data) async {
    await _firestore.collection(_collectie).doc(id).update(data);
  }
}