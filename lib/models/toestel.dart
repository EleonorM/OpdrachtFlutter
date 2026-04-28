class Toestel {
  final String id;
  final String naam;
  final String beschrijving;
  final String categorie;
  final double prijs;
  final String beschikbaarheid;
  final String verhuurderEmail;
  final String verhuurderUid;
  final String? fotoUrl;
  final double? latitude;
  final double? longitude;
  final String? adres;

  Toestel({
    required this.id,
    required this.naam,
    required this.beschrijving,
    required this.categorie,
    required this.prijs,
    required this.beschikbaarheid,
    required this.verhuurderEmail,
    required this.verhuurderUid,
    this.fotoUrl,
    this.latitude,
    this.longitude,
    this.adres,
  });

  // Van Firestore naar Dart object
  factory Toestel.fromFirestore(Map<String, dynamic> data, String id) {
    return Toestel(
      id: id,
      naam: data['naam'] ?? '',
      beschrijving: data['beschrijving'] ?? '',
      categorie: data['categorie'] ?? '',
      prijs: (data['prijs'] ?? 0).toDouble(),
      beschikbaarheid: data['beschikbaarheid'] ?? '',
      verhuurderEmail: data['verhuurderEmail'] ?? '',
      verhuurderUid: data['verhuurderUid'] ?? '',
      fotoUrl: data['fotoUrl'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      adres: data['adres'],
    );
  }

  // Van Dart object naar Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'naam': naam,
      'beschrijving': beschrijving,
      'categorie': categorie,
      'prijs': prijs,
      'beschikbaarheid': beschikbaarheid,
      'verhuurderEmail': verhuurderEmail,
      'verhuurderUid': verhuurderUid,
      'fotoUrl': fotoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'adres': adres,
    };
  }
}