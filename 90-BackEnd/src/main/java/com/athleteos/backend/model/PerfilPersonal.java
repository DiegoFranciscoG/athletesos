package com.athleteos.backend.model;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.util.UUID;
import java.math.BigDecimal;

@Entity
@Table(name = "perfil_personal")
@Data
@NoArgsConstructor
public class PerfilPersonal {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;

    @OneToOne
    @JoinColumn(name = "usuario_id", referencedColumnName = "id", nullable = false, unique = true)
    private Usuario usuario;

    @Column(nullable = false)
    private String nombre;

    @Column(name = "avatar_url")
    private String avatarUrl;

    @Column(name = "objetivo_principal")
    private String objetivoPrincipal;

    @Column(name = "fecha_nacimiento")
    private LocalDate fechaNacimiento;

    @Column(name = "altura_cm")
    private BigDecimal alturaCm;

    @Column(name = "peso_kg")
    private BigDecimal pesoKg;

    @Column(name = "horas_sueno_objetivo")
    private BigDecimal horasSuenoObjetivo;

    @Column(name = "created_at", insertable = false, updatable = false)
    private ZonedDateTime createdAt;

    @Column(name = "updated_at", insertable = false, updatable = false)
    private ZonedDateTime updatedAt;
}
