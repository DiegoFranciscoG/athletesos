import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/notifications/notification_service.dart';

class NotificationConfigState {
  final bool isLoading;
  final List<Map<String, dynamic>> configuracion;
  final String? error;

  const NotificationConfigState({this.isLoading = true, this.configuracion = const [], this.error});

  NotificationConfigState copyWith({bool? isLoading, List<Map<String, dynamic>>? configuracion, String? error}) {
    return NotificationConfigState(
      isLoading: isLoading ?? this.isLoading,
      configuracion: configuracion ?? this.configuracion,
      error: error,
    );
  }

  Map<String, dynamic>? categoria(String nombre) {
    for (final c in configuracion) {
      if (c['categoria'] == nombre) return c;
    }
    return null;
  }
}

class NotificationConfigNotifier extends StateNotifier<NotificationConfigState> {
  final Ref ref;
  NotificationConfigNotifier(this.ref) : super(const NotificationConfigState()) {
    fetch();
  }

  Future<void> fetch() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await dioClient.dio.get('/notificaciones/configuracion');
      final lista = List<Map<String, dynamic>>.from(response.data['configuracion'] ?? []);
      state = NotificationConfigState(isLoading: false, configuracion: lista);
      await _reprogramar();
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'No se pudo cargar la configuración de recordatorios');
    }
  }

  Future<bool> actualizar(String categoria, Map<String, dynamic> campos) async {
    try {
      final response = await dioClient.dio.put('/notificaciones/configuracion/$categoria', data: campos);
      final lista = List<Map<String, dynamic>>.from(response.data['configuracion'] ?? []);
      state = state.copyWith(configuracion: lista);
      await _reprogramar();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _reprogramar() async {
    await NotificationService.instance.reprogramarTodo(configuracion: state.configuracion);
  }
}

final notificationConfigProvider = StateNotifierProvider<NotificationConfigNotifier, NotificationConfigState>((ref) {
  return NotificationConfigNotifier(ref);
});
