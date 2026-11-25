import 'package:flutter/material.dart';
import 'package:vlinix/theme/app_colors.dart';

class DemoBanner extends StatelessWidget {
  final Widget child;
  final VoidCallback onReset;
  final bool persistent;
  const DemoBanner({
    super.key,
    required this.child,
    required this.onReset,
    required this.persistent,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: const Color(0xFFFFF3DB),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.science_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    persistent
                        ? 'Demonstração • Dados fictícios. Alterações só neste navegador.'
                        : 'Demonstração • Dados fictícios. Alterações apenas nesta sessão.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Restaurar exemplo'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );
}
