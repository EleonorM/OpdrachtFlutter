import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:verhuurapp/models/reservering.dart';

class ReserveringService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectie = 'reserveringen';

  // Reservering toevoegen
  Future<void> reserveringToevoegen(Reservering reservering) async {
    await _firestore.collection(_collectie).add(reservering.toFirestore());
  }

  // Reserveringen van een huurder ophalen
  Stream<List<Reservering>> getMijnReserveringen(String uid) {
    return _firestore
        .collection(_collectie)
        .where('huurderUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Reservering.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Reserveringen voor een verhuurder ophalen
  Stream<List<Reservering>> getReserveringenVoorVerhuurder(String uid) {
    return _firestore
        .collection(_collectie)
        .where('verhuurderUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Reservering.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  // Status van reservering updaten
  Future<void> statusUpdaten(String id, String status) async {
    await _firestore
        .collection(_collectie)
        .doc(id)
        .update({'status': status});
  }

  // Reservering annuleren
  Future<void> reserveringAnnuleren(String id) async {
    await _firestore
        .collection(_collectie)
        .doc(id)
        .update({'status': 'Geannuleerd'});
  }

  // Actieve reserveringen voor een toestel ophalen (voor datumblokkering)
  Future<List<Reservering>> getActieveReserveringenVoorToestel(String toestelId) async {
    final snapshot = await _firestore
        .collection(_collectie)
        .where('toestelId', isEqualTo: toestelId)
        .where('status', whereIn: ['In afwachting', 'Goedgekeurd'])
        .get();
    return snapshot.docs
        .map((doc) => Reservering.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  // Controleer of er nog actieve reserveringen zijn voor een toestel
  Future<bool> heeftActieveReserveringen(String toestelId) async {
    final reserveringen = await getActieveReserveringenVoorToestel(toestelId);
    return reserveringen.isNotEmpty;
  }
}