package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.shared.exception.BusinessException;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AiQuotaService {

    private static final ZoneOffset QUOTA_ZONE = ZoneOffset.ofHours(8);

    private static final String RESERVE_SQL = """
            INSERT INTO ai_daily_quotas
                (id, user_id, quota_date, question_count, created_at, updated_at)
            VALUES (?, ?, ?, 1, now(), now())
            ON CONFLICT (user_id, quota_date) DO UPDATE
            SET question_count = ai_daily_quotas.question_count + 1,
                updated_at = now()
            WHERE ai_daily_quotas.question_count < ?
            RETURNING question_count
            """;

    private final JdbcTemplate jdbcTemplate;
    private final Clock clock;

    public AiQuotaService(JdbcTemplate jdbcTemplate, Clock clock) {
        this.jdbcTemplate = jdbcTemplate;
        this.clock = clock;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Reservation reserve(UUID userId, int dailyLimit) {
        if (dailyLimit <= 0) {
            throw new BusinessException(HttpStatus.TOO_MANY_REQUESTS, "今日 AI 提问次数已用完");
        }
        LocalDate today = today();
        List<Integer> counts = jdbcTemplate.query(
                RESERVE_SQL,
                (resultSet, rowNum) -> resultSet.getInt(1),
                UUID.randomUUID(),
                userId,
                today,
                dailyLimit
        );
        if (counts.isEmpty()) {
            throw new BusinessException(HttpStatus.TOO_MANY_REQUESTS, "今日 AI 提问次数已用完");
        }
        return new Reservation(userId, today, counts.getFirst());
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void release(Reservation reservation) {
        jdbcTemplate.update(
                """
                UPDATE ai_daily_quotas
                SET question_count = greatest(question_count - 1, 0),
                    updated_at = now()
                WHERE user_id = ? AND quota_date = ?
                """,
                reservation.userId(),
                reservation.quotaDate()
        );
    }

    @Transactional(readOnly = true)
    public int used(UUID userId) {
        LocalDate today = today();
        Integer count = jdbcTemplate.queryForObject(
                """
                SELECT coalesce(max(question_count), 0)
                FROM ai_daily_quotas
                WHERE user_id = ? AND quota_date = ?
                """,
                Integer.class,
                userId,
                today
        );
        return count != null ? count : 0;
    }

    private LocalDate today() {
        return LocalDate.now(clock.withZone(QUOTA_ZONE));
    }

    public record Reservation(UUID userId, LocalDate quotaDate, int used) {
    }
}
