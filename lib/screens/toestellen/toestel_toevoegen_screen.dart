import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:verhuurapp/models/toestel.dart';
import 'package:verhuurapp/services/toestel_service.dart';

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
  final _toestelService = ToestelService();

  String _geselecteerdeCategorie = 'Stofzuiger';
  String _geselecteerdeBeschikbaarheid = 'Beschikbaar';
  bool _isLoading = false;
  LatLng? _geselecteerdeLocatie;

  final List<String> _categorieen = [
    'Stofzuiger',
    'Grasmaaier',
    'Keukenmachine',
    'Boormachine',
    'Ladder',
    'Hogedrukreiniger',
    'Andere',
  ];

  final List<String> _beschikbaarheden = [
    'Beschikbaar',
    'Niet beschikbaar',
  ];

  static const LatLng _beginPositie = LatLng(50.8503, 4.3517);

  @override
  void dispose() {
    _naamController.dispose();
    _beschrijvingController.dispose();
    _prijsController.dispose();
    super.dispose();
  }

  Future<void> _toestelOpslaan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final toestel = Toestel(
        id: '',
        naam: _naamController.text.trim(),
        beschrijving: _beschrijvingController.text.trim(),
        categorie: _geselecteerdeCategorie,
        prijs: double.parse(_prijsController.text.trim()),
        beschikbaarheid: _geselecteerdeBeschikbaarheid,
        verhuurderEmail: user.email!,
        verhuurderUid: user.uid,
        latitude: _geselecteerdeLocatie?.latitude,
        longitude: _geselecteerdeLocatie?.longitude,
      );

      await _toestelService.toestelToevoegen(toestel);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Toestel succesvol toegevoegd! ✅'),
            backgroundColor: Colors.green,
          ),
        );
        _naamController.clear();
        _beschrijvingController.clear();
        _prijsController.clear();
        setState(() => _geselecteerdeLocatie = null);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toestel toevoegen'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _naamController,
                decoration: const InputDecoration(
                  labelText: 'Naam toestel',
                  prefixIcon: Icon(Icons.devices),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vul een naam in.';
                  }
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
                items: _categorieen.map((categorie) {
                  return DropdownMenuItem(
                    value: categorie,
                    child: Text(categorie),
                  );
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
                  if (value == null || value.isEmpty) {
                    return 'Vul een prijs in.';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Vul een geldig bedrag in.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _geselecteerdeBeschikbaarheid,
                decoration: const InputDecoration(
                  labelText: 'Beschikbaarheid',
                  prefixIcon: Icon(Icons.event_available),
                  border: OutlineInputBorder(),
                ),
                items: _beschikbaarheden.map((beschikbaarheid) {
                  return DropdownMenuItem(
                    value: beschikbaarheid,
                    child: Text(beschikbaarheid),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _geselecteerdeBeschikbaarheid = value!);
                },
              ),
              const SizedBox(height: 16),
              // Locatie picker
              const Text(
                'Locatie (optioneel)',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tik op de kaart om de locatie van het toestel aan te duiden.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              if (_geselecteerdeLocatie != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Locatie geselecteerd: ${_geselecteerdeLocatie!.latitude.toStringAsFixed(4)}, ${_geselecteerdeLocatie!.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                height: 200,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _beginPositie,
                      zoom: 12,
                    ),
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
                  backgroundColor: Colors.green,
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