import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/youtube_player_sheet.dart';
import '../../providers/ruta_aprendizaje_provider.dart';

const _dominioTitulo = {
  'calistenia': 'Calistenia en casa',
  'ajedrez': 'Ajedrez',
  'boxeo': 'Boxeo',
  'karate': 'Karate',
  'conocimiento': 'Conocimiento',
};

class RutaAprendizajeScreen extends ConsumerWidget {
  final String dominio;
  const RutaAprendizajeScreen({super.key, required this.dominio});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = rutaAprendizajeProvider(dominio);
    final state = ref.watch(provider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(_dominioTitulo[dominio] ?? dominio,
            style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        actions: [
          if (dominio == 'ajedrez')
            TextButton.icon(
              onPressed: () => context.push('/ajedrez'),
              icon: const Icon(Icons.sports_esports_rounded, size: 18),
              label: const Text('Jugar'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text(state.error!, style: const TextStyle(fontFamily: 'PlusJakartaSans')))
              : state.raiz.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Esta ruta todavía no tiene contenido — próximamente.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.neutralSecondary)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.raiz.length,
                      itemBuilder: (context, i) {
                        final tema = state.raiz[i];
                        final subtemas = state.subtemasDe(tema.temaId);
                        final completados = subtemas.where((s) => s.estado == 'COMPLETADO').length;
                        return _TemaCard(
                          tema: tema,
                          subtemas: subtemas,
                          completados: completados,
                          onCompletar: (subtemaId) async {
                            final ok = await ref.read(provider.notifier).completarTema(subtemaId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(ok ? '¡Completado! Sigue con el siguiente.' : 'No se pudo guardar, intenta de nuevo.')),
                              );
                            }
                          },
                        );
                      },
                    ),
    );
  }
}

class _TemaCard extends StatelessWidget {
  final TemaRuta tema;
  final List<TemaRuta> subtemas;
  final int completados;
  final Future<void> Function(String subtemaId) onCompletar;

  const _TemaCard({required this.tema, required this.subtemas, required this.completados, required this.onCompletar});

  @override
  Widget build(BuildContext context) {
    final total = subtemas.length;
    final completo = total > 0 && completados == total;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: completados > 0 && !completo,
          leading: Icon(
            completo ? Icons.check_circle_rounded : Icons.folder_open_rounded,
            color: completo ? AppColors.success : AppColors.primary,
          ),
          title: Text(tema.nombre, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 15)),
          subtitle: Text('$completados / $total completados',
              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.neutralSecondary)),
          children: subtemas.map((s) => _SubtemaTile(subtema: s, onCompletar: () => onCompletar(s.temaId))).toList(),
        ),
      ),
    );
  }
}

class _SubtemaTile extends StatelessWidget {
  final TemaRuta subtema;
  final VoidCallback onCompletar;
  const _SubtemaTile({required this.subtema, required this.onCompletar});

  @override
  Widget build(BuildContext context) {
    final bloqueado = subtema.estado == 'BLOQUEADO';
    final completado = subtema.estado == 'COMPLETADO';

    return ListTile(
      enabled: !bloqueado,
      leading: Icon(
        bloqueado ? Icons.lock_rounded : (completado ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded),
        color: bloqueado ? AppColors.neutralSecondary : (completado ? AppColors.success : AppColors.accent),
        size: 22,
      ),
      title: Text(subtema.nombre,
          style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: bloqueado ? AppColors.neutralSecondary : AppColors.onSurface)),
      subtitle: Row(
        children: [
          Text('Dificultad ${subtema.nivelDificultad}/5',
              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: AppColors.neutralSecondary)),
          if (subtema.videoUrl != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.videocam_rounded, size: 13, color: AppColors.neutralSecondary),
          ],
        ],
      ),
      onTap: bloqueado
          ? () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Completa el paso anterior para desbloquear este.')))
          : () => _abrirDetalle(context, subtema, onCompletar),
    );
  }

  void _abrirDetalle(BuildContext context, TemaRuta subtema, VoidCallback onCompletar) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DetalleSubtemaSheet(subtema: subtema, onCompletar: onCompletar),
    );
  }
}

class _DetalleSubtemaSheet extends StatelessWidget {
  final TemaRuta subtema;
  final VoidCallback onCompletar;
  const _DetalleSubtemaSheet({required this.subtema, required this.onCompletar});

  @override
  Widget build(BuildContext context) {
    final completado = subtema.estado == 'COMPLETADO';
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtema.nombre, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Dificultad ${subtema.nivelDificultad}/5',
              style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.neutralSecondary)),
          if (subtema.videoUrl != null) ...[
            const SizedBox(height: 14),
            YoutubeInlinePlayer(videoUrl: subtema.videoUrl!),
          ],
          const SizedBox(height: 16),
          Text(subtema.descripcion, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14)),
          if (subtema.contenido != null && subtema.contenido!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(subtema.contenido!, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, color: AppColors.onSurfaceVariant)),
          ],
          if (subtema.secuenciaTexto != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.checklist_rounded, color: AppColors.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(subtema.secuenciaTexto!,
                        style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.onSurface)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: completado ? null : () { onCompletar(); Navigator.of(context).pop(); },
              style: ElevatedButton.styleFrom(
                backgroundColor: completado ? AppColors.success : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(completado ? 'YA COMPLETADO' : 'MARCAR COMO COMPLETADO',
                  style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, letterSpacing: 0.04)),
            ),
          ),
        ],
      ),
    );
  }
}
