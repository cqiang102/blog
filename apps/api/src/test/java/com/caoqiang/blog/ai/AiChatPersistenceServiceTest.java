package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.ai.chat.application.service.AiChatPersistenceService;
import com.caoqiang.blog.ai.chat.domain.model.AiChatMessage;
import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatMessageRepository;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatSessionRepository;
import com.caoqiang.blog.ai.chat.event.AiChatMessagesCreatedEvent;
import com.caoqiang.blog.shared.domain.event.DomainEventPublisher;
import com.caoqiang.blog.shared.exception.BusinessException;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class AiChatPersistenceServiceTest {

    @Mock
    private AiChatSessionRepository sessionRepository;

    @Mock
    private AiChatMessageRepository messageRepository;

    @Mock
    private DomainEventPublisher domainEventPublisher;

    private AiChatPersistenceService service;
    private AiChatSession session;
    private UUID userId;

    @BeforeEach
    void setUp() {
        service = new AiChatPersistenceService(sessionRepository, messageRepository, domainEventPublisher);
        userId = UUID.randomUUID();
        session = new AiChatSession(userId, "并发测试");
    }

    @Test
    void persistsExactlyTwoMessagesAtTheLimitAndTouchesTheSession() {
        when(sessionRepository.findForUpdate(session.getId(), userId)).thenReturn(Optional.of(session));
        when(messageRepository.countBySessionIdAndDeletedFalse(session.getId())).thenReturn(38L);
        when(messageRepository.save(any(AiChatMessage.class))).thenAnswer(invocation -> invocation.getArgument(0));

        long count = service.persistExchange(userId, session.getId(), "问题", "回答", 40);

        assertThat(count).isEqualTo(40);
        assertThat(session.getUpdatedAt()).isNotNull();
        verify(messageRepository, org.mockito.Mockito.times(2)).save(any(AiChatMessage.class));
        verify(domainEventPublisher).publishEvent(any(AiChatMessagesCreatedEvent.class));
    }

    @Test
    void rejectsTheExchangeWhenOnlyOneMessageSlotRemains() {
        when(sessionRepository.findForUpdate(session.getId(), userId)).thenReturn(Optional.of(session));
        when(messageRepository.countBySessionIdAndDeletedFalse(session.getId())).thenReturn(39L);

        assertThatThrownBy(() -> service.persistExchange(userId, session.getId(), "问题", "回答", 40))
                .isInstanceOfSatisfying(BusinessException.class, error -> {
                    assertThat(error.status()).isEqualTo(HttpStatus.CONFLICT);
                    assertThat(error.getMessage()).contains("消息数已达上限");
                });

        verify(messageRepository, never()).save(any(AiChatMessage.class));
        verify(domainEventPublisher, never()).publishEvent(any());
    }
}
