import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Recordatorios reales en el teléfono (agua, desconexión).
/// App de un solo usuario en Ecuador -> zona horaria fija America/Guayaquil
/// (UTC-5, sin horario de verano), evita depender de un plugin extra solo
/// para detectar la zona del dispositivo.
const _zonaLocal = 'America/Guayaquil';

// Rangos de IDs reservados para poder cancelar por categoría sin tocar las
// demás: AGUA 1000-1999, DESCONEXION fija en 3000.
const _idBaseAgua = 1000;
const _idDesconexion = 3000;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_zonaLocal));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> requestPermissions() async {
    await _android?.requestNotificationsPermission();
    await _android?.requestExactAlarmsPermission();
  }

  Future<bool> tienePermisoAlarmasExactas() async => await _android?.canScheduleExactNotifications() ?? false;

  Future<void> cancelarTodo() async => _plugin.cancelAll();

  /// Recalcula y reprograma TODOS los recordatorios a partir de la config
  /// real del usuario. Se llama al iniciar sesión y cada vez que se guarda
  /// un cambio en Ajustes — siempre cancela y vuelve a programar desde
  /// cero, así nunca queda un recordatorio viejo con datos obsoletos.
  Future<void> reprogramarTodo({required List<Map<String, dynamic>> configuracion}) async {
    if (!_initialized) await init();

    final agua = _buscarCategoria(configuracion, 'AGUA');
    final desconexion = _buscarCategoria(configuracion, 'DESCONEXION');

    await _cancelarRango(_idBaseAgua, 999);
    if (agua != null && agua['activa'] == true) {
      await _programarAgua(agua);
    }

    await _plugin.cancel(_idDesconexion);
    if (desconexion != null && desconexion['activa'] == true) {
      await _programarDesconexion(desconexion);
    }
  }

  Map<String, dynamic>? _buscarCategoria(List<Map<String, dynamic>> configuracion, String categoria) {
    for (final c in configuracion) {
      if (c['categoria'] == categoria) return c;
    }
    return null;
  }

  Future<void> _cancelarRango(int base, int cantidad) async {
    for (var i = 0; i <= cantidad; i++) {
      await _plugin.cancel(base + i);
    }
  }

  Future<void> _programarAgua(Map<String, dynamic> config) async {
    final horaInicio = _parseHora(config['hora_inicio'] as String?);
    final horaFin = _parseHora(config['hora_fin'] as String?);
    final intervalo = (config['intervalo_min'] as num?)?.toInt() ?? 60;
    if (horaInicio == null || horaFin == null || intervalo <= 0) return;

    var minutos = horaInicio.$1 * 60 + horaInicio.$2;
    final minutosFin = horaFin.$1 * 60 + horaFin.$2;
    var id = _idBaseAgua;
    final vibra = config['vibracion'] != false;
    final suena = config['sonido'] != false;

    while (minutos <= minutosFin && id < _idBaseAgua + 200) {
      final hora = minutos ~/ 60;
      final minuto = minutos % 60;
      await _programarDiaria(
        id: id,
        titulo: 'Hidratación',
        cuerpo: 'Toca un vaso de agua ahora — mantén el ritmo.',
        hora: hora,
        minuto: minuto,
        vibra: vibra,
        suena: suena,
        canalId: 'agua',
        canalNombre: 'Hidratación',
      );
      id++;
      minutos += intervalo;
    }
  }

  Future<void> _programarDesconexion(Map<String, dynamic> config) async {
    final hora = _parseHora(config['hora_fija'] as String?);
    if (hora == null) return;
    await _programarDiaria(
      id: _idDesconexion,
      titulo: 'Desconexión',
      cuerpo: 'Hora de bajar el ritmo — pantallas fuera, prepara el sueño.',
      hora: hora.$1,
      minuto: hora.$2,
      vibra: config['vibracion'] != false,
      suena: config['sonido'] != false,
      canalId: 'desconexion',
      canalNombre: 'Desconexión',
    );
  }

  Future<void> _programarDiaria({
    required int id,
    required String titulo,
    required String cuerpo,
    required int hora,
    required int minuto,
    required bool vibra,
    required bool suena,
    required String canalId,
    required String canalNombre,
  }) async {
    var momento = tz.TZDateTime.now(tz.local);
    momento = tz.TZDateTime(tz.local, momento.year, momento.month, momento.day, hora, minuto);
    if (momento.isBefore(tz.TZDateTime.now(tz.local))) {
      momento = momento.add(const Duration(days: 1));
    }
    try {
      await _plugin.zonedSchedule(
        id,
        titulo,
        cuerpo,
        momento,
        NotificationDetails(
          android: AndroidNotificationDetails(
            canalId,
            canalNombre,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            enableVibration: vibra,
            playSound: suena,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      if (kDebugMode) print('No se pudo programar notificación $id: $e');
    }
  }

  /// Devuelve (hora, minuto) a partir de "HH:MM" o "HH:MM:SS". Null si no es válido.
  (int, int)? _parseHora(String? valor) {
    if (valor == null) return null;
    final partes = valor.split(':');
    if (partes.length < 2) return null;
    final h = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    if (h == null || m == null) return null;
    return (h, m);
  }
}
