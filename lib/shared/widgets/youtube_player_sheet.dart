import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/network/dio_client.dart';

/// Extrae el ID del video de cualquier URL real de YouTube
/// (watch?v=, youtu.be/, embed/). Devuelve null si no lo reconoce.
String? extraerYoutubeId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.host.contains('youtu.be')) {
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  }
  if (uri.host.contains('youtube.com')) {
    if (uri.pathSegments.contains('embed')) {
      final idx = uri.pathSegments.indexOf('embed');
      return idx + 1 < uri.pathSegments.length ? uri.pathSegments[idx + 1] : null;
    }
    return uri.queryParameters['v'];
  }
  return null;
}

/// Reproductor de YouTube embebido DENTRO de la app (WebView con el embed
/// oficial servido desde nuestro propio backend), como widget normal — se
/// usa directo en el layout (ej. dentro del detalle de un subtema), sin
/// requerir que el usuario toque un botón para "revelar" el video.
class YoutubeInlinePlayer extends StatefulWidget {
  final String videoUrl;
  final int? startSeconds;
  final BorderRadius borderRadius;

  const YoutubeInlinePlayer({super.key, required this.videoUrl, this.startSeconds, this.borderRadius = const BorderRadius.all(Radius.circular(14))});

  @override
  State<YoutubeInlinePlayer> createState() => _YoutubeInlinePlayerState();
}

class _YoutubeInlinePlayerState extends State<YoutubeInlinePlayer> {
  late final WebViewController _controller;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    final videoId = extraerYoutubeId(widget.videoUrl);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _cargando = false);
        },
      ));

    if (videoId != null) {
      // Navegar el WebView directo a youtube.com/embed/... (o envolverlo con
      // loadHtmlString + un baseUrl falso) dispara el Error 153/152 porque
      // YouTube valida el Referer real de la petición al iframe. Sirviendo
      // el wrapper desde nuestro propio backend (mismo origen que ya usa el
      // resto de la app) ese Referer es legítimo y el video sí reproduce
      // — verificado en Chrome real antes de aplicar este fix.
      final base = dioClient.dio.options.baseUrl; // http://host:puerto/api/v1
      final start = widget.startSeconds != null ? '&start=${widget.startSeconds}' : '';
      _controller.loadRequest(Uri.parse('$base/media/youtube-embed?v=$videoId$start'));
    } else {
      _controller.loadRequest(Uri.parse(widget.videoUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(color: Colors.black),
            WebViewWidget(controller: _controller),
            if (_cargando) const CircularProgressIndicator(color: AppColors.coral),
          ],
        ),
      ),
    );
  }
}

/// Igual que [YoutubeInlinePlayer] pero como bottom sheet con su propio
/// título y botón de cerrar — para los casos donde el video no forma parte
/// del layout normal de la pantalla (ej. un detalle que se abre aparte).
class YoutubePlayerSheet extends StatelessWidget {
  final String videoUrl;
  final String? titulo;
  final int? startSeconds;

  const YoutubePlayerSheet({super.key, required this.videoUrl, this.titulo, this.startSeconds});

  static Future<void> abrir(BuildContext context, {required String videoUrl, String? titulo, int? startSeconds}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (_) => YoutubePlayerSheet(videoUrl: videoUrl, titulo: titulo, startSeconds: startSeconds),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(titulo ?? 'Video',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'PlusJakartaSans', color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          YoutubeInlinePlayer(videoUrl: videoUrl, startSeconds: startSeconds, borderRadius: BorderRadius.zero),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
