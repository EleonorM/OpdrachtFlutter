import 'package:flutter/material.dart';
import 'package:verhuurapp/app_state.dart';
import 'package:verhuurapp/services/auth_service.dart';
import 'package:verhuurapp/screens/toestellen/toestellen_overzicht_screen.dart';
import 'package:verhuurapp/screens/toestellen/toestel_toevoegen_screen.dart';
import 'package:verhuurapp/screens/reserveringen/mijn_reserveringen_screen.dart';
import 'package:verhuurapp/screens/reserveringen/dashboard_screen.dart';
import 'package:verhuurapp/screens/kaart_screen.dart';
import 'package:verhuurapp/screens/profiel_screen.dart';

const kBlue = Color(0xFF1E88E5);
const kBlueLight = Color(0xFFE3F2FD);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  int _huidigIndex = 0;

  @override
  void initState() {
    super.initState();
    homeTabNotifier.addListener(_onTabChange);
  }

  void _onTabChange() {
    setState(() => _huidigIndex = homeTabNotifier.value);
  }

  @override
  void dispose() {
    homeTabNotifier.removeListener(_onTabChange);
    super.dispose();
  }

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
        title: const Text('Lendly', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfielScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final bevestigd = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Uitloggen'),
                  content: const Text('Weet je zeker dat je wilt uitloggen?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Annuleren'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Uitloggen',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (bevestigd == true) {
                await _authService.logout();
                // StreamBuilder in main.dart toont automatisch LoginScreen
              }
            },
          ),
        ],
      ),
      body: _schermen[_huidigIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _huidigIndex,
        selectedItemColor: kBlue,
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
