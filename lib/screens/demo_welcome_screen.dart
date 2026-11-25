import 'package:flutter/material.dart';
import 'package:vlinix/screens/main_screen.dart';
import 'package:vlinix/theme/app_colors.dart';

class DemoWelcomeScreen extends StatelessWidget {
  const DemoWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/images/logo_symbol.png', height: 76),
              const SizedBox(height: 24),
              const Text(
                'Vlinix',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Da agenda ao resultado do seu negócio.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              const Text(
                'Explore o aplicativo de gestão para profissionais de estética automotiva com clientes, veículos, serviços e movimentações financeiras fictícios.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(Icons.people_outline, size: 18),
                    label: Text('Clientes e veículos'),
                  ),
                  Chip(
                    avatar: Icon(Icons.calendar_month, size: 18),
                    label: Text('Agendamentos'),
                  ),
                  Chip(
                    avatar: Icon(Icons.local_offer_outlined, size: 18),
                    label: Text('Serviços'),
                  ),
                  Chip(
                    avatar: Icon(Icons.insights, size: 18),
                    label: Text('Finanças'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MainScreen()),
                ),
                icon: const Icon(Icons.explore_outlined),
                label: const Text(
                  'Explorar demonstração',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sem conta e sem senha. Você pode criar, editar e excluir exemplos. Use “Restaurar exemplo” para recomeçar. Nenhum dado é enviado a um servidor.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
