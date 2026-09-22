package com.athleteos.backend.security;

import io.jsonwebtoken.Jwts;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import java.util.Date;

@Component
public class JwtUtils {

    private final SecretKey key;
    private final long expirationMs;

    public JwtUtils(
            @Value("${app.security.jwt.secret}") String secret,
            @Value("${app.security.jwt.expiration-ms}") long expirationMs) {
        byte[] keyBytes = java.util.Base64.getDecoder().decode(secret);
        // Explícito HmacSHA256 (no Keys.hmacShaKeyFor, que elige HS384/HS512 según el
        // tamaño de la clave): SecurityConfig.jwtDecoder() valida específicamente HS256,
        // y un mismatch aquí hace que CUALQUIER request autenticado falle con 401.
        this.key = new SecretKeySpec(keyBytes, "HmacSHA256");
        this.expirationMs = expirationMs;
    }

    public String generateTokenFromEmail(String email) {
        return generateToken(email, "ATLETA");
    }

    public String generateToken(String email, String rol) {
        return Jwts.builder()
                .subject(email)
                .claim("rol", rol)
                .issuedAt(new Date())
                .expiration(new Date((new Date()).getTime() + expirationMs))
                .signWith(key, Jwts.SIG.HS256)
                .compact();
    }
    
    public String getEmailFromToken(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload()
                .getSubject();
    }
}
