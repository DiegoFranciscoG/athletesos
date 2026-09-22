package com.athleteos.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.ZonedDateTime;
import java.util.UUID;

@Entity
@Table(name = "habito")
@Data
@NoArgsConstructor
public class Habito {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;

    @Column(name = "usuario_id", nullable = false)
    private UUID usuarioId;

    @Column(nullable = false)
    private String nombre;

    @Column(nullable = false)
    private String tipo; // AGUA | SUENO | ESTUDIO | PANTALLA | MOVILIDAD | OTRO

    private Boolean activo = true;

    @Column(name = "created_at", insertable = false, updatable = false)
    private ZonedDateTime createdAt;
}
