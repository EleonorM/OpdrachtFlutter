import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:verhuurapp/models/toestel.dart';
import 'package:verhuurapp/services/toestel_service.dart';

const _kBlue = Color(0xFF1E88E5);
const _kBlueLight = Color(0xFFE3F2FD);

const List<String> _categorieen = [
  'Huishouden & Schoonmaak',
  'Koken & Tafelen',
  'Computers & Telefoons',
  'Klussen & Gereedschap',
  'Gaming & Speelgoed',
  'Kleding & Kostuums',
  'Andere',
];

class _AdresSuggestie {
  final String displayNaam;
  final String kortNaam;
  final double lat;
  final double lon;
  _AdresSuggestie(this.displayNaam, this.kortNaam, this.lat, this.lon);
}

class ToestelToevoegenScreen extends StatefulWidget {
  const ToestelToevoegenScreen({super.key});

  @override
  State<ToestelToevoegenScreen> createState() => _ToestelToevoegenScreenState();
}

class _ToestelToevoegenScreenState extends State<ToestelToevoegenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _naamController = TextEditingController();
  final _beschrijvingController = TextEditingController();
  final _prijsController = TextEditingController();
  final _adresController = TextEditingController();
  final _toestelService = ToestelService();
  final FocusNode _adresFocusNode = FocusNode();

  String _geselecteerdeCategorie = _categorieen.first;
  bool _isLoading = false;
  LatLng? _geselecteerdeLocatie;
  String? _geselecteerdeAdresTekst;
  GoogleMapController? _mapController;

  // Foto
  File? _fotoFile;
  Uint8List? _fotoBytes;
  final ImagePicker _picker = ImagePicker();

  // Adres autocomplete
  List<_AdresSuggestie> _suggesties = [];
  bool _laadtSuggesties = false;
  bool _toonSuggesties = false;
  Timer? _debounceTimer;

  static const LatLng _beginPositie = LatLng(50.8503, 4.3517);

  @override
  void initState() {
    super.initState();
    _adresFocusNode.addListener(() {
      if (!_adresFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _toonSuggesties = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _naamController.dispose();
    _beschrijvingController.dispose();
    _prijsController.dispose();
    _adresController.dispose();
    _adresFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ── Foto ──────────────────────────────────────────────────────────────────

  Future<void> _fotoKiezen() async {
    final XFile? foto = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (foto == null) return;
    // Altijd bytes laden – werkt op web én native
    final bytes = await foto.readAsBytes();
    setState(() => _fotoBytes = bytes);
    // Ook File bewaren voor native (voor putFile fallback)
    if (!kIsWeb) setState(() => _fotoFile = File(foto.path));
  }

  bool get _heeftFoto => _fotoBytes != null;

  Future<String?> _fotoUploaden(String toestelId) async {
    if (_fotoBytes == null) return null;

    final ref = FirebaseStorage.instance
        .ref()
        .child('toestellen')
        .child('$toestelId.jpg');

    try {
      // Gebruik altijd putData (bytes) – werkt op alle platforms
      final uploadTask = ref.putData(
        _fotoBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Wacht max 60 seconden
      final snapshot = await uploadTask.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          uploadTask.cancel();
          throw TimeoutException('Foto upload time-out na 60 seconden.');
        },
      );

      if (snapshot.state == TaskState.success) {
        return await ref.getDownloadURL();
      }
      return null;
    } on FirebaseException catch (e) {
      debugPrint('Firebase Storage fout: ${e.code} – ${e.message}');
      rethrow;
    }
  }

  // ── Adres autocomplete (Nominatim) ────────────────────────────────────────

  void _onAdresGewijzigd(String waarde) {
    _debounceTimer?.cancel();
    if (waarde.trim().length < 3) {
      setState(() {
        _suggesties = [];
        _toonSuggesties = false;
      });
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _zoekSuggesties(waarde.trim());
    });
  }

  Future<void> _zoekSuggesties(String query) async {
    setState(() => _laadtSuggesties = true);
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '6',
        'addressdetails': '1',
        'accept-language': 'nl,en',
      });

      final response = await http
          .get(uri, headers: {'User-Agent': 'Lendly-Flutter/1.0 contact@lendly.be'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

      final suggesties = data.map((item) {
        // Veilig parsen – lat/lon zijn strings in Nominatim
        final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
        final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;

        final volledig = item['display_name']?.toString() ?? '';

        // Bouw een kort leesbaar label: "Straat, Stad, Land"
        final addr = item['address'] as Map<String, dynamic>? ?? {};
        final delen = <String>[];
        final straat = addr['road'] ?? addr['street'];
        final huisnr = addr['house_number'];
        final stad = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['municipality'];
        final land = addr['country'];
        if (straat != null) {
          delen.add(huisnr != null ? '$straat $huisnr' : straat as String);
        }
        if (stad != null) delen.add(stad as String);
        if (land != null) delen.add(land as String);
        final kort = delen.isNotEmpty ? delen.join(', ') : volledig.split(',').take(3).join(',');

        return _AdresSuggestie(volledig, kort, lat, lon);
      }).where((s) => s.lat != 0.0 && s.lon != 0.0).toList();

      if (mounted) {
        setState(() {
          _suggesties = suggesties;
          _toonSuggesties = suggesties.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Adres zoeken fout: $e');
      if (mounted) setState(() => _toonSuggesties = false);
    } finally {
      if (mounted) setState(() => _laadtSuggesties = false);
    }
  }

  void _suggestieGekozen(_AdresSuggestie suggestie) {
    final positie = LatLng(suggestie.lat, suggestie.lon);
    _adresController.text = suggestie.kortNaam;
    _adresFocusNode.unfocus();
    setState(() {
      _geselecteerdeLocatie = positie;
      _geselecteerdeAdresTekst = suggestie.kortNaam;
      _suggesties = [];
      _toonSuggesties = false;
    });
    // Even wachten zodat de map controller zeker klaar is
    Future.delayed(const Duration(milliseconds: 300), () {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(positie, 15),
      );
    });
  }

  // ── Opslaan ───────────────────────────────────────────────────────────────

  Future<void> _toestelOpslaan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_geselecteerdeLocatie == null) {
      _toonSnackbar('Voer een adres in of tik op de kaart.', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final toestelData = Toestel(
        id: '',
        naam: _naamController.text.trim(),
        beschrijving: _beschrijvingController.text.trim(),
        categorie: _geselecteerdeCategorie,
        prijs: double.parse(_prijsController.text.trim()),
        beschikbaarheid: 'Beschikbaar',
        verhuurderEmail: user.email!,
        verhuurderUid: user.uid,
        latitude: _geselecteerdeLocatie!.latitude,
        longitude: _geselecteerdeLocatie!.longitude,
        adres: _geselecteerdeAdresTekst ?? _adresController.text.trim(),
      );

      // 1. Toestel opslaan in Firestore
      final toestelId = await _toestelService.toestelToevoegenMetId(toestelData);

      // 2. Foto uploaden (apart proberen – mislukken stopt het opslaan niet)
      if (_heeftFoto) {
        try {
          final fotoUrl = await _fotoUploaden(toestelId);
          if (fotoUrl != null) {
            await _toestelService.toestelUpdaten(toestelId, {'fotoUrl': fotoUrl});
          } else {
            _toonSnackbar('Toestel opgeslagen, maar foto kon niet worden geüpload.', Colors.orange);
          }
        } catch (e) {
          // Foto upload mislukt → toestel is al opgeslagen zonder foto
          _toonSnackbar(
            'Toestel opgeslagen zonder foto. Fout: ${_fotofout(e)}',
            Colors.orange,
          );
        }
      }

      if (mounted) {
        _toonSnackbar('Toestel succesvol toegevoegd!', _kBlue);
        _resetFormulier();
      }
    } catch (e) {
      if (mounted) {
        _toonSnackbar('Fout bij opslaan: ${e.toString()}', Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fotofout(Object e) {
    if (e is TimeoutException) return 'Upload time-out.';
    if (e is FirebaseException) {
      if (e.code == 'unauthorized') return 'Geen toestemming voor Firebase Storage.';
      if (e.code == 'canceled') return 'Upload geannuleerd.';
      return 'Firebase fout (${e.code}).';
    }
    return e.toString();
  }

  void _toonSnackbar(String tekst, Color kleur) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tekst), backgroundColor: kleur),
    );
  }

  void _resetFormulier() {
    _naamController.clear();
    _beschrijvingController.clear();
    _prijsController.clear();
    _adresController.clear();
    setState(() {
      _geselecteerdeLocatie = null;
      _geselecteerdeAdresTekst = null;
      _fotoFile = null;
      _fotoBytes = null;
      _geselecteerdeCategorie = _categorieen.first;
    });
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_beginPositie, 12),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  Widget _fotoWidget() {
    if (_fotoBytes != null) {
      return Image.memory(_fotoBytes!, fit: BoxFit.cover, width: double.infinity);
    }
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 48, color: _kBlue),
        SizedBox(height: 8),
        Text('Tik om een foto toe te voegen',
            style: TextStyle(color: _kBlue)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toestel toevoegen'),
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
      ),
      body: GestureDetector(
        onTap: () {
          _adresFocusNode.unfocus();
          setState(() => _toonSuggesties = false);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Foto ──
                GestureDetector(
                  onTap: _fotoKiezen,
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: _kBlueLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBlue.withValues(alpha: 0.3)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _fotoWidget(),
                  ),
                ),
                if (_heeftFoto)
                  TextButton.icon(
                    onPressed: _fotoKiezen,
                    icon: const Icon(Icons.edit, color: _kBlue),
                    label: const Text('Foto wijzigen',
                        style: TextStyle(color: _kBlue)),
                  ),
                const SizedBox(height: 16),

                // ── Naam ──
                TextFormField(
                  controller: _naamController,
                  decoration: const InputDecoration(
                    labelText: 'Naam toestel',
                    prefixIcon: Icon(Icons.devices),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Vul een naam in.' : null,
                ),
                const SizedBox(height: 16),

                // ── Beschrijving ──
                TextFormField(
                  controller: _beschrijvingController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Beschrijving',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Vul een beschrijving in.'
                      : null,
                ),
                const SizedBox(height: 16),

                // ── Categorie ──
                DropdownButtonFormField<String>(
                  value: _geselecteerdeCategorie,
                  decoration: const InputDecoration(
                    labelText: 'Categorie',
                    prefixIcon: Icon(Icons.category),
                    border: OutlineInputBorder(),
                  ),
                  items: _categorieen
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _geselecteerdeCategorie = v!),
                ),
                const SizedBox(height: 16),

                // ── Prijs ──
                TextFormField(
                  controller: _prijsController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Prijs per dag (€)',
                    prefixIcon: Icon(Icons.euro),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vul een prijs in.';
                    if (double.tryParse(v.replaceAll(',', '.')) == null) {
                      return 'Vul een geldig bedrag in.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // ── Locatie ──
                const Text('Locatie *',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),

                // Adres tekstveld
                TextField(
                  controller: _adresController,
                  focusNode: _adresFocusNode,
                  onChanged: _onAdresGewijzigd,
                  decoration: InputDecoration(
                    labelText: 'Adres zoeken (straat, stad...)',
                    prefixIcon: const Icon(Icons.search, color: _kBlue),
                    border: const OutlineInputBorder(),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: _kBlue, width: 2),
                    ),
                    suffixIcon: _laadtSuggesties
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _kBlue),
                            ),
                          )
                        : _adresController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _adresController.clear();
                                  setState(() {
                                    _suggesties = [];
                                    _toonSuggesties = false;
                                    _geselecteerdeLocatie = null;
                                    _geselecteerdeAdresTekst = null;
                                  });
                                },
                              )
                            : null,
                  ),
                ),

                // Suggesties dropdown
                if (_toonSuggesties && _suggesties.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _kBlue.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: _suggesties.asMap().entries.map((entry) {
                        final s = entry.value;
                        final isLaatste =
                            entry.key == _suggesties.length - 1;
                        return Column(
                          children: [
                            InkWell(
                              onTap: () => _suggestieGekozen(s),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_pin,
                                        color: _kBlue, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.kortNaam,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            s.displayNaam,
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!isLaatste)
                              const Divider(height: 1, indent: 44),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      _geselecteerdeLocatie != null
                          ? Icons.check_circle
                          : Icons.info_outline,
                      color: _geselecteerdeLocatie != null
                          ? _kBlue
                          : Colors.grey,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _geselecteerdeLocatie != null
                            ? 'Locatie ingesteld: ${_geselecteerdeAdresTekst ?? ""}'
                            : 'Typ een adres en kies uit de suggesties, of tik op de kaart.',
                        style: TextStyle(
                          color: _geselecteerdeLocatie != null
                              ? _kBlue
                              : Colors.grey,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Kaart
                SizedBox(
                  height: 220,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: _beginPositie,
                        zoom: 12,
                      ),
                      onMapCreated: (c) => _mapController = c,
                      markers: _geselecteerdeLocatie == null
                          ? {}
                          : {
                              Marker(
                                markerId: const MarkerId('locatie'),
                                position: _geselecteerdeLocatie!,
                                infoWindow: InfoWindow(
                                  title: _geselecteerdeAdresTekst ?? 'Locatie',
                                ),
                              ),
                            },
                      onTap: (p) {
                        setState(() {
                          _geselecteerdeLocatie = p;
                          _geselecteerdeAdresTekst =
                              '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';
                          _toonSuggesties = false;
                        });
                        _adresController.text = _geselecteerdeAdresTekst!;
                      },
                      zoomControlsEnabled: true,
                      myLocationButtonEnabled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Opslaan knop
                ElevatedButton(
                  onPressed: _isLoading ? null : _toestelOpslaan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Text('Opslaan...'),
                          ],
                        )
                      : const Text('Toestel opslaan',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
