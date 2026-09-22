import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/trivia_provider.dart';

class TriviaScreen extends ConsumerWidget {
  const TriviaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(triviaProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Trivia', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, color: AppColors.onSurface)),
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
                    : _TarjetaTrivia(state: state),
      ),
      floatingActionButton: (!state.isLoading && !state.agotado && state.correcto != null)
          ? FloatingActionButton.extended(
              onPressed: () => ref.read(triviaProvider.notifier).siguiente(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Siguiente pregunta', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700)),
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
          Icon(Icons.quiz_rounded, size: 48, color: AppColors.neutralSecondary),
          const SizedBox(height: 16),
          Text('Respondiste todas las preguntas del banco actual.',
              textAlign: TextAlign.center, style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          Text('Vuelve pronto por más — nunca se repite lo mismo.',
              textAlign: TextAlign.center, style: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.neutralSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TarjetaTrivia extends ConsumerWidget {
  final TriviaState state;
  const _TarjetaTrivia({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final respondida = state.correcto != null;
    final esperandoRespuesta = state.opcionElegida != null && !respondida && state.errorRespuesta == null;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.categoria != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(999)),
              child: Text(state.categoria!.toUpperCase(),
                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.accent, letterSpacing: 0.06)),
            ),
          const SizedBox(height: 14),
          Text(state.pregunta ?? '', style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 19, fontWeight: FontWeight.w800, height: 1.3)),
          const SizedBox(height: 20),
          if (state.errorRespuesta != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(child: Text(state.errorRespuesta!, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.error))),
              ]),
            ),
          ...List.generate(state.opciones.length, (i) {
            final esElegida = state.opcionElegida == i;
            final esCorrecta = state.respuestaCorrecta == i;
            Color borderColor = AppColors.outlineVariant.withOpacity(0.4);
            Color bgColor = Colors.white;
            IconData? trailingIcon;
            Color? trailingColor;
            if (respondida) {
              if (esCorrecta) {
                borderColor = AppColors.success;
                bgColor = AppColors.successLight;
                trailingIcon = Icons.check_circle_rounded;
                trailingColor = AppColors.success;
              } else if (esElegida) {
                borderColor = AppColors.error;
                bgColor = AppColors.errorContainer;
                trailingIcon = Icons.cancel_rounded;
                trailingColor = AppColors.error;
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: (respondida || esperandoRespuesta) ? null : () => ref.read(triviaProvider.notifier).responder(i),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor, width: esElegida || esCorrecta ? 1.5 : 1)),
                  child: Row(
                    children: [
                      Expanded(child: Text(state.opciones[i], style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w600))),
                      if (esperandoRespuesta && esElegida)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      else if (trailingIcon != null)
                        Icon(trailingIcon, color: trailingColor, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (respondida && state.explicacion != null && state.explicacion!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: AppColors.neutralSecondary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.explicacion!, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, height: 1.4))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 90),
        ],
      ),
    );
  }
}
