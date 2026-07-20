package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.ai.chat.domain.model.AiChatMessage;
import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.ai.chat.domain.model.AiMessageRole;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatMessageRepository;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatSessionRepository;
import com.caoqiang.blog.ai.chat.event.AiChatMessagesCreatedEvent;
import com.caoqiang.blog.shared.domain.event.DomainEventPublisher;
import com.caoqiang.blog.shared.exception.BusinessException;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AiChatPersistenceService {

    private final AiChatSessionRepository sessionRepository;
    private final AiChatMessageRepository messageRepository;
    private final DomainEventPublisher domainEventPublisher;

    public AiChatPersistenceService(
            AiChatSessionRepository sessionRepository,
            AiChatMessageRepository messageRepository,
            DomainEventPublisher domainEventPublisher) {
        this.sessionRepository = sessionRepository;
        this.messageRepository = messageRepository;
        this.domainEventPublisher = domainEventPublisher;
    }

    @Transactional
    public long persistExchange(
            UUID userId, UUID sessionId, String userMessage, String assistantMessage, int maxMessages) {
        AiChatSession session = sessionRepository
                .findForUpdate(sessionId, userId)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));

        long messageCount = messageRepository.countBySessionIdAndDeletedFalse(sessionId);
        if (messageCount + 2 > maxMessages) {
            throw new BusinessException(HttpStatus.CONFLICT, "该会话消息数已达上限，请创建新会话");
        }

        AiChatMessage userMsg = messageRepository.save(new AiChatMessage(session, AiMessageRole.USER, userMessage));
        AiChatMessage assistantMsg =
                messageRepository.save(new AiChatMessage(session, AiMessageRole.ASSISTANT, assistantMessage));
        session.touch();
        domainEventPublisher.publishEvent(
                new AiChatMessagesCreatedEvent(List.of(userMsg.getId(), assistantMsg.getId())));
        return messageCount + 2;
    }
}
