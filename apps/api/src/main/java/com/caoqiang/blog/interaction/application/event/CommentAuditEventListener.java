package com.caoqiang.blog.interaction.application.event;

import com.caoqiang.blog.interaction.application.service.CommentAuditService;
import com.caoqiang.blog.interaction.event.CommentCreatedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Starts asynchronous comment moderation after a comment transaction commits.
 */
@Component
public class CommentAuditEventListener {

    private static final Logger log = LoggerFactory.getLogger(CommentAuditEventListener.class);

    private final CommentAuditService commentAuditService;

    public CommentAuditEventListener(CommentAuditService commentAuditService) {
        this.commentAuditService = commentAuditService;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("commentAuditExecutor")
    public void onCommentCreated(CommentCreatedEvent event) {
        commentAuditService.audit(event.getCommentId());
        log.info("Comment created: commentId={}, contentId={}, userId={}",
                event.getCommentId(), event.getContentId(), event.getUserId());
    }
}
