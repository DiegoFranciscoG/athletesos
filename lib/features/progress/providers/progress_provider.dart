import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

class ProgressState {
  final bool isLoading;
  final bool hasActivePlan;
  final Map<String, int> rachas; // tipo -> racha_actual
  final String? error;

  const ProgressState({
    this.isLoading = true,
    this.hasActivePlan = false,
    this.rachas = const {},
    this.error,
  });

  ProgressState copyWith({bool? isLoading, bool? hasActivePlan, Map<String, int>? rachas, String? error}) {
    return ProgressState(
      isLoading: isLoading ?? this.isLoading,
      hasActivePlan: hasActivePlan ?? this.hasActivePlan,
      rachas: rachas ?? this.rachas,
      error: error,
    );
  }
}

class ProgressNotifier extends StateNotifier<ProgressState> {
  ProgressNotifier() : super(const ProgressState()) {
    fetchProgress();
  }

  Future<void> fetchProgress() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await dioClient.dio.get('/progress/resumen');
      final resumen = response.data as Map<String, dynamic>;

      if (resumen['hasActivePlan'] != true) {
        state = const ProgressState(isLoading: false, hasActivePlan: false);
        return;
      }

      final rachasList = (resumen['rachas'] as List<dynamic>? ?? []);
      final rachas = <String, int>{
        for (final r in rachasList) (r['tipo'] as String): (r['racha_actual'] as num).toInt(),
      };

      state = ProgressState(isLoading: false, hasActivePlan: true, rachas: rachas);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'No se pudo cargar tu progreso');
    }
  }
}

final progressProvider = StateNotifierProvider<ProgressNotifier, ProgressState>((ref) {
  return ProgressNotifier();
});
