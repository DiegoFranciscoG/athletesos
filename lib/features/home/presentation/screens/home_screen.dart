import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/domain_icons.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../settings/providers/notification_config_provider.dart';
import '../../../habits/providers/habit_provider.dart';
import '../../../progress/providers/progress_provider.dart';

class _RutaInfo {
  final String dominio;
  final String label;
  const _RutaInfo(this.dominio, this.label);
}

const _rutasDisponibles = [
  _RutaInfo('calistenia', 'Calistenia'),
  _RutaInfo('karate', 'Karate'),
  _RutaInfo('boxeo', 'Boxeo'),
  _RutaInfo('__ajedrez_jugar__', 'Ajedrez'),
];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final habitState = ref.watch(habitProvider);
    final progressState = ref.watch(progressProvider);
    ref.watch(notificationConfigProvider); // dispara la carga + programación de recordatorios reales
    final profile = authState.profile;
    final userName = profile?.nombre ?? 'Atleta';
    final rachaHabitos = progressState.rachas['HABITOS'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(habitProvider.notifier).fetch();
          await ref.read(progressProvider.notifier).fetchProgress();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.surface,
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 20, right: 20, bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ATHLETEOS',
                              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.1)),
                          const SizedBox(height: 2),
                          Text('Aprende',
                              style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.onSurface, letterSpacing: -0.01)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (profile?.isAdmin == true) ...[
                          IconButton(
                            icon: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.onSurface),
                            onPressed: () => context.push('/admin'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          icon: const Icon(Icons.tune_rounded, color: AppColors.onSurface),
                          onPressed: () => context.push('/ajustes'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary,
                          backgroundImage: profile?.avatarUrl != null ? NetworkImage(profile!.avatarUrl!) : null,
                          child: profile?.avatarUrl == null
                              ? Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                  style: const TextStyle(color: Colors.white, fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 14))
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _RachaCard(dias: rachaHabitos),
                  const SizedBox(height: 24),
                  Text('RUTAS DE APRENDIZAJE',
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neutralSecondary, letterSpacing: 0.08)),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.3),
                    itemCount: _rutasDisponibles.length,
                    itemBuilder: (context, i) {
                      final r = _rutasDisponibles[i];
                      final iconKey = r.dominio == '__ajedrez_jugar__' ? 'ajedrez' : r.dominio;
                      final domainIcon = domainIcons[iconKey]!;
                      return InkWell(
                        onTap: () => context.push(r.dominio == '__ajedrez_jugar__' ? '/ajedrez' : '/rutas/${r.dominio}'),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: domainIcon.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                                child: Icon(domainIcon.icon, color: domainIcon.color, size: 22),
                              ),
                              const Spacer(),
                              Text(r.label, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('CONOCIMIENTO',
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neutralSecondary, letterSpacing: 0.08)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _TarjetaConocimiento(
                          icono: Icons.menu_book_rounded,
                          color: AppColors.info,
                          titulo: 'Vocabulario',
                          onTap: () => context.push('/vocabulario'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TarjetaConocimiento(
                          icono: Icons.quiz_rounded,
                          color: AppColors.success,
                          titulo: 'Trivia',
                          onTap: () => context.push('/trivia'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('HÁBITOS DE HOY',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.neutralSecondary, letterSpacing: 0.08)),
                      Text('${habitState.completadosHoy} / ${habitState.habitos.length}',
                          style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (habitState.isLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  else if (habitState.habitos.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(12)),
                      child: Text('Sin hábitos todavía.', style: TextStyle(fontFamily: 'PlusJakartaSans', color: AppColors.neutralSecondary, fontSize: 13)),
                    )
                  else
                    ...habitState.habitos.map((h) => _HabitoRow(
                          habito: h,
                          onTap: h.completadoHoy
                              ? null
                              : () async {
                                  final ok = await ref.read(habitProvider.notifier).completar(h.id);
                                  if (!ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('No se pudo marcar el hábito. Intenta de nuevo.'), backgroundColor: AppColors.error),
                                    );
                                  }
                                },
                        )),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _mostrarDialogoNuevoHabito(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Agregar hábito', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 100),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoNuevoHabito(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nuevo hábito', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontFamily: 'PlusJakartaSans'),
          decoration: const InputDecoration(hintText: 'Ej. Leer 10 páginas'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final nombre = controller.text.trim();
              if (nombre.isEmpty) return;
              Navigator.pop(dialogContext);
              await ref.read(habitProvider.notifier).crear(nombre);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}

class _RachaCard extends StatelessWidget {
  final int dias;
  const _RachaCard({required this.dias});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8d4b00), Color(0xFFb15f00)]),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$dias ${dias == 1 ? 'día' : 'días'} seguidos',
                    style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.02)),
                Text('Racha de hábitos', style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: Colors.white.withOpacity(0.75))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaConocimiento extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final VoidCallback onTap;
  const _TarjetaConocimiento({required this.icono, required this.color, required this.titulo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icono, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(titulo, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _HabitoRow extends StatelessWidget {
  final Habito habito;
  final VoidCallback? onTap;
  const _HabitoRow({required this.habito, required this.onTap});

  static const _iconos = {
    'AGUA': Icons.water_drop_rounded,
    'SUENO': Icons.bedtime_rounded,
    'PANTALLA': Icons.phonelink_off_rounded,
    'MOVILIDAD': Icons.self_improvement_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final done = habito.completadoHoy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: done ? AppColors.success.withOpacity(0.3) : AppColors.outlineVariant.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Icon(_iconos[habito.tipo] ?? Icons.task_alt_rounded, size: 20, color: AppColors.neutralSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(habito.nombre, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13.5, fontWeight: FontWeight.w600)),
                ),
                Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: done ? AppColors.success : AppColors.neutralSecondary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
