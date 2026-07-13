package com.caoqiang.blog.ai.knowledge.application.event;

import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeIndexService;
import com.caoqiang.blog.content.event.ContentArchivedEvent;
import com.caoqiang.blog.content.event.ContentPublishedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/** Owns AI knowledge-index reactions to content lifecycle events. */
@Component
public class ContentKnowledgeIndexEventListener {

    private static final Logger log = LoggerFactory.getLogger(ContentKnowledgeIndexEventListener.class);

    private final KnowledgeIndexService knowledgeIndexService;

    public ContentKnowledgeIndexEventListener(KnowledgeIndexService knowledgeIndexService) {
        this.knowledgeIndexService = knowledgeIndexService;
    }

    @Async("taskExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onContentPublished(ContentPublishedEvent event) {
        try {
            knowledgeIndexService.indexContent(event.getContentId());
        } catch (Exception exception) {
            log.error("Failed to index published content {}", event.getContentId(), exception);
        }
    }

    @Async("taskExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onContentArchived(ContentArchivedEvent event) {
        try {
            knowledgeIndexService.deleteContentIndex(event.getContentId());
        } catch (Exception exception) {
            log.error("Failed to delete content index {}", event.getContentId(), exception);
        }
    }
}
