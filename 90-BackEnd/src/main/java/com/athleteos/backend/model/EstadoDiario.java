package com.athleteos.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.util.UUID;

@Entity
@Table(name = "estado_diario")
@Data
@NoArgsConstructor
public class EstadoDiario {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;

    @Column(name = "usuario_id", nullable = false)
    private UUID usuarioId;

    @Column(nullable = false)
    private LocalDate fecha = LocalDate.now();

    private Short energia;
    private Short fatiga;
    private Short estres;

    @Column(name = "horas_sueno")
    private java.math.BigDecimal horasSueno;

    private String comentario;

    @Column(name = "created_at", insertable = false, updatable = false)
    private ZonedDateTime createdAt;
}
