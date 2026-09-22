import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/notification_config_provider.dart';

class AjustesScreen extends ConsumerStatefulWidget {
  const AjustesScreen({super.key});

  @override
  ConsumerState<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends ConsumerState<AjustesScreen> {
  bool _permisoAlarmas = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.instance.requestPermissions();
      final ok = await NotificationService.instance.tienePermisoAlarmasExactas();
      if (mounted) setState(() => _permisoAlarmas = ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationConfigProvider);
    final agua = state.categoria('AGUA');
    final desconexion = state.categoria('DESCONEXION');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Ajustes', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text('RECORDATORIOS',
                    style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neutralSecondary, letterSpacing: 0.08)),
                const SizedBox(height: 12),
                if (!_permisoAlarmas)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Activa "Alarmas y recordatorios" en Ajustes del sistema para que suenen a la hora exacta.',
                            style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.onSurface)),
                      ),
                    ]),
                  ),
                if (agua != null)
                  _CategoriaCard(
                    icono: Icons.water_drop_rounded,
                    color: const Color(0xFF3B82F6),
                    titulo: 'Hidratación',
                    subtitulo: agua['activa'] == true
                        ? 'Cada ${agua['intervalo_min']} min, ${_fmt(agua['hora_inicio'])}–${_fmt(agua['hora_fin'])}'
                        : 'Desactivado',
                    activa: agua['activa'] == true,
                    onToggle: (v) => ref.read(notificationConfigProvider.notifier).actualizar('AGUA', {'activa': v}),
                    children: [
                      _FilaHora(
                        etiqueta: 'Desde',
                        hora: _fmt(agua['hora_inicio']),
                        onTap: () => _elegirHora(context, agua['hora_inicio'], (h) => ref.read(notificationConfigProvider.notifier).actualizar('AGUA', {'horaInicio': h})),
                      ),
                      _FilaHora(
                        etiqueta: 'Hasta',
                        hora: _fmt(agua['hora_fin']),
                        onTap: () => _elegirHora(context, agua['hora_fin'], (h) => ref.read(notificationConfigProvider.notifier).actualizar('AGUA', {'horaFin': h})),
                      ),
                      _FilaOpciones(
                        etiqueta: 'Cada',
                        opciones: const [30, 45, 60, 90, 120],
                        sufijo: ' min',
                        valor: (agua['intervalo_min'] as num?)?.toInt() ?? 60,
                        onSeleccionar: (v) => ref.read(notificationConfigProvider.notifier).actualizar('AGUA', {'intervaloMin': v}),
                      ),
                    ],
                  ),
                const SizedBox(height: 14),
                if (desconexion != null)
                  _CategoriaCard(
                    icono: Icons.nightlight_round,
                    color: AppColors.accent,
                    titulo: 'Desconexión',
                    subtitulo: desconexion['activa'] == true ? 'Todos los días a las ${_fmt(desconexion['hora_fija'])}' : 'Desactivado',
                    activa: desconexion['activa'] == true,
                    onToggle: (v) => ref.read(notificationConfigProvider.notifier).actualizar('DESCONEXION', {'activa': v}),
                    children: [
                      _FilaHora(
                        etiqueta: 'Hora',
                        hora: _fmt(desconexion['hora_fija']),
                        onTap: () => _elegirHora(context, desconexion['hora_fija'], (h) => ref.read(notificationConfigProvider.notifier).actualizar('DESCONEXION', {'horaFija': h})),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Cerrar sesión', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700)),
                        content: const Text('¿Seguro que quieres cerrar sesión?', style: TextStyle(fontFamily: 'PlusJakartaSans')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ref.read(authProvider.notifier).logout();
                            },
                            child: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cerrar sesión', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
    );
  }

  String _fmt(dynamic horaSql) {
    if (horaSql == null) return '--:--';
    final s = horaSql.toString();
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  Future<void> _elegirHora(BuildContext context, dynamic horaActualSql, Future<void> Function(String) onElegida) async {
    final actual = _fmt(horaActualSql);
    final partes = actual.split(':');
    final inicial = TimeOfDay(hour: int.tryParse(partes[0]) ?? 8, minute: int.tryParse(partes.length > 1 ? partes[1] : '0') ?? 0);
    final elegida = await showTimePicker(context: context, initialTime: inicial);
    if (elegida == null) return;
    final hh = elegida.hour.toString().padLeft(2, '0');
    final mm = elegida.minute.toString().padLeft(2, '0');
    await onElegida('$hh:$mm');
  }
}

class _CategoriaCard extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final bool activa;
  final ValueChanged<bool> onToggle;
  final List<Widget> children;

  const _CategoriaCard({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.activa,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4))),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icono, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(subtitulo, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.neutralSecondary)),
                  ],
                ),
              ),
              Switch(value: activa, activeThumbColor: AppColors.primary, onChanged: onToggle),
            ],
          ),
          if (activa) ...[
            const Divider(height: 24),
            ...children,
          ],
        ],
      ),
    );
  }
}

class _FilaHora extends StatelessWidget {
  final String etiqueta;
  final String hora;
  final VoidCallback onTap;
  const _FilaHora({required this.etiqueta, required this.hora, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiqueta, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.onSurface)),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(999)),
              child: Text(hora, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaOpciones extends StatelessWidget {
  final String etiqueta;
  final List<int> opciones;
  final String sufijo;
  final int valor;
  final ValueChanged<int> onSeleccionar;
  const _FilaOpciones({required this.etiqueta, required this.opciones, required this.sufijo, required this.valor, required this.onSeleccionar});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.onSurface)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: opciones.map((o) {
              final sel = o == valor;
              return GestureDetector(
                onTap: () => onSeleccionar(o),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('$o$sufijo',
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.onSurface)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
