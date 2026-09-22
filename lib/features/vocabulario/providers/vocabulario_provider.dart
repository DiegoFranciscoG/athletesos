import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

class PalabraState {
  final bool isLoading;
  final bool agotado;
  final String? palabra;
  final String? definicion;
  final String? ejemplo;
  final String? categoriaGramatical;
  final String? fuente;
  final String? error;

  const PalabraState({
    this.isLoading = true,
    this.agotado = false,
    this.palabra,
    this.definicion,
    this.ejemplo,
    this.categoriaGramatical,
    this.fuente,
    this.error,
  });
}

class VocabularioNotifier extends StateNotifier<PalabraState> {
  VocabularioNotifier() : super(const PalabraState()) {
    siguiente();
  }

  Future<void> siguiente() async {
    state = const PalabraState(isLoading: true);
    try {
      final response = await dioClient.dio.get('/aprendizaje/palabra-nueva');
      final data = response.data as Map<String, dynamic>;
      if (data['agotado'] == true) {
        state = const PalabraState(isLoading: false, agotado: true);
        return;
      }
      state = PalabraState(
        isLoading: false,
        palabra: data['palabra'] as String?,
        definicion: data['definicion'] as String?,
        ejemplo: data['ejemplo'] as String?,
        categoriaGramatical: data['categoria_gramatical'] as String?,
        fuente: data['fuente'] as String?,
      );
    } catch (_) {
      state = const PalabraState(isLoading: false, error: 'No se pudo cargar una palabra nueva.');
    }
  }
}

final vocabularioProvider = StateNotifierProvider.autoDispose<VocabularioNotifier, PalabraState>((ref) {
  return VocabularioNotifier();
});
