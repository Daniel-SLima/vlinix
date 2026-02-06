import 'package:flutter/material.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/widgets/user_profile_menu.dart'; // O componente que criamos

// Import das telas filhas
import 'package:vlinix/screens/home_screen.dart'; // Aba Agendamentos (Dashboard)
import 'package:vlinix/screens/clients_screen.dart'; // Aba Clientes
import 'package:vlinix/screens/all_vehicles_screen.dart'; // Aba Veículos
import 'package:vlinix/screens/services_screen.dart'; // Aba Serviços
import 'package:vlinix/screens/finance_screen.dart'; // Aba Financeiro

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 2; // Começa na aba do meio (Agendamentos/Dashboard)

  // Lista das telas que serão exibidas
  final List<Widget> _screens = [
    const ClientsScreen(), // 0
    const AllVehiclesScreen(), // 1
    const HomeScreen(), // 2 (Agendamentos/Dashboard)
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
    return Scaffold(
      // O corpo muda conforme o índice
      // Usamos IndexedStack para manter o estado das abas (não recarregar tudo ao trocar)
      body: IndexedStack(index: _currentIndex, children: _screens),

      // --- BARRA DE NAVEGAÇÃO INFERIOR ---
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: AppColors.accent.withOpacity(
              0.2,
            ), // Dourado suave no fundo do ícone
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                );
              }
              return const TextStyle(color: Colors.grey, fontSize: 12);
            }),
            iconTheme: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const IconThemeData(
                  color: AppColors.accent,
                ); // Ícone Dourado
              }
              return const IconThemeData(color: Colors.grey); // Ícone Cinza
            }),
          ),
          child: NavigationBar(
            height: 65,
            backgroundColor:
                Colors.white, // Fundo branco na barra para limpeza visual
            // Se preferir fundo Chumbo (Dark Mode na barra), troque por AppColors.primary
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabTapped,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: 'Clientes',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_car_outlined),
                selectedIcon: Icon(Icons.directions_car),
                label: 'Veículos',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Agenda',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_offer_outlined),
                selectedIcon: Icon(Icons.local_offer),
                label: 'Serviços',
              ),
              NavigationDestination(
                icon: Icon(Icons.attach_money),
                selectedIcon: Icon(Icons.monetization_on),
                label: 'Caixa',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
