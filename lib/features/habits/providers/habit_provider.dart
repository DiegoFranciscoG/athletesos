import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

class Habito {
  final String id;
  final String nombre;
  final String tipo;
  final bool completadoHoy;

  Habito({required this.id, required this.nombre, required this.tipo, required this.completadoHoy});

  factory Habito.fromJson(Map<String, dynamic> json) => Habito(
        id: json['id'].toString(),
        nombre: json['nombre'] as String,
        tipo: json['tipo'] as String,
        completadoHoy: json['completadoHoy'] as bool? ?? false,
      );
}

class HabitState {
  final bool isLoading;
  final List<Habito> habitos;
  final String? error;

  const HabitState({this.isLoading = true, this.habitos = const [], this.error});

  HabitState copyWith({bool? isLoading, List<Habito>? habitos, String? error}) {
    return HabitState(isLoading: isLoading ?? this.isLoading, habitos: habitos ?? this.habitos, error: error);
  }

  int get completadosHoy => habitos.where((h) => h.completadoHoy).length;
}

class HabitNotifier extends StateNotifier<HabitState> {
  HabitNotifier() : super(const HabitState()) {
    fetch();
  }

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await dioClient.dio.get('/habits');
      final lista = (response.data['habitos'] as List<dynamic>).map((h) => Habito.fromJson(h as Map<String, dynamic>)).toList();
      state = state.copyWith(isLoading: false, habitos: lista);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'No se pudieron cargar tus hábitos');
    }
  }

  Future<bool> completar(String habitoId) async {
    try {
      await dioClient.dio.post('/habits/$habitoId/completar');
      await fetch();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> crear(String nombre) async {
    try {
      await dioClient.dio.post('/habits', data: {'nombre': nombre});
      await fetch();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final habitProvider = StateNotifierProvider<HabitNotifier, HabitState>((ref) {
  return HabitNotifier();
});
