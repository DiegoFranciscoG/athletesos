import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/network/dio_client.dart';
import '../../../auth/providers/auth_provider.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  bool _loading = true;
  List<dynamic> _configIntensidad = [];
  List<dynamic> _configNivel = [];
  List<dynamic> _auditoria = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        dioClient.dio.get('/admin/config/intensidad'),
        dioClient.dio.get('/admin/config/nivel'),
        dioClient.dio.get('/admin/auditoria', queryParameters: {'limit': 30}),
      ]);
      setState(() {
        _configIntensidad = results[0].data['config'] ?? [];
        _configNivel = results[1].data['config'] ?? [];
        _auditoria = results[2].data['eventos'] ?? [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar el panel admin (¿tu cuenta tiene rol ADMIN?)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authProvider).profile;
    if (profile != null && !profile.isAdmin) {
      return Scaffold(
        appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop())),
        body: Center(
          child: Text('Esta sección es solo para el rol ADMIN.', style: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.neutralSecondary)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: AppColors.onSurface), onPressed: () => context.pop()),
        title: Text('Panel Admin', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, color: AppColors.onSurface)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.error)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _SectionTitle('Configuración de Intensidad (motor de plan)'),
                    ..._configIntensidad.map((c) => _ConfigRow(
                          title: '${c['intensidad']} · ${c['area']}',
                          subtitle: '${c['sesiones_semana']}x/sem · ${c['duracion_min']}min · ${c['series_base']}x${c['repeticiones_base']} · desc ${c['descanso_seg']}s',
                        )),
                    const SizedBox(height: 20),
                    _SectionTitle('Configuración de Nivel (dificultad)'),
                    ..._configNivel.map((c) => _ConfigRow(
                          title: '${c['nivel']} · ${c['area']}',
                          subtitle: 'dificultad máx ${c['dificultad_max']} · progresión ${c['progresion_semanal_pct']}%/sem',
                        )),
                    const SizedBox(height: 20),
                    _SectionTitle('Auditoría reciente'),
                    if (_auditoria.isEmpty)
                      Text('Sin eventos todavía.', style: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.neutralSecondary, fontSize: 13))
                    else
                      ..._auditoria.map((a) => _ConfigRow(title: '${a['tabla']} · ${a['operacion']}', subtitle: '${a['created_at']}')),
                    const SizedBox(height: 100),
                  ],
                ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.04)),
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final String title;
  final String subtitle;
  const _ConfigRow({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.onSurface)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: AppColors.neutralSecondary)),
        ],
      ),
    );
  }
}
