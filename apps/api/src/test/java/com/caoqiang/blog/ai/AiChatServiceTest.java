package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.ai.chat.application.dto.AiChatRequest;
import com.caoqiang.blog.ai.chat.application.dto.AiChatResponse;
import com.caoqiang.blog.ai.chat.application.service.AiChatExchangeService;
import com.caoqiang.blog.ai.chat.application.service.AiChatModelService;
import com.caoqiang.blog.ai.chat.application.service.AiChatPersistenceService;
import com.caoqiang.blog.ai.chat.application.service.AiChatService;
import com.caoqiang.blog.ai.chat.application.service.AiChatSessionService;
import com.caoqiang.blog.ai.chat.application.service.AiQuotaService;
import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.application.api.IdentityUser;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class AiChatServiceTest {

    private static final Clock FIXED_CLOCK = Clock.fixed(Instant.parse("2026-06-14T16:00:00Z"), ZoneOffset.UTC);

    @Mock
    private AiChatSessionService sessionService;

    @Mock
    private AiChatModelService modelService;

    @Mock
    private AiQuotaService quotaService;

    @Mock
    private AiChatPersistenceService persistenceService;

    private AiChatService service;
    private AuthenticatedUser principal;
    private IdentityUser identity;
    private AiChatSession session;
    private AiQuotaService.Reservation reservation;

    @BeforeEach
    void setUp() {
        BlogProperties properties = new BlogProperties();
        properties.getAi().setDailyQuestionLimit(10);
        AiChatExchangeService exchangeService =
                new AiChatExchangeService(properties, sessionService, quotaService, persistenceService);
        service =
                new AiChatService(properties, FIXED_CLOCK, sessionService, quotaService, exchangeService, modelService);

        UUID userId = UUID.randomUUID();
        principal = new AuthenticatedUser(userId, "reader@example.com", "读者", Role.USER);
        identity = new IdentityUser(
                userId, principal.email(), principal.nickname(), null, null, null, "password-hash", Role.USER, true);
        session = new AiChatSession(userId, "测试会话");
        reservation = new AiQuotaService.Reservation(userId, LocalDate.of(2026, 6, 15), 3);
    }

    @Test
    void orchestratesASynchronousExchangeAndReturnsRemainingLimits() {
        stubUserAndReservation();
        when(sessionService.resolveForChat(identity, session.getId()))
                .thenReturn(new AiChatSessionService.ResolvedSession(session, 4, List.of()));
        when(modelService.generateAnswer("问题", List.of(), principal)).thenReturn("模型回答");
        when(persistenceService.persistExchange(identity.id(), session.getId(), "问题", "模型回答", 40))
                .thenReturn(6L);

        AiChatResponse response = service.chat(principal, new AiChatRequest(session.getId(), "  问题  "));

        assertThat(response.sessionId()).isEqualTo(session.getId());
        assertThat(response.answer()).isEqualTo("模型回答");
        assertThat(response.remainingQuestions()).isEqualTo(7);
        assertThat(response.remainingMessages()).isEqualTo(34);
        verify(persistenceService).persistExchange(identity.id(), session.getId(), "问题", "模型回答", 40);
        verify(quotaService, never()).release(any());
    }

    @Test
    void releasesReservedQuotaWhenTheSessionHasNoRoomForAnExchange() {
        stubUserAndReservation();
        when(sessionService.resolveForChat(identity, session.getId()))
                .thenReturn(new AiChatSessionService.ResolvedSession(session, 39, List.of()));

        assertThatThrownBy(() -> service.chat(principal, new AiChatRequest(session.getId(), "问题")))
                .isInstanceOfSatisfying(BusinessException.class, error -> {
                    assertThat(error.status()).isEqualTo(HttpStatus.CONFLICT);
                    assertThat(error.getMessage()).contains("消息数已达上限");
                });

        verify(quotaService).release(reservation);
        verifyNoInteractions(modelService, persistenceService);
    }

    @Test
    void releasesReservedQuotaWhenTheModelFails() {
        stubUserAndReservation();
        when(sessionService.resolveForChat(identity, session.getId()))
                .thenReturn(new AiChatSessionService.ResolvedSession(session, 2, List.of()));
        when(modelService.generateAnswer("问题", List.of(), principal))
                .thenThrow(new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "AI 服务暂时不可用"));

        assertThatThrownBy(() -> service.chat(principal, new AiChatRequest(session.getId(), "问题")))
                .isInstanceOfSatisfying(BusinessException.class, error -> {
                    assertThat(error.status()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
                    assertThat(error.getMessage()).isEqualTo("AI 服务暂时不可用");
                });

        verify(quotaService).release(reservation);
        verifyNoInteractions(persistenceService);
    }

    @Test
    void reportsQuotaUsingTheConfiguredUtcPlusEightBoundary() {
        when(sessionService.requireActiveUser(principal)).thenReturn(identity);
        when(quotaService.used(identity.id())).thenReturn(4);

        var response = service.quota(principal);

        assertThat(response.date()).isEqualTo(LocalDate.of(2026, 6, 15));
        assertThat(response.dailyLimit()).isEqualTo(10);
        assertThat(response.used()).isEqualTo(4);
        verify(quotaService, never()).reserve(any(), anyInt());
    }

    private void stubUserAndReservation() {
        when(sessionService.requireActiveUser(principal)).thenReturn(identity);
        when(quotaService.reserve(identity.id(), 10)).thenReturn(reservation);
    }
}
