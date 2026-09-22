package com.athleteos.backend.repository;

import com.athleteos.backend.model.EstadoDiario;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.Optional;
import java.util.UUID;

public interface EstadoDiarioRepository extends JpaRepository<EstadoDiario, UUID> {
    Optional<EstadoDiario> findByUsuarioIdAndFecha(UUID usuarioId, LocalDate fecha);
}
