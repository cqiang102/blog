package com.caoqiang.blog.ai;

import com.caoqiang.blog.ai.chat.application.event.AiChatAuditEventListener;
import com.caoqiang.blog.ai.chat.application.service.AiChatAuditService;
import com.caoqiang.blog.ai.chat.event.AiChatMessagesCreatedEvent;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class AiChatAuditEventListenerTest {

    @Mock
    private AiChatAuditService aiChatAuditService;

    @Test
    void messagesCreatedStartsAuditForEveryMessage() {
        UUID firstMessageId = UUID.randomUUID();
        UUID secondMessageId = UUID.randomUUID();
        AiChatAuditEventListener listener = new AiChatAuditEventListener(aiChatAuditService);

        listener.onAiChatMessagesCreated(
                new AiChatMessagesCreatedEvent(List.of(firstMessageId, secondMessageId))
        );

        verify(aiChatAuditService).audit(firstMessageId);
        verify(aiChatAuditService).audit(secondMessageId);
    }
}
