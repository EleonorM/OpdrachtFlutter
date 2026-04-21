class Reservering {
  final String id;
  final String toestelId;
  final String toestelNaam;
  final String huurderUid;
  final String huurderEmail;
  final String verhuurderUid;
  final DateTime startDatum;
  final DateTime eindDatum;
  final double totalePrijs;
  final String status;

  Reservering({
    required this.id,
    required this.toestelId,
    required this.toestelNaam,
    required this.huurderUid,
    required this.huurderEmail,
    required this.verhuurderUid,
    required this.startDatum,
    required this.eindDatum,
    required this.totalePrijs,
    required this.status,
  });

  // Van Firestore naar Dart object
  factory Reservering.fromFirestore(Map<String, dynamic> data, String id) {
    return Reservering(
      id: id,
      toestelId: data['toestelId'] ?? '',
      toestelNaam: data['toestelNaam'] ?? '',
      huurderUid: data['huurderUid'] ?? '',
      huurderEmail: data['huurderEmail'] ?? '',
      verhuurderUid: data['verhuurderUid'] ?? '',
      startDatum: DateTime.parse(data['startDatum']),
      eindDatum: DateTime.parse(data['eindDatum']),
      totalePrijs: (data['totalePrijs'] ?? 0).toDouble(),
      status: data['status'] ?? 'In afwachting',
    );
  }

  // Van Dart object naar Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'toestelId': toestelId,
      'toestelNaam': toestelNaam,
      'huurderUid': huurderUid,
      'huurderEmail': huurderEmail,
      'verhuurderUid': verhuurderUid,
      'startDatum': startDatum.toIso8601String(),
      'eindDatum': eindDatum.toIso8601String(),
      'totalePrijs': totalePrijs,
      'status': status,
    };
  }

  // Aantal huurdagen berekenen
  int get aantalDagen => eindDatum.difference(startDatum).inDays;
}