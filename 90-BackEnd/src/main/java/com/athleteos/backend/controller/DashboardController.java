package com.athleteos.backend.controller;

import com.athleteos.backend.model.EstadoDiario;
import com.athleteos.backend.model.Usuario;
import com.athleteos.backend.repository.EstadoDiarioRepository;
import com.athleteos.backend.repository.UsuarioRepository;
import com.athleteos.backend.service.PlanEngineService;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.sql.Time;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/api/v1/dashboard")
@RequiredArgsConstructor
public class DashboardController {

    private final UsuarioRepository usuarioRepository;
    private final EstadoDiarioRepository estadoDiarioRepository;
    private final PlanEngineService planEngineService;

    @GetMapping("/home")
    public ResponseEntity<?> getHomeDashboard(Authentication authentication) {
        Usuario usuario = requireUsuario(authentication);
        HomeDashboardResponse response = new HomeDashboardResponse();

        if (!Boolean.TRUE.equals(usuario.getOnboardingCompletado())) {
            response.setHasActivePlan(false);
            response.setVigor(vigorDeHoy(usuario.getId()));
            return ResponseEntity.ok(response);
        }

        Map<String, Object> dashboard = planEngineService.getDashboard(usuario.getId());
        if (dashboard == null) {
            // El usuario completó onboarding pero el programa aún no generó el día de hoy
            // (p. ej. onboarding se hizo después del fin de los 90 días de prueba).
            response.setHasActivePlan(false);
            response.setVigor(vigorDeHoy(usuario.getId()));
            return ResponseEntity.ok(response);
        }

        response.setHasActivePlan(true);
        response.setVigor(vigorDeHoy(usuario.getId()));
        response.setDayNumber(asInt(dashboard.get("numero_dia")));
        response.setFase((String) dashboard.get("fase_nombre"));
        response.setFaseProgress(asInt(dashboard.get("fase_progreso_pct")));

        int total = asInt(dashboard.get("actividades_hoy_total"));
        int completadas = asInt(dashboard.get("actividades_hoy_completadas"));
        response.setDayCompletionPercent(total == 0 ? 0.0 : (double) completadas / total);

        Map<String, Object> actual = planEngineService.getActividadActual(usuario.getId());
        response.setActiveActivity(actual != null ? toBlock(actual) : null);

        List<Map<String, Object>> agenda = planEngineService.getAgendaHoy(usuario.getId());
        List<Object> nextBlocks = new ArrayList<>();
        for (Map<String, Object> row : agenda) {
            if ("PROXIMA".equals(row.get("estado_temporal"))) {
                nextBlocks.add(toBlock(row));
            }
        }
        response.setNextBlocks(nextBlocks);

        Map<String, Object> evaluacion = planEngineService.evaluarDia(usuario.getId(), LocalDate.now());
        String nivelCarga = (String) evaluacion.get("nivel_carga");
        if (nivelCarga != null && !"NORMAL".equals(nivelCarga)) {
            response.setHasWhyChanged(true);
            response.setWhyChangedText((String) evaluacion.get("motivo"));
        }

        return ResponseEntity.ok(response);
    }

    private int vigorDeHoy(java.util.UUID usuarioId) {
        Optional<EstadoDiario> estado = estadoDiarioRepository.findByUsuarioIdAndFecha(usuarioId, LocalDate.now());
        if (estado.isEmpty()) return 100;
        EstadoDiario e = estado.get();
        if (e.getEnergia() == null || e.getFatiga() == null || e.getEstres() == null) return 100;
        double energiaScore = e.getEnergia() * 10.0;
        double fatigaScore = (10 - e.getFatiga()) * 10.0;
        double estresScore = (10 - e.getEstres()) * 10.0;
        return (int) Math.round((energiaScore + fatigaScore + estresScore) / 3.0);
    }

    private Map<String, Object> toBlock(Map<String, Object> row) {
        String hora = formatTime(row.get("hora_inicio"));
        Object horaFinObj = row.get("hora_fin");
        String time = hora;
        if (horaFinObj != null) {
            String horaFin = formatTime(horaFinObj);
            if (!horaFin.isEmpty()) {
                time = hora + " - " + horaFin;
            }
        }
        return Map.of(
                "title", String.valueOf(row.get("titulo")),
                "time", time,
                "tipo", String.valueOf(row.get("tipo")),
                "id", String.valueOf(row.get("id"))
        );
    }

    /** El driver JDBC de Postgres puede devolver TIME como java.sql.Time o java.time.LocalTime según el camino de lectura. */
    private String formatTime(Object value) {
        if (value == null) return "";
        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("HH:mm");
        if (value instanceof Time time) return time.toLocalTime().format(fmt);
        if (value instanceof java.time.LocalTime localTime) return localTime.format(fmt);
        String text = value.toString();
        return text.length() >= 5 ? text.substring(0, 5) : text;
    }

    private int asInt(Object value) {
        if (value == null) return 0;
        if (value instanceof Number n) return n.intValue();
        return Integer.parseInt(value.toString());
    }

    private Usuario requireUsuario(Authentication authentication) {
        String email = authentication.getName();
        return usuarioRepository.findByEmail(email)
                .orElseThrow(() -> new IllegalStateException("Usuario autenticado no encontrado: " + email));
    }

    @Data
    static class HomeDashboardResponse {
        private int vigor = 100;
        private int dayNumber = 0;
        private String fase = "Onboarding pendiente";
        private int faseProgress = 0;
        private double dayCompletionPercent = 0.0;
        private boolean hasActivePlan = false;
        private Object activeActivity;
        private List<Object> nextBlocks = Collections.emptyList();
        private boolean hasWhyChanged = false;
        private String whyChangedText;
    }
}
