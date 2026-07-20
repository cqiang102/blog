package com.caoqiang.blog.ai.knowledge.application.event;

import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeIndexService;
import com.caoqiang.blog.ai.knowledge.event.KnowledgeDocumentIndexRequestedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/** Starts knowledge-document indexing only after the source document is durable. */
@Component
public class KnowledgeDocumentIndexEventListener {

    private static final Logger log = LoggerFactory.getLogger(KnowledgeDocumentIndexEventListener.class);

    private final KnowledgeIndexService knowledgeIndexService;

    public KnowledgeDocumentIndexEventListener(KnowledgeIndexService knowledgeIndexService) {
        this.knowledgeIndexService = knowledgeIndexService;
    }

    @Async("taskExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onIndexRequested(KnowledgeDocumentIndexRequestedEvent event) {
        try {
            knowledgeIndexService.indexDocument(event.documentId());
        } catch (Exception exception) {
            log.error("Failed to index knowledge document {}", event.documentId(), exception);
        }
    }
}
