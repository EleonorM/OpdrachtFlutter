class Gebruiker {
  final String uid;
  final String email;
  final String? adres;
  final String? stad;
  final String? postnummer;
  final double? latitude;
  final double? longitude;

  Gebruiker({
    required this.uid,
    required this.email,
    this.adres,
    this.stad,
    this.postnummer,
    this.latitude,
    this.longitude,
  });

  factory Gebruiker.fromFirestore(Map<String, dynamic> data, String uid) {
    return Gebruiker(
      uid: uid,
      email: data['email'] ?? '',
      adres: data['adres'],
      stad: data['stad'],
      postnummer: data['postnummer'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'adres': adres,
      'stad': stad,
      'postnummer': postnummer,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  bool get heeftLocatie => latitude != null && longitude != null;
}
