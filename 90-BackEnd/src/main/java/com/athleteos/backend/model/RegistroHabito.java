package com.athleteos.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.util.UUID;

@Entity
@Table(name = "registro_habito")
@Data
@NoArgsConstructor
public class RegistroHabito {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;

    @Column(name = "usuario_id", nullable = false)
    private UUID usuarioId;

    @Column(name = "habito_id", nullable = false)
    private UUID habitoId;

    @Column(nullable = false)
    private LocalDate fecha = LocalDate.now();

    private Boolean completado = true;

    @Column(name = "created_at", insertable = false, updatable = false)
    private ZonedDateTime createdAt;
}
