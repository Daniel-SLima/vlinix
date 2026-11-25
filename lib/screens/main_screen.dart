import 'package:vlinix/data/app_backend.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/l10n/app_localizations.dart';

// Import das telas filhas
import 'package:vlinix/screens/home_screen.dart';
import 'package:vlinix/screens/clients_screen.dart';
// REMOVIDO: import 'package:vlinix/screens/all_vehicles_screen.dart';
import 'package:vlinix/screens/services_screen.dart';
import 'package:vlinix/screens/finance_screen.dart';
import 'package:vlinix/screens/login_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex =
      1; // Ajustado para começar na aba de Agenda (que agora é a índice 1)
  Timer? _sessionTimer;

  RealtimeChannel? _securitySubscription;

  // --- MUDANÇA: Tiramos a AllVehiclesScreen da lista de telas ---
  final List<Widget> _screens = [
    const ClientsScreen(),
    const HomeScreen(), // Agenda
    const ServicesScreen(),
    const FinanceScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkDemoUser();
    _setupRealtimeSecurity();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    if (_securitySubscription != null) {
      AppBackend.client.removeChannel(_securitySubscription!);
    }
    super.dispose();
  }

  void _setupRealtimeSecurity() {
    if (AppBackend.isDemo) return;
    final supabase = AppBackend.client;
    final myUserId = supabase.auth.currentUser?.id;

    if (myUserId == null) return;

    _securitySubscription = supabase
        .channel('public:profiles')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: myUserId,
          ),
          callback: (payload) {
            final isActive = payload.newRecord['is_active'];
            if (isActive == false) {
              _forceLogout(isSuspended: true);
            }
          },
        )
        .subscribe();
  }

  Future<void> _forceLogout({bool isSuspended = false}) async {
    if (!mounted) return;

    await AppBackend.client.auth.signOut();

    if (mounted) {
      final lang = AppLocalizations.of(context)!;

      String message = isSuspended
          ? lang.msgAccountSuspendedLive
          : lang.msgDemoModeEnded;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _checkDemoUser() {
    if (AppBackend.isDemo) return;
    final user = AppBackend.client.auth.currentUser;
    const emailDeTeste = 'visitante@vlinix.com';

    if (user?.email == emailDeTeste) {
      debugPrint('⏳ Modo Demonstração iniciado: 10 minutos restantes.');
      _sessionTimer = Timer(const Duration(minutes: 10), () {
        _forceLogout();
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final lang = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(lang.msgDemoModeStarted),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      });
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
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: AppColors.accent.withValues(alpha: 0.2),
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
            // --- MUDANÇA: APENAS 4 ITENS AGORA ---
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                label: lang.menuClients,
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
