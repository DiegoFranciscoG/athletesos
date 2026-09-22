package com.athleteos.backend.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Disparador del cierre diario (job_cierre_diario en Postgres). Neon free
 * no siempre habilita pg_cron, así que el trigger viene de aquí; la lógica
 * de qué hacer sigue viviendo íntegramente en la función SQL.
 */
@Component
public class DailyJobRunner {

    private static final Logger log = LoggerFactory.getLogger(DailyJobRunner.class);

    private final JdbcTemplate jdbc;

    public DailyJobRunner(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    @Scheduled(cron = "0 5 0 * * *") // 00:05 todos los días
    public void ejecutarCierreDiario() {
        try {
            String resultado = jdbc.queryForObject("SELECT job_cierre_diario()::text", String.class);
            log.info("job_cierre_diario ejecutado: {}", resultado);
        } catch (Exception e) {
            log.error("job_cierre_diario falló", e);
        }
    }
}
