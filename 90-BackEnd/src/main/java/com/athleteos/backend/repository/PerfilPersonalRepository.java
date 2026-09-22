package com.athleteos.backend.repository;

import com.athleteos.backend.model.PerfilPersonal;
import com.athleteos.backend.model.Usuario;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
import java.util.UUID;

public interface PerfilPersonalRepository extends JpaRepository<PerfilPersonal, UUID> {
    Optional<PerfilPersonal> findByUsuario(Usuario usuario);
}
