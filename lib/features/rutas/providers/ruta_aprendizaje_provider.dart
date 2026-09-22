import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

class TemaRuta {
  final String temaId;
  final String? padreId;
  final String codigo;
  final String nombre;
  final String descripcion;
  final int orden;
  final int nivelDificultad;
  final String? videoUrl;
  final String? videoTitulo;
  final String? contenido;
  final String fuenteUrl;
  final bool esSubtema;
  final String estado; // BLOQUEADO | DISPONIBLE | EN_PROGRESO | COMPLETADO
  final int? seriesBase;
  final int? repeticionesBase;
  final int? duracionSeg;
  final int? descansoSeg;

  const TemaRuta({
    required this.temaId,
    required this.padreId,
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.orden,
    required this.nivelDificultad,
    required this.videoUrl,
    required this.videoTitulo,
    required this.contenido,
    required this.fuenteUrl,
    required this.esSubtema,
    required this.estado,
    this.seriesBase,
    this.repeticionesBase,
    this.duracionSeg,
    this.descansoSeg,
  });

  /// Texto listo para mostrar la prescripción tras el video (null si es un
  /// tema teórico sin series/reps, como ajedrez).
  String? get secuenciaTexto {
    if (seriesBase == null) return null;
    final partes = <String>[];
    if (repeticionesBase != null) {
      partes.add('$seriesBase series x $repeticionesBase reps');
    } else if (duracionSeg != null) {
      partes.add('$seriesBase rondas x ${duracionSeg}s');
    }
    if (descansoSeg != null) partes.add('descanso ${descansoSeg}s');
    return partes.isEmpty ? null : partes.join(' · ');
  }

  factory TemaRuta.fromJson(Map<String, dynamic> json) => TemaRuta(
        temaId: json['tema_id'] as String,
        padreId: json['padre_id'] as String?,
        codigo: json['codigo'] as String,
        nombre: json['nombre'] as String,
        descripcion: json['descripcion'] as String,
        orden: (json['orden'] as num).toInt(),
        nivelDificultad: (json['nivel_dificultad'] as num).toInt(),
        videoUrl: json['video_url'] as String?,
        videoTitulo: json['video_titulo'] as String?,
        contenido: json['contenido'] as String?,
        fuenteUrl: json['fuente_url'] as String,
        esSubtema: json['es_subtema'] as bool,
        estado: json['estado'] as String,
        seriesBase: (json['series_base'] as num?)?.toInt(),
        repeticionesBase: (json['repeticiones_base'] as num?)?.toInt(),
        duracionSeg: (json['duracion_seg'] as num?)?.toInt(),
        descansoSeg: (json['descanso_seg'] as num?)?.toInt(),
      );
}

class RutaAprendizajeState {
  final bool isLoading;
  final List<TemaRuta> temas;
  final String? error;

  const RutaAprendizajeState({this.isLoading = true, this.temas = const [], this.error});

  RutaAprendizajeState copyWith({bool? isLoading, List<TemaRuta>? temas, String? error}) {
    return RutaAprendizajeState(
      isLoading: isLoading ?? this.isLoading,
      temas: temas ?? this.temas,
      error: error,
    );
  }

  List<TemaRuta> get raiz => temas.where((t) => !t.esSubtema).toList()..sort((a, b) => a.orden.compareTo(b.orden));

  List<TemaRuta> subtemasDe(String temaId) =>
      temas.where((t) => t.esSubtema && t.padreId == temaId).toList()..sort((a, b) => a.orden.compareTo(b.orden));
}

class RutaAprendizajeNotifier extends StateNotifier<RutaAprendizajeState> {
  final String dominio;
  RutaAprendizajeNotifier(this.dominio) : super(const RutaAprendizajeState()) {
    cargar();
  }

  Future<void> cargar() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await dioClient.dio.get('/rutas/$dominio');
      final temas = (response.data['temas'] as List<dynamic>)
          .map((e) => TemaRuta.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(isLoading: false, temas: temas);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'No se pudo cargar la ruta de aprendizaje.');
    }
  }

  Future<bool> completarTema(String temaId) async {
    try {
      await dioClient.dio.post('/rutas/temas/$temaId/completar');
      await cargar();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final rutaAprendizajeProvider =
    StateNotifierProvider.family<RutaAprendizajeNotifier, RutaAprendizajeState, String>((ref, dominio) {
  return RutaAprendizajeNotifier(dominio);
});
