import 'package:flutter/material.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/l10n/app_localizations.dart'; // <--- IMPORTANTE

// Import das telas filhas
import 'package:vlinix/screens/home_screen.dart';
import 'package:vlinix/screens/clients_screen.dart';
import 'package:vlinix/screens/all_vehicles_screen.dart';
import 'package:vlinix/screens/services_screen.dart';
import 'package:vlinix/screens/finance_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 2; // Começa na aba do meio (Agendamentos/Dashboard)

  final List<Widget> _screens = [
    const ClientsScreen(), // 0
    const AllVehiclesScreen(), // 1
    const HomeScreen(), // 2
    const ServicesScreen(), // 3
    const FinanceScreen(), // 4
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!; // <--- Pega Traduções

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: AppColors.accent.withValues(
              alpha: 0.2,
            ), // Correção withValues
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
              }
              return const TextStyle(color: Colors.grey, fontSize: 12);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: AppColors.accent);
              }
              return const IconThemeData(color: Colors.grey);
            }),
          ),
          child: NavigationBar(
            height: 65,
            backgroundColor: Colors.white,
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabTapped,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                label: lang.menuClients, // Traduzido
              ),
              NavigationDestination(
                icon: const Icon(Icons.directions_car_outlined),
                selectedIcon: const Icon(Icons.directions_car),
                label: lang.menuVehicles, // Traduzido
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month),
                label: lang.menuAgenda, // Traduzido
              ),
              NavigationDestination(
                icon: const Icon(Icons.local_offer_outlined),
                selectedIcon: const Icon(Icons.local_offer),
                label: lang.menuServices, // Traduzido
              ),
              NavigationDestination(
                icon: const Icon(Icons.attach_money),
                selectedIcon: const Icon(Icons.monetization_on),
                label: lang.menuFinance, // Traduzido
              ),
            ],
          ),
        ),
      ),
    );
  }
}
