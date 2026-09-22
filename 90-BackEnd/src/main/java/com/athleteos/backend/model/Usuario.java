package com.athleteos.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.ZonedDateTime;
import java.util.UUID;

@Entity
@Table(name = "usuario")
@Data
@NoArgsConstructor
public class Usuario {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;

    @Column(name = "google_id", unique = true)
    private String googleId;

    @Column(unique = true, nullable = false)
    private String email;

    @Column(name = "password_hash")
    private String passwordHash;

    private Boolean activo = true;

    @Column(nullable = false)
    private String rol = "ATLETA"; // ATLETA | ADMIN

    @Column(name = "nivel_habilidad")
    private String nivelHabilidad; // PRINCIPIANTE | INTERMEDIO | PROFESIONAL

    private String intensidad; // NORMAL | INTERMEDIA | INTENSA

    @Column(name = "onboarding_completado", nullable = false)
    private Boolean onboardingCompletado = false;

    @Column(name = "zona_horaria")
    private String zonaHoraria = "America/Mexico_City";

    @Column(name = "created_at", insertable = false, updatable = false)
    private ZonedDateTime createdAt;

    @Column(name = "updated_at", insertable = false, updatable = false)
    private ZonedDateTime updatedAt;

    public boolean isAdmin() {
        return "ADMIN".equals(rol);
    }
}
