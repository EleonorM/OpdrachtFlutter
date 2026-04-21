import 'package:flutter/material.dart';
import 'package:verhuurapp/services/auth_service.dart';
import 'package:verhuurapp/screens/toestellen/toestellen_overzicht_screen.dart';
import 'package:verhuurapp/screens/toestellen/toestel_toevoegen_screen.dart';
import 'package:verhuurapp/screens/reserveringen/mijn_reserveringen_screen.dart';
import 'package:verhuurapp/screens/reserveringen/dashboard_screen.dart';
import 'package:verhuurapp/screens/kaart_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  int _huidigIndex = 0;

  final List<Widget> _schermen = [
    const ToestellenOverzichtScreen(),
    const KaartScreen(),
    const ToestelToevoegenScreen(),
    const MijnReserveringenScreen(),
    const DashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lendly'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.logout();
            },
          ),
        ],
      ),
      body: _schermen[_huidigIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _huidigIndex,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() => _huidigIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Ontdekken',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Kaart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle),
            label: 'Toevoegen',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Mijn huur',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}