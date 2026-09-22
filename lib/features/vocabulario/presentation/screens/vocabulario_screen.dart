import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/vocabulario_provider.dart';

class VocabularioScreen extends ConsumerWidget {
  const VocabularioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vocabularioProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Vocabulario', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.error != null
                ? Center(child: Text(state.error!, style: const TextStyle(fontFamily: 'PlusJakartaSans')))
                : state.agotado
                    ? const _EstadoAgotado()
                    : _TarjetaPalabra(state: state),
      ),
      floatingActionButton: (!state.isLoading && !state.agotado)
          ? FloatingActionButton.extended(
              onPressed: () => ref.read(vocabularioProvider.notifier).siguiente(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Siguiente palabra', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }
}

class _EstadoAgotado extends StatelessWidget {
  const _EstadoAgotado();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, size: 48, color: AppColors.neutralSecondary),
          const SizedBox(height: 16),
          Text('Aprendiste todas las palabras del banco actual.',
              textAlign: TextAlign.center, style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          Text('Vuelve pronto por más — nunca se repite lo mismo.',
              textAlign: TextAlign.center, style: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.neutralSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TarjetaPalabra extends StatelessWidget {
  final PalabraState state;
  const _TarjetaPalabra({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8d4b00), Color(0xFFb15f00)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.categoriaGramatical != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(999)),
                    child: Text(state.categoriaGramatical!.toUpperCase(),
                        style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.06)),
                  ),
                const SizedBox(height: 12),
                Text(state.palabra ?? '', style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('DEFINICIÓN', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neutralSecondary, letterSpacing: 0.08)),
          const SizedBox(height: 8),
          Text(state.definicion ?? '', style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 16, height: 1.4)),
          if (state.ejemplo != null) ...[
            const SizedBox(height: 20),
            Text('EJEMPLO', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neutralSecondary, letterSpacing: 0.08)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
              child: Text('"${state.ejemplo}"', style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontStyle: FontStyle.italic)),
            ),
          ],
          if (state.fuente != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              Icon(Icons.verified_rounded, size: 14, color: AppColors.neutralSecondary),
              const SizedBox(width: 6),
              Text(state.fuente!, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: AppColors.neutralSecondary)),
            ]),
          ],
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}
