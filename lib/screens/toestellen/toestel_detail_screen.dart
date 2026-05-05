import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:verhuurapp/models/toestel.dart';
import 'package:verhuurapp/models/gebruiker.dart';
import 'package:verhuurapp/services/gebruiker_service.dart';
import 'package:verhuurapp/screens/reserveringen/reservering_maken_screen.dart';

const _kBlue = Color(0xFF1E88E5);
const _kBlueLight = Color(0xFFE3F2FD);

class ToestelDetailScreen extends StatefulWidget {
  final Toestel toestel;

  const ToestelDetailScreen({super.key, required this.toestel});

  @override
  State<ToestelDetailScreen> createState() => _ToestelDetailScreenState();
}

class _ToestelDetailScreenState extends State<ToestelDetailScreen> {
  Gebruiker? _gebruiker;
  bool _laadtProfiel = true;

  @override
  void initState() {
    super.initState();
    _laadGebruikersProfiel();
  }

  Future<void> _laadGebruikersProfiel() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final profiel = await GebruikerService().getProfiel(uid);
        if (mounted) setState(() => _gebruiker = profiel);
      } catch (_) {}
    }
    if (mounted) setState(() => _laadtProfiel = false);
  }

  String? _berekenAfstand() {
    if (_laadtProfiel) return null;
    if (widget.toestel.latitude == null || widget.toestel.longitude == null) return null;
    if (_gebruiker == null || !_gebruiker!.heeftLocatie) return null;

    final meters = Geolocator.distanceBetween(
      _gebruiker!.latitude!,
      _gebruiker!.longitude!,
      widget.toestel.latitude!,
      widget.toestel.longitude!,
    );

    if (meters < 1000) {
      return '${meters.round()} m van jou';
    } else {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1)} km van jou';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final isEigenToestel = user.uid == widget.toestel.verhuurderUid;
    final afstand = _berekenAfstand();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.toestel.naam),
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Foto ──
            SizedBox(
              height: 240,
              child: widget.toestel.fotoUrl != null
                  ? Image.network(
                      widget.toestel.fotoUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: _kBlueLight,
                          child: const Center(
                              child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (_, __, ___) => _fotoPlaceholder(),
                    )
                  : _fotoPlaceholder(),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Naam + afstand ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.toestel.naam,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (afstand != null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kBlueLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: _kBlue.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me,
                                  size: 14, color: _kBlue),
                              const SizedBox(width: 4),
                              Text(
                                afstand,
                                style: const TextStyle(
                                    color: _kBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // ── Categorie ──
                  Row(
                    children: [
                      const Icon(Icons.category,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(widget.toestel.categorie,
                          style: const TextStyle(color: Colors.grey)),
                      if (widget.toestel.adres != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on,
                            size: 16, color: Colors.grey),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            widget.toestel.adres!,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Prijs ──
                  _infoKaart(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Prijs per dag',
                            style: TextStyle(fontSize: 16)),
                        Text(
                          '€${widget.toestel.prijs.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: _kBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Beschikbaarheid ──
                  _infoKaart(
                    kleur: widget.toestel.beschikbaarheid == 'Beschikbaar'
                        ? _kBlueLight
                        : Colors.red.shade50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Beschikbaarheid',
                            style: TextStyle(fontSize: 16)),
                        Text(
                          widget.toestel.beschikbaarheid,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                widget.toestel.beschikbaarheid == 'Beschikbaar'
                                    ? _kBlue
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Beschrijving ──
                  const Text('Beschrijving',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.toestel.beschrijving,
                      style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 16),

                  // ── Verhuurder ──
                  const Text('Aangeboden door',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(widget.toestel.verhuurderEmail,
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Reserveer knop ──
                  if (!isEigenToestel)
                    ElevatedButton(
                      onPressed:
                          widget.toestel.beschikbaarheid == 'Beschikbaar'
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ReserveringMakenScreen(
                                          toestel: widget.toestel),
                                    ),
                                  );
                                }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Reserveer dit toestel',
                          style: TextStyle(fontSize: 16)),
                    ),
                  if (isEigenToestel)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kBlueLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info, color: _kBlue),
                          SizedBox(width: 8),
                          Text('Dit is jouw eigen toestel.',
                              style: TextStyle(color: _kBlue)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoKaart({required Widget child, Color? kleur}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kleur ?? _kBlueLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _fotoPlaceholder() {
    return Container(
      color: _kBlueLight,
      child: const Center(
          child: Icon(Icons.devices, size: 80, color: _kBlue)),
    );
  }
}
