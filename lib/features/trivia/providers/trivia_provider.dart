import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

class TriviaState {
  final bool isLoading;
  final bool agotado;
  final int? id;
  final String? pregunta;
  final List<String> opciones;
  final String? categoria;
  final int? opcionElegida;
  final bool? correcto;
  final int? respuestaCorrecta;
  final String? explicacion;
  final String? error;
  final String? errorRespuesta;

  const TriviaState({
    this.isLoading = true,
    this.agotado = false,
    this.id,
    this.pregunta,
    this.opciones = const [],
    this.categoria,
    this.opcionElegida,
    this.correcto,
    this.respuestaCorrecta,
    this.explicacion,
    this.error,
    this.errorRespuesta,
  });

  TriviaState copyWith({
    int? opcionElegida,
    bool clearOpcionElegida = false,
    bool? correcto,
    int? respuestaCorrecta,
    String? explicacion,
    String? errorRespuesta,
    bool clearErrorRespuesta = false,
  }) {
    return TriviaState(
      isLoading: isLoading,
      agotado: agotado,
      id: id,
      pregunta: pregunta,
      opciones: opciones,
      categoria: categoria,
      opcionElegida: clearOpcionElegida ? null : (opcionElegida ?? this.opcionElegida),
      correcto: correcto ?? this.correcto,
      respuestaCorrecta: respuestaCorrecta ?? this.respuestaCorrecta,
      explicacion: explicacion ?? this.explicacion,
      errorRespuesta: clearErrorRespuesta ? null : (errorRespuesta ?? this.errorRespuesta),
    );
  }
}

class TriviaNotifier extends StateNotifier<TriviaState> {
  TriviaNotifier() : super(const TriviaState()) {
    siguiente();
  }

  Future<void> siguiente() async {
    state = const TriviaState(isLoading: true);
    try {
      final response = await dioClient.dio.get('/aprendizaje/trivia-nueva');
      final data = response.data as Map<String, dynamic>;
      if (data['agotado'] == true) {
        state = const TriviaState(isLoading: false, agotado: true);
        return;
      }
      state = TriviaState(
        isLoading: false,
        id: (data['id'] as num?)?.toInt(),
        pregunta: data['pregunta'] as String?,
        opciones: List<String>.from(data['opciones'] ?? []),
        categoria: data['categoria'] as String?,
      );
    } catch (_) {
      state = const TriviaState(isLoading: false, error: 'No se pudo cargar una pregunta nueva.');
    }
  }

  Future<void> responder(int opcion) async {
    if (state.id == null || state.opcionElegida != null) return;
    state = state.copyWith(opcionElegida: opcion, clearErrorRespuesta: true);
    try {
      final response = await dioClient.dio.post('/aprendizaje/trivia/${state.id}/responder', data: {'opcionElegida': opcion});
      final data = response.data as Map<String, dynamic>;
      state = state.copyWith(
        correcto: data['correcto'] as bool?,
        respuestaCorrecta: (data['respuestaCorrecta'] as num?)?.toInt(),
        explicacion: data['explicacion'] as String?,
      );
    } catch (_) {
      // Revierte la selección para que el usuario pueda volver a tocar una
      // opción — sin esto, un fallo de red dejaba la tarjeta en rojo sin
      // explicación y sin forma de reintentar (bug real visto en dispositivo).
      state = state.copyWith(clearOpcionElegida: true, errorRespuesta: 'No se pudo enviar tu respuesta. Toca de nuevo.');
    }
  }
}

final triviaProvider = StateNotifierProvider.autoDispose<TriviaNotifier, TriviaState>((ref) {
  return TriviaNotifier();
});
