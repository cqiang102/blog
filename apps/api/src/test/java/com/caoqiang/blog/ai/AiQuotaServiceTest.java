package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.ai.chat.application.service.AiQuotaService;
import com.caoqiang.blog.shared.exception.BusinessException;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentMatchers;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

@ExtendWith(MockitoExtension.class)
class AiQuotaServiceTest {

    @Mock
    private JdbcTemplate jdbcTemplate;

    @Test
    void releaseUsesTheDateCapturedByTheReservation() {
        Clock clock = Clock.fixed(Instant.parse("2026-06-14T15:59:59Z"), ZoneOffset.UTC);
        AiQuotaService service = new AiQuotaService(jdbcTemplate, clock);
        UUID userId = UUID.randomUUID();

        when(jdbcTemplate.query(
                anyString(),
                ArgumentMatchers.<RowMapper<Integer>>any(),
                any(),
                any(),
                any(),
                any()
        )).thenReturn(List.of(3));

        AiQuotaService.Reservation reservation = service.reserve(userId, 10);
        service.release(reservation);

        assertThat(reservation.quotaDate()).isEqualTo(LocalDate.of(2026, 6, 14));
        assertThat(reservation.used()).isEqualTo(3);
        verify(jdbcTemplate).update(anyString(), eq(userId), eq(LocalDate.of(2026, 6, 14)));
    }

    @Test
    void zeroDailyLimitDoesNotCreateAQuotaRow() {
        AiQuotaService service = new AiQuotaService(jdbcTemplate, Clock.systemUTC());

        assertThatThrownBy(() -> service.reserve(UUID.randomUUID(), 0))
                .isInstanceOfSatisfying(BusinessException.class, error -> {
                    assertThat(error.status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    assertThat(error.getMessage()).isEqualTo("今日 AI 提问次数已用完");
                });
        verifyNoInteractions(jdbcTemplate);
    }
}
