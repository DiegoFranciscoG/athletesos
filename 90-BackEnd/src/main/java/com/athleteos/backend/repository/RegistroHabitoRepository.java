package com.athleteos.backend.repository;

import com.athleteos.backend.model.RegistroHabito;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public interface RegistroHabitoRepository extends JpaRepository<RegistroHabito, UUID> {
    List<RegistroHabito> findByUsuarioIdAndFecha(UUID usuarioId, LocalDate fecha);
    boolean existsByHabitoIdAndFecha(UUID habitoId, LocalDate fecha);
}
