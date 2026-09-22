package com.athleteos.backend.controller;

import com.athleteos.backend.model.PerfilPersonal;
import com.athleteos.backend.model.Usuario;
import com.athleteos.backend.repository.PerfilPersonalRepository;
import com.athleteos.backend.repository.UsuarioRepository;
import com.athleteos.backend.security.JwtUtils;
import com.athleteos.backend.service.GoogleAuthService;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.regex.Pattern;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AuthController {

    private static final Pattern EMAIL_PATTERN =
            Pattern.compile("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$");
    private static final int PASSWORD_MIN_LENGTH = 6;

    private final JwtUtils jwtUtils;
    private final UsuarioRepository usuarioRepository;
    private final PerfilPersonalRepository perfilRepository;
    private final GoogleAuthService googleAuthService;
    private final BCryptPasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    /**
     * Login alternativo con Google. Comparte la misma tabla usuario: si ya existe una
     * cuenta con ese email (creada por email+password), simplemente le asocia el
     * google_id en vez de crear un usuario nuevo — un solo usuario.id por persona.
     */
    @PostMapping("/google")
    public ResponseEntity<?> autenticarGoogle(@RequestBody TokenRequest request) {
        GoogleIdToken.Payload payload = googleAuthService.verifyToken(request.getIdToken());
        if (payload == null) {
            return ResponseEntity.status(401).body(new ErrorResponse("Token de Google inválido."));
        }

        String email = normalizarEmail(payload.getEmail());
        String googleId = payload.getSubject();
        String name = (String) payload.get("name");
        String pictureUrl = (String) payload.get("picture");

        Usuario usuario = usuarioRepository.findByEmail(email).orElseGet(() -> {
            Usuario nuevo = new Usuario();
            nuevo.setEmail(email);
            nuevo.setRol(usuarioRepository.count() == 0 ? "ADMIN" : "ATLETA");
            return usuarioRepository.save(nuevo);
        });
        if (usuario.getGoogleId() == null) {
            usuario.setGoogleId(googleId);
            usuario = usuarioRepository.save(usuario);
        }
        final Usuario usuarioFinal = usuario;

        perfilRepository.findByUsuario(usuarioFinal).orElseGet(() -> {
            PerfilPersonal perfil = new PerfilPersonal();
            perfil.setUsuario(usuarioFinal);
            perfil.setNombre(name != null ? name : email.split("@")[0]);
            perfil.setAvatarUrl(pictureUrl);
            return perfilRepository.save(perfil);
        });

        String jwt = jwtUtils.generateToken(usuario.getEmail(), usuario.getRol());
        return ResponseEntity.ok(new AuthResponse(jwt, usuario.getEmail()));
    }

    @PostMapping("/registro")
    public ResponseEntity<?> registro(@RequestBody CredencialesRequest request) {
        String email = normalizarEmail(request.getEmail());
        String error = validar(email, request.getPassword());
        if (error != null) {
            return ResponseEntity.badRequest().body(new ErrorResponse(error));
        }
        if (usuarioRepository.findByEmail(email).isPresent()) {
            return ResponseEntity.status(409).body(new ErrorResponse("Ya existe una cuenta con ese correo. Inicia sesión."));
        }

        Usuario usuario = new Usuario();
        usuario.setEmail(email);
        usuario.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        // El primer usuario del sistema queda como ADMIN automáticamente (uso personal: eres tú).
        usuario.setRol(usuarioRepository.count() == 0 ? "ADMIN" : "ATLETA");
        usuario = usuarioRepository.save(usuario);

        PerfilPersonal perfil = new PerfilPersonal();
        perfil.setUsuario(usuario);
        perfil.setNombre(email.split("@")[0]);
        perfilRepository.save(perfil);

        String jwt = jwtUtils.generateToken(usuario.getEmail(), usuario.getRol());
        return ResponseEntity.ok(new AuthResponse(jwt, usuario.getEmail()));
    }

    @PostMapping("/login")
    public ResponseEntity<?> login(@RequestBody CredencialesRequest request) {
        String email = normalizarEmail(request.getEmail());
        Usuario usuario = usuarioRepository.findByEmail(email).orElse(null);

        if (usuario == null || usuario.getPasswordHash() == null
                || !passwordEncoder.matches(request.getPassword(), usuario.getPasswordHash())) {
            return ResponseEntity.status(401).body(new ErrorResponse("Correo o contraseña incorrectos."));
        }

        String jwt = jwtUtils.generateToken(usuario.getEmail(), usuario.getRol());
        return ResponseEntity.ok(new AuthResponse(jwt, usuario.getEmail()));
    }

    private String validar(String email, String password) {
        if (email == null || !EMAIL_PATTERN.matcher(email).matches()) {
            return "Ingresa un correo válido.";
        }
        if (password == null || password.length() < PASSWORD_MIN_LENGTH) {
            return "La contraseña debe tener al menos " + PASSWORD_MIN_LENGTH + " caracteres.";
        }
        return null;
    }

    private String normalizarEmail(String email) {
        return email == null ? null : email.trim().toLowerCase();
    }

    @Data
    static class CredencialesRequest {
        private String email;
        private String password;
    }

    @Data
    static class TokenRequest {
        private String idToken;
    }

    @Data
    static class AuthResponse {
        private final String token;
        private final String email;
    }

    @Data
    static class ErrorResponse {
        private final String error;
    }
}
