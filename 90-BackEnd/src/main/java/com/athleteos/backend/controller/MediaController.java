package com.athleteos.backend.controller;

import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.regex.Pattern;

/**
 * Sirve una página HTML mínima que envuelve el embed de YouTube en un <iframe>
 * real servido desde un origen http(s) genuino. Cargar el WebView del app
 * directo a youtube.com/embed/... (vía loadRequest) o con loadHtmlString y un
 * baseUrl falso dispara el Error 153/152 ("no se permite en reproductores
 * incrustados") porque YouTube valida el Referer real de la petición al
 * iframe. Sirviendo el wrapper desde nuestro propio backend, ese Referer es
 * legítimo y el video reproduce igual que en un navegador normal.
 */
@RestController
@RequestMapping("/api/v1/media")
public class MediaController {

    private static final Pattern VIDEO_ID_PATTERN = Pattern.compile("^[a-zA-Z0-9_-]{6,20}$");

    @GetMapping(value = "/youtube-embed", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> youtubeEmbed(
            @RequestParam("v") String videoId,
            @RequestParam(value = "start", required = false) Integer start) {

        if (!VIDEO_ID_PATTERN.matcher(videoId).matches()) {
            return ResponseEntity.badRequest().body("<html><body>ID de video inválido</body></html>");
        }
        int startSeconds = start != null && start > 0 ? start : 0;

        String html = """
                <!DOCTYPE html>
                <html><head><meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>html,body{margin:0;padding:0;background:#000;height:100%%;overflow:hidden;}
                iframe{position:fixed;top:0;left:0;width:100%%;height:100%%;border:0;}</style></head>
                <body>
                <iframe src="https://www.youtube.com/embed/%s?autoplay=1&playsinline=1&rel=0&start=%d"
                  allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>
                </body></html>
                """.formatted(videoId, startSeconds);

        return ResponseEntity.ok()
                .header(HttpHeaders.CACHE_CONTROL, "no-store")
                .body(html);
    }
}
