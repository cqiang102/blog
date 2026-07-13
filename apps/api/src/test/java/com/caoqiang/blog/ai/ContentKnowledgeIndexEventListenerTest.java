package com.caoqiang.blog.ai;

import static org.mockito.Mockito.verify;

import com.caoqiang.blog.ai.knowledge.application.event.ContentKnowledgeIndexEventListener;
import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeIndexService;
import com.caoqiang.blog.content.event.ContentArchivedEvent;
import com.caoqiang.blog.content.event.ContentPublishedEvent;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ContentKnowledgeIndexEventListenerTest {

    @Mock
    private KnowledgeIndexService knowledgeIndexService;

    @Test
    void indexesPublishedContentAndDeletesArchivedContent() {
        UUID contentId = UUID.randomUUID();
        ContentKnowledgeIndexEventListener listener = new ContentKnowledgeIndexEventListener(
                knowledgeIndexService
        );

        listener.onContentPublished(new ContentPublishedEvent(contentId, "Title", "title"));
        listener.onContentArchived(new ContentArchivedEvent(contentId));

        verify(knowledgeIndexService).indexContent(contentId);
        verify(knowledgeIndexService).deleteContentIndex(contentId);
    }
}
