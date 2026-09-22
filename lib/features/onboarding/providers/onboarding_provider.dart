import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

class OnboardingState {
  final Set<String> dominiosSeleccionados;
  final bool isSubmitting;
  final String? error;
  final bool completado;

  const OnboardingState({
    this.dominiosSeleccionados = const {},
    this.isSubmitting = false,
    this.error,
    this.completado = false,
  });

  OnboardingState copyWith({
    Set<String>? dominiosSeleccionados,
    bool? isSubmitting,
    String? error,
    bool? completado,
  }) {
    return OnboardingState(
      dominiosSeleccionados: dominiosSeleccionados ?? this.dominiosSeleccionados,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
      completado: completado ?? this.completado,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void alternarDominio(String dominio) {
    final nuevos = Set<String>.from(state.dominiosSeleccionados);
    if (nuevos.contains(dominio)) {
      nuevos.remove(dominio);
    } else {
      nuevos.add(dominio);
    }
    state = state.copyWith(dominiosSeleccionados: nuevos);
  }

  bool get puedeEnviar => state.dominiosSeleccionados.isNotEmpty;

  Future<bool> completar() async {
    if (!puedeEnviar) return false;
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await dioClient.dio.post('/onboarding/completar-aprendizaje');
      state = state.copyWith(isSubmitting: false, completado: true);
      return true;
    } catch (_) {
      state = state.copyWith(isSubmitting: false, error: 'No se pudo iniciar tu ruta. Intenta de nuevo.');
      return false;
    }
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
