import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/ajedrez_provider.dart';

const _filas = ['8', '7', '6', '5', '4', '3', '2', '1'];
const _columnas = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

const _glifos = {
  'w': {'p': '♙', 'n': '♘', 'b': '♗', 'r': '♖', 'q': '♕', 'k': '♔'},
  'b': {'p': '♟', 'n': '♞', 'b': '♝', 'r': '♜', 'q': '♛', 'k': '♚'},
};

class AjedrezScreen extends ConsumerWidget {
  const AjedrezScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ajedrezProvider);
    final notifier = ref.read(ajedrezProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('Ajedrez', style: TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, color: AppColors.onSurface)),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: 'Ver teoría',
            onPressed: () => context.push('/rutas/ajedrez'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Nueva partida',
            onPressed: state.modo == ModoAjedrez.libre ? notifier.nuevaPartida : notifier.reintentarPuzzle,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: _ModoTab(
                    icon: Icons.sports_esports_rounded,
                    label: 'Libre',
                    selected: state.modo == ModoAjedrez.libre,
                    onTap: () => notifier.cambiarModo(ModoAjedrez.libre),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModoTab(
                    icon: Icons.extension_rounded,
                    label: 'Puzzles',
                    selected: state.modo == ModoAjedrez.puzzle,
                    onTap: () => notifier.cambiarModo(ModoAjedrez.puzzle),
                  ),
                ),
              ],
            ),
          ),
          if (state.modo == ModoAjedrez.puzzle && state.puzzles.isNotEmpty) _PuzzleHeader(state: state, notifier: notifier),
          _EstadoPartida(state: state),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _Tablero(state: state, notifier: notifier),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ModoTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModoTab({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : AppColors.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : AppColors.onSurface),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _PuzzleHeader extends StatelessWidget {
  final AjedrezState state;
  final AjedrezNotifier notifier;
  const _PuzzleHeader({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    final puzzle = state.puzzles[state.puzzleIndex];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.amberLight)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Puzzle ${state.puzzleIndex + 1}/${state.puzzles.length}: ${puzzle.titulo}',
                      style: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                Text('Nivel ${puzzle.nivelDificultad}/5', style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 11, color: AppColors.neutralSecondary)),
              ],
            ),
            const SizedBox(height: 4),
            Text(puzzle.descripcion, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, color: AppColors.onSurfaceVariant)),
            if (state.puzzleFeedback != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(state.puzzleResuelto ? Icons.check_circle_rounded : Icons.info_rounded,
                      size: 16, color: state.puzzleResuelto ? AppColors.success : AppColors.warning),
                  const SizedBox(width: 6),
                  Expanded(child: Text(state.puzzleFeedback!, style: const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 12, fontWeight: FontWeight.w600))),
                  if (state.puzzleResuelto && state.puzzles.length > 1)
                    TextButton(onPressed: notifier.siguientePuzzle, child: const Text('Siguiente →')),
                  if (!state.puzzleResuelto)
                    TextButton(onPressed: notifier.reintentarPuzzle, child: const Text('Reintentar')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EstadoPartida extends StatelessWidget {
  final AjedrezState state;
  const _EstadoPartida({required this.state});

  @override
  Widget build(BuildContext context) {
    String texto;
    Color color;
    if (state.jaqueMate) {
      texto = '¡Jaque mate! Ganan ${state.turnoBlancas ? 'negras' : 'blancas'}';
      color = AppColors.error;
    } else if (state.tablas) {
      texto = 'Tablas';
      color = AppColors.neutralSecondary;
    } else if (state.enJaque) {
      texto = '¡Jaque a ${state.turnoBlancas ? 'blancas' : 'negras'}!';
      color = AppColors.coral;
    } else {
      texto = 'Turno: ${state.turnoBlancas ? 'Blancas' : 'Negras'}';
      color = AppColors.onSurfaceVariant;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Text(texto, style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _Tablero extends StatelessWidget {
  final AjedrezState state;
  final AjedrezNotifier notifier;
  const _Tablero({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.outline, width: 2)),
      clipBehavior: Clip.antiAlias,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
        itemCount: 64,
        itemBuilder: (context, index) {
          final row = index ~/ 8;
          final col = index % 8;
          final square = '${_columnas[col]}${_filas[row]}';
          final esClara = (row + col) % 2 == 0;
          final seleccionada = state.selectedSquare == square;
          final esDestino = state.legalDestinos.contains(square);
          final pieza = notifier.piezaEn(square);

          Color bg = esClara ? const Color(0xFFF0D9B5) : const Color(0xFFB58863);
          if (seleccionada) bg = AppColors.accent.withOpacity(0.55);

          return GestureDetector(
            onTap: () => notifier.seleccionar(square),
            child: Container(
              color: bg,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (pieza != null)
                    Text(_glifos[pieza.esBlanca ? 'w' : 'b']![pieza.tipo] ?? '',
                        style: const TextStyle(fontSize: 30, height: 1)),
                  if (esDestino && pieza == null)
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.6), shape: BoxShape.circle)),
                  if (esDestino && pieza != null)
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.coral, width: 3)),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
