package com.athleteos.backend.repository;

import com.athleteos.backend.model.Habito;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface HabitoRepository extends JpaRepository<Habito, UUID> {
    List<Habito> findByUsuarioIdAndActivoTrue(UUID usuarioId);
}
