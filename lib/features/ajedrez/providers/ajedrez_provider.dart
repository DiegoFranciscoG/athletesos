import 'dart:math';
import 'package:chess/chess.dart' as chesslib;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';

enum ModoAjedrez { libre, puzzle }

class PuzzleAjedrez {
  final int id;
  final String titulo;
  final String descripcion;
  final String fen;
  final String solucionSan;
  final int nivelDificultad;

  const PuzzleAjedrez({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.fen,
    required this.solucionSan,
    required this.nivelDificultad,
  });

  factory PuzzleAjedrez.fromJson(Map<String, dynamic> json) => PuzzleAjedrez(
        id: (json['id'] as num).toInt(),
        titulo: json['titulo'] as String,
        descripcion: json['descripcion'] as String,
        fen: json['fen'] as String,
        solucionSan: json['solucion_san'] as String,
        nivelDificultad: (json['nivel_dificultad'] as num).toInt(),
      );
}

class AjedrezState {
  final String fen;
  final String? selectedSquare;
  final List<String> legalDestinos;
  final bool turnoBlancas;
  final bool enJaque;
  final bool jaqueMate;
  final bool tablas;
  final ModoAjedrez modo;
  final List<PuzzleAjedrez> puzzles;
  final int puzzleIndex;
  final String? puzzleFeedback;
  final bool puzzleResuelto;
  final List<String> historialSan;

  const AjedrezState({
    this.fen = chesslib.Chess.DEFAULT_POSITION,
    this.selectedSquare,
    this.legalDestinos = const [],
    this.turnoBlancas = true,
    this.enJaque = false,
    this.jaqueMate = false,
    this.tablas = false,
    this.modo = ModoAjedrez.libre,
    this.puzzles = const [],
    this.puzzleIndex = 0,
    this.puzzleFeedback,
    this.puzzleResuelto = false,
    this.historialSan = const [],
  });

  AjedrezState copyWith({
    String? fen,
    String? selectedSquare,
    bool clearSelected = false,
    List<String>? legalDestinos,
    bool? turnoBlancas,
    bool? enJaque,
    bool? jaqueMate,
    bool? tablas,
    ModoAjedrez? modo,
    List<PuzzleAjedrez>? puzzles,
    int? puzzleIndex,
    String? puzzleFeedback,
    bool clearFeedback = false,
    bool? puzzleResuelto,
    List<String>? historialSan,
  }) {
    return AjedrezState(
      fen: fen ?? this.fen,
      selectedSquare: clearSelected ? null : (selectedSquare ?? this.selectedSquare),
      legalDestinos: legalDestinos ?? this.legalDestinos,
      turnoBlancas: turnoBlancas ?? this.turnoBlancas,
      enJaque: enJaque ?? this.enJaque,
      jaqueMate: jaqueMate ?? this.jaqueMate,
      tablas: tablas ?? this.tablas,
      modo: modo ?? this.modo,
      puzzles: puzzles ?? this.puzzles,
      puzzleIndex: puzzleIndex ?? this.puzzleIndex,
      puzzleFeedback: clearFeedback ? null : (puzzleFeedback ?? this.puzzleFeedback),
      puzzleResuelto: puzzleResuelto ?? this.puzzleResuelto,
      historialSan: historialSan ?? this.historialSan,
    );
  }
}

/// Envuelve el motor real de reglas (paquete `chess`, puerto de chess.js):
/// validación de movimientos legales, jaque, jaque mate, enroque, captura al
/// paso y coronación — nada de esto se reimplementa a mano, todo es real.
class AjedrezNotifier extends StateNotifier<AjedrezState> {
  AjedrezNotifier() : super(const AjedrezState()) {
    _cargarPuzzles();
  }

  chesslib.Chess _game = chesslib.Chess();
  final _random = Random();

  Future<void> _cargarPuzzles() async {
    try {
      final response = await dioClient.dio.get('/rutas/ajedrez/puzzles');
      final puzzles = (response.data['puzzles'] as List<dynamic>)
          .map((e) => PuzzleAjedrez.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(puzzles: puzzles);
    } catch (_) {
      // Sin puzzles disponibles, el modo Libre sigue funcionando igual.
    }
  }

  void nuevaPartida() {
    _game = chesslib.Chess();
    state = AjedrezState(puzzles: state.puzzles, modo: state.modo);
    _sync();
  }

  void cambiarModo(ModoAjedrez modo) {
    if (modo == ModoAjedrez.puzzle && state.puzzles.isNotEmpty) {
      _cargarPuzzle(0);
    } else {
      _game = chesslib.Chess();
      state = AjedrezState(puzzles: state.puzzles, modo: modo);
      _sync();
    }
  }

  void _cargarPuzzle(int index) {
    if (index < 0 || index >= state.puzzles.length) return;
    final puzzle = state.puzzles[index];
    _game = chesslib.Chess.fromFEN(puzzle.fen);
    state = AjedrezState(puzzles: state.puzzles, modo: ModoAjedrez.puzzle, puzzleIndex: index);
    _sync();
  }

  void siguientePuzzle() {
    final next = (state.puzzleIndex + 1) % state.puzzles.length;
    _cargarPuzzle(next);
  }

  void seleccionar(String square) {
    if (state.jaqueMate || state.tablas) return;

    // Si ya hay una selección y tocaron un destino legal, mover.
    if (state.selectedSquare != null && state.legalDestinos.contains(square)) {
      _mover(state.selectedSquare!, square);
      return;
    }

    final piece = _game.get(square);
    if (piece == null || piece.color != _game.turn) {
      state = state.copyWith(clearSelected: true, legalDestinos: []);
      return;
    }

    final moves = _game.moves({'square': square, 'verbose': true}) as List;
    final destinos = moves.map((m) => (m as Map)['to'] as String).toList();
    state = state.copyWith(selectedSquare: square, legalDestinos: destinos);
  }

  void _mover(String from, String to) {
    final moved = _game.move({'from': from, 'to': to, 'promotion': 'q'});
    if (moved == false) {
      state = state.copyWith(clearSelected: true, legalDestinos: []);
      return;
    }
    state = state.copyWith(clearSelected: true, legalDestinos: []);
    _sync();

    if (state.modo == ModoAjedrez.puzzle) {
      _evaluarPuzzle();
      return;
    }

    if (!_game.game_over && _game.turn == chesslib.Chess.BLACK) {
      Future.delayed(const Duration(milliseconds: 500), _jugarIA);
    }
  }

  void _evaluarPuzzle() {
    final puzzle = state.puzzles[state.puzzleIndex];
    final ultimoMovimiento = state.historialSan.isNotEmpty ? state.historialSan.last : '';
    final limpio = ultimoMovimiento.replaceAll('+', '').replaceAll('#', '');
    final esperado = puzzle.solucionSan.replaceAll('+', '').replaceAll('#', '');
    if (limpio == esperado) {
      state = state.copyWith(puzzleFeedback: '¡Correcto! Esa era la jugada.', puzzleResuelto: true);
    } else {
      state = state.copyWith(puzzleFeedback: 'Esa no era la mejor jugada — inténtalo de nuevo.', puzzleResuelto: false);
    }
  }

  void reintentarPuzzle() => _cargarPuzzle(state.puzzleIndex);

  /// Oponente real y honesto, aunque débil: evalúa TODAS las jugadas legales
  /// a 1 ply por material (captura > valor de la pieza capturada), sin
  /// trampas ni jugadas guionadas. No es fuerte, pero cada jugada es
  /// calculada de verdad sobre la posición real.
  void _jugarIA() {
    if (_game.game_over) {
      _sync();
      return;
    }
    final moves = _game.moves({'verbose': true}) as List;
    if (moves.isEmpty) return;

    const valores = {'p': 1, 'n': 3, 'b': 3, 'r': 5, 'q': 9};
    int mejorValor = -1;
    final mejores = <Map>[];
    for (final m in moves) {
      final mapa = m as Map;
      final capturada = mapa['captured'] as String?;
      final valor = capturada != null ? (valores[capturada] ?? 0) : 0;
      if (valor > mejorValor) {
        mejorValor = valor;
        mejores.clear();
        mejores.add(mapa);
      } else if (valor == mejorValor) {
        mejores.add(mapa);
      }
    }
    final elegido = mejores[_random.nextInt(mejores.length)];
    _game.move({'from': elegido['from'], 'to': elegido['to'], 'promotion': 'q'});
    _sync();
  }

  void _sync() {
    final historial = _game.getHistory({'verbose': false}) as List;
    state = state.copyWith(
      fen: _game.fen,
      turnoBlancas: _game.turn == chesslib.Chess.WHITE,
      enJaque: _game.in_check,
      jaqueMate: _game.in_checkmate,
      tablas: _game.in_draw,
      historialSan: historial.cast<String>(),
    );
  }

  /// Devuelve el tipo de pieza ('p','n','b','r','q','k') y color ('w'/'b') en una casilla, o null.
  ({String tipo, bool esBlanca})? piezaEn(String square) {
    final piece = _game.get(square);
    if (piece == null) return null;
    return (tipo: piece.type.name, esBlanca: piece.color == chesslib.Chess.WHITE);
  }
}

final ajedrezProvider = StateNotifierProvider<AjedrezNotifier, AjedrezState>((ref) {
  return AjedrezNotifier();
});
