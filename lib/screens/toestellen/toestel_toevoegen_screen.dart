import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:verhuurapp/models/toestel.dart';
import 'package:verhuurapp/services/toestel_service.dart';

// Geocoding alleen op niet-web platforms
import 'package:geocoding/geocoding.dart'
    if (dart.library.html) 'package:verhuurapp/services/geocoding_stub.dart';

const _kBlue = Color(0xFF1E88E5);
const _kBlueLight = Color(0xFFE3F2FD);

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

  String _geselecteerdeCategorie = 'Stofzuiger';
  bool _isLoading = false;
  bool _isGeocoding = false;
  LatLng? _geselecteerdeLocatie;
  GoogleMapController? _mapController;

  // Platform-afhankelijke foto opslag
  File? _fotoFile; // mobile/desktop
  Uint8List? _fotoBytes; // web

  final ImagePicker _picker = ImagePicker();

  final List<String> _categorieen = [
    'Stofzuiger',
    'Grasmaaier',
    'Keukenmachine',
    'Boormachine',
    'Ladder',
    'Hogedrukreiniger',
    'Andere',
  ];

  static const LatLng _beginPositie = LatLng(50.8503, 4.3517);

  @override
  void dispose() {
    _naamController.dispose();
    _beschrijvingController.dispose();
    _prijsController.dispose();
    _adresController.dispose();
    super.dispose();
  }

  Future<void> _fotoKiezen() async {
    final XFile? foto = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (foto == null) return;

    if (kIsWeb) {
      final bytes = await foto.readAsBytes();
      setState(() => _fotoBytes = bytes);
    } else {
      setState(() => _fotoFile = File(foto.path));
    }
  }

  Future<String?> _fotoUploaden(String toestelId) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('toestellen')
        .child('$toestelId.jpg');

    if (kIsWeb && _fotoBytes != null) {
      await ref.putData(_fotoBytes!,
          SettableMetadata(contentType: 'image/jpeg'));
    } else if (!kIsWeb && _fotoFile != null) {
      await ref.putFile(_fotoFile!);
    } else {
      return null;
    }
    return await ref.getDownloadURL();
  }

  bool get _heeftFoto =>
      (kIsWeb && _fotoBytes != null) || (!kIsWeb && _fotoFile != null);

  Future<void> _zoekAdres() async {
    final adres = _adresController.text.trim();
    if (adres.isEmpty) return;

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tik op de kaart om een locatie te kiezen in de browser.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGeocoding = true);
    try {
      final locaties = await locationFromAddress(adres);
      if (locaties.isNotEmpty) {
        final loc = locaties.first;
        final nieuwePositie = LatLng(loc.latitude, loc.longitude);
        setState(() => _geselecteerdeLocatie = nieuwePositie);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(nieuwePositie, 15),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Adres niet gevonden. Probeer een ander adres.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kon adres niet vinden. Tik op de kaart.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() => _isGeocoding = false);
    }
  }

  Future<void> _toestelOpslaan() async {
    if (!_formKey.currentState!.validate()) return;

    if (_geselecteerdeLocatie == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voer een adres in of tik op de kaart.'),
          backgroundColor: Colors.orange,
        ),
      );
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
        adres: _adresController.text.trim().isEmpty
            ? null
            : _adresController.text.trim(),
      );

      final toestelId = await _toestelService.toestelToevoegenMetId(toestelData);

      if (_heeftFoto) {
        final fotoUrl = await _fotoUploaden(toestelId);
        if (fotoUrl != null) {
          await _toestelService.toestelUpdaten(toestelId, {'fotoUrl': fotoUrl});
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toestel succesvol toegevoegd!'),
            backgroundColor: _kBlue,
          ),
        );
        _naamController.clear();
        _beschrijvingController.clear();
        _prijsController.clear();
        _adresController.clear();
        setState(() {
          _geselecteerdeLocatie = null;
          _fotoFile = null;
          _fotoBytes = null;
          _geselecteerdeCategorie = 'Stofzuiger';
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_beginPositie, 12),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _fotoWidget() {
    if (kIsWeb && _fotoBytes != null) {
      return Image.memory(_fotoBytes!, fit: BoxFit.cover, width: double.infinity);
    } else if (!kIsWeb && _fotoFile != null) {
      return Image.file(_fotoFile!, fit: BoxFit.cover, width: double.infinity);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Foto sectie
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
                  icon: const Icon(Icons.edit),
                  label: const Text('Foto wijzigen'),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _naamController,
                decoration: const InputDecoration(
                  labelText: 'Naam toestel',
                  prefixIcon: Icon(Icons.devices),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Vul een naam in.';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _beschrijvingController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Beschrijving',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vul een beschrijving in.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _geselecteerdeCategorie,
                decoration: const InputDecoration(
                  labelText: 'Categorie',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(),
                ),
                items: _categorieen.map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (value) {
                  setState(() => _geselecteerdeCategorie = value!);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _prijsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Prijs per dag (€)',
                  prefixIcon: Icon(Icons.euro),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Vul een prijs in.';
                  if (double.tryParse(value) == null) {
                    return 'Vul een geldig bedrag in.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Adres sectie
              const Text(
                'Locatie *',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _adresController,
                      decoration: InputDecoration(
                        labelText: 'Adres (straat, stad)',
                        prefixIcon: const Icon(Icons.location_on),
                        border: const OutlineInputBorder(),
                        suffixIcon: _isGeocoding
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _zoekAdres(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isGeocoding ? null : _zoekAdres,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.search),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                kIsWeb
                    ? 'Tik op de kaart om de locatie te kiezen.'
                    : 'Typ een adres en tik op zoeken, of tik op de kaart.',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              if (_geselecteerdeLocatie != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: _kBlue, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Locatie ingesteld',
                        style: const TextStyle(
                            color: _kBlue, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _beginPositie,
                      zoom: 12,
                    ),
                    onMapCreated: (controller) =>
                        _mapController = controller,
                    markers: _geselecteerdeLocatie == null
                        ? {}
                        : {
                            Marker(
                              markerId: const MarkerId('geselecteerd'),
                              position: _geselecteerdeLocatie!,
                            ),
                          },
                    onTap: (positie) {
                      setState(() => _geselecteerdeLocatie = positie);
                    },
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _toestelOpslaan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Toestel opslaan',
                        style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
