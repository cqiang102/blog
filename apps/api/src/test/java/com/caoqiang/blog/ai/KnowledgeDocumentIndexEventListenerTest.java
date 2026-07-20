package com.caoqiang.blog.ai;

import static org.mockito.Mockito.verify;

import com.caoqiang.blog.ai.knowledge.application.event.KnowledgeDocumentIndexEventListener;
import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeIndexService;
import com.caoqiang.blog.ai.knowledge.event.KnowledgeDocumentIndexRequestedEvent;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class KnowledgeDocumentIndexEventListenerTest {

    @Mock
    private KnowledgeIndexService knowledgeIndexService;

    @Test
    void indexesRequestedDocument() {
        UUID documentId = UUID.randomUUID();
        KnowledgeDocumentIndexEventListener listener = new KnowledgeDocumentIndexEventListener(knowledgeIndexService);

        listener.onIndexRequested(new KnowledgeDocumentIndexRequestedEvent(documentId));

        verify(knowledgeIndexService).indexDocument(documentId);
    }
}
