import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:verhuurapp/models/toestel.dart';
import 'package:verhuurapp/services/toestel_service.dart';
import 'package:verhuurapp/screens/toestellen/toestel_detail_screen.dart';

class KaartScreen extends StatefulWidget {
  const KaartScreen({super.key});

  @override
  State<KaartScreen> createState() => _KaartScreenState();
}

class _KaartScreenState extends State<KaartScreen> {
  final ToestelService _toestelService = ToestelService();
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<Toestel> _toestellen = [];

  static const LatLng _beginPositie = LatLng(50.8503, 4.3517); // Brussel

  @override
  void initState() {
    super.initState();
    _toestelService.getAlleToestellen().listen((toestellen) {
      if (mounted) {
        setState(() {
          _toestellen = toestellen;
          _markers = _bouwMarkers(toestellen);
        });
      }
    });
  }

  Set<Marker> _bouwMarkers(List<Toestel> toestellen) {
    final markers = <Marker>{};
    for (final toestel in toestellen) {
      if (toestel.latitude != null && toestel.longitude != null) {
        markers.add(
          Marker(
            markerId: MarkerId(toestel.id),
            position: LatLng(toestel.latitude!, toestel.longitude!),
            infoWindow: InfoWindow(
              title: toestel.naam,
              snippet: '€${toestel.prijs.toStringAsFixed(2)} per dag',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ToestelDetailScreen(toestel: toestel),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _beginPositie,
          zoom: 12,
        ),
        markers: _markers,
        onMapCreated: (controller) {
          _mapController = controller;
        },
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
      ),
    );
  }
}