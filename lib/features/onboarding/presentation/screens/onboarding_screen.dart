import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/domain_icons.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';

const _dominios = [
  {'id': 'calistenia', 'label': 'Calistenia', 'desc': 'Fuerza con tu propio peso — piernas, core, empuje y tracción.'},
  {'id': 'karate', 'label': 'Karate', 'desc': 'Kihon, katas y kumite, grado por grado.'},
  {'id': 'boxeo', 'label': 'Boxeo', 'desc': 'Postura, golpes, combinaciones y defensa.'},
  {'id': 'ajedrez', 'label': 'Ajedrez', 'desc': 'Teoría, puzzles y partidas jugables contra la app.'},
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  Future<void> _submit() async {
    final ok = await ref.read(onboardingProvider.notifier).completar();
    if (ok && mounted) {
      await ref.read(authProvider.notifier).refreshProfile();
      if (mounted) context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('¿Qué quieres aprender?',
                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.onSurface, letterSpacing: -0.02)),
              const SizedBox(height: 6),
              Text('Elige uno o varios — cada uno tiene su propia ruta con video y práctica.',
                  style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.neutralSecondary)),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.92),
                  itemCount: _dominios.length,
                  itemBuilder: (context, i) {
                    final d = _dominios[i];
                    final id = d['id'] as String;
                    final domainIcon = domainIcons[id]!;
                    final selected = state.dominiosSeleccionados.contains(id);
                    return GestureDetector(
                      onTap: () => ref.read(onboardingProvider.notifier).alternarDominio(id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.amberBg : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: selected ? AppColors.primary : AppColors.outlineVariant.withOpacity(0.4), width: selected ? 1.5 : 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(color: domainIcon.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                                  child: Icon(domainIcon.icon, color: domainIcon.color, size: 24),
                                ),
                                const Spacer(),
                                if (selected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(d['label'] as String, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(d['desc'] as String,
                                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11.5, color: AppColors.neutralSecondary, height: 1.35)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(state.error!, style: const TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.error, fontSize: 12)),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: state.dominiosSeleccionados.isEmpty || state.isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('EMPEZAR', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, letterSpacing: 0.04)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
