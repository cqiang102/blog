package com.caoqiang.blog.ai.chat.application.event;

import com.caoqiang.blog.ai.chat.application.service.AiChatAuditService;
import com.caoqiang.blog.ai.chat.event.AiChatMessagesCreatedEvent;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Starts asynchronous moderation for newly persisted AI chat messages.
 */
@Component
public class AiChatAuditEventListener {

    private final AiChatAuditService aiChatAuditService;

    public AiChatAuditEventListener(AiChatAuditService aiChatAuditService) {
        this.aiChatAuditService = aiChatAuditService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("aiChatAuditExecutor")
    public void onAiChatMessagesCreated(AiChatMessagesCreatedEvent event) {
        event.getMessageIds().forEach(aiChatAuditService::audit);
    }
}
