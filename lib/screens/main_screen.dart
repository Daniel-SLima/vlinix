import 'dart:async'; // <--- Necessário para o Timer
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // <--- Necessário para Auth
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/l10n/app_localizations.dart';

// Import das telas filhas
import 'package:vlinix/screens/home_screen.dart';
import 'package:vlinix/screens/clients_screen.dart';
import 'package:vlinix/screens/all_vehicles_screen.dart';
import 'package:vlinix/screens/services_screen.dart';
import 'package:vlinix/screens/finance_screen.dart';
import 'package:vlinix/screens/login_screen.dart'; // <--- Verifique se o caminho está correto

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 2; // Começa na aba do meio (Agendamentos/Dashboard)
  Timer? _sessionTimer; // Variável para controlar o tempo

  final List<Widget> _screens = [
    const ClientsScreen(), // 0
    const AllVehiclesScreen(), // 1
    const HomeScreen(), // 2
    const ServicesScreen(), // 3
    const FinanceScreen(), // 4
  ];

  @override
  void initState() {
    super.initState();
    _checkDemoUser(); // <--- Inicia a verificação ao abrir
  }

  @override
  void dispose() {
    _sessionTimer?.cancel(); // <--- Limpa o timer se sair da tela antes
    super.dispose();
  }

  // --- LÓGICA DE TEMPO LIMITE ---
  void _checkDemoUser() {
    final user = Supabase.instance.client.auth.currentUser;

    // DEFINA AQUI QUEM É O USUÁRIO DE TESTE
    // Pode ser por email, ou por uma metadata específica
    const emailDeTeste = 'visitante@vlinix.com';

    if (user?.email == emailDeTeste) {
      debugPrint('⏳ Modo Demonstração iniciado: 10 minutos restantes.');

      // Inicia o timer de 10 minutos (600 segundos)
      _sessionTimer = Timer(const Duration(minutes: 10), () {
        _forceLogout();
      });

      // Opcional: Mostrar um aviso inicial
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Modo Teste: Sessão expira em 10 minutos! ⏳'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      });
    }
  }

  Future<void> _forceLogout() async {
    if (!mounted) return;

    // 1. Desloga do Supabase
    await Supabase.instance.client.auth.signOut();

    // 2. Redireciona para o Login (removendo histórico)
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );

      // 3. Aviso de expiração
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tempo de teste finalizado. Obrigado! 👋'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: AppColors.accent.withOpacity(
              0.2,
            ), // Deprecated warning corrigido: withValues se for Flutter 3.27+
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
                label: lang.menuClients,
              ),
              NavigationDestination(
                icon: const Icon(Icons.directions_car_outlined),
                selectedIcon: const Icon(Icons.directions_car),
                label: lang.menuVehicles,
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month),
                label: lang.menuAgenda,
              ),
              NavigationDestination(
                icon: const Icon(Icons.local_offer_outlined),
                selectedIcon: const Icon(Icons.local_offer),
                label: lang.menuServices,
              ),
              NavigationDestination(
                icon: const Icon(Icons.attach_money),
                selectedIcon: const Icon(Icons.monetization_on),
                label: lang.menuFinance,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
