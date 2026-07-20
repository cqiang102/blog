package com.caoqiang.blog.interaction;

import static org.mockito.Mockito.verify;

import com.caoqiang.blog.interaction.application.event.CommentAuditEventListener;
import com.caoqiang.blog.interaction.application.service.CommentAuditService;
import com.caoqiang.blog.interaction.event.CommentCreatedEvent;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class CommentAuditEventListenerTest {

    @Mock
    private CommentAuditService commentAuditService;

    @Test
    void commentCreatedStartsAudit() {
        UUID commentId = UUID.randomUUID();
        CommentAuditEventListener listener = new CommentAuditEventListener(commentAuditService);

        listener.onCommentCreated(new CommentCreatedEvent(commentId, UUID.randomUUID(), UUID.randomUUID()));

        verify(commentAuditService).audit(commentId);
    }
}
