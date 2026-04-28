import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:verhuurapp/models/toestel.dart';
import 'package:verhuurapp/screens/reserveringen/reservering_maken_screen.dart';

const _kBlue = Color(0xFF1E88E5);
const _kBlueLight = Color(0xFFE3F2FD);

class ToestelDetailScreen extends StatelessWidget {
  final Toestel toestel;

  const ToestelDetailScreen({super.key, required this.toestel});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final isEigenToestel = user.uid == toestel.verhuurderUid;

    return Scaffold(
      appBar: AppBar(
        title: Text(toestel.naam),
        backgroundColor: _kBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Foto
            SizedBox(
              height: 240,
              child: toestel.fotoUrl != null
                  ? Image.network(
                      toestel.fotoUrl!,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: _kBlueLight,
                          child: const Center(child: CircularProgressIndicator()),
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
                  // Naam + categorie
                  Text(
                    toestel.naam,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.category, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(toestel.categorie,
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Prijs
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _kBlueLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Prijs per dag',
                            style: TextStyle(fontSize: 16)),
                        Text(
                          '€${toestel.prijs.toStringAsFixed(2)}',
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
                  // Beschikbaarheid
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: toestel.beschikbaarheid == 'Beschikbaar'
                          ? _kBlueLight
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Beschikbaarheid',
                            style: TextStyle(fontSize: 16)),
                        Text(
                          toestel.beschikbaarheid,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: toestel.beschikbaarheid == 'Beschikbaar'
                                ? _kBlue
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Beschrijving
                  const Text('Beschrijving',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(toestel.beschrijving,
                      style:
                          const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 16),
                  // Verhuurder
                  const Text('Aangeboden door',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(toestel.verhuurderEmail,
                            style: const TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Reserveer knop
                  if (!isEigenToestel)
                    ElevatedButton(
                      onPressed: toestel.beschikbaarheid == 'Beschikbaar'
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ReserveringMakenScreen(toestel: toestel),
                                ),
                              );
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  Widget _fotoPlaceholder() {
    return Container(
      color: _kBlueLight,
      child: const Center(
        child: Icon(Icons.devices, size: 80, color: _kBlue),
      ),
    );
  }
}
