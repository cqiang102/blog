package com.caoqiang.blog.ai;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeChunkWriter;
import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeIndexReconciliationService;
import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeIndexService;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class KnowledgeIndexReconciliationServiceTest {

    @Mock
    private KnowledgeChunkRepository repository;

    @Mock
    private KnowledgeIndexService indexService;

    @Mock
    private KnowledgeChunkWriter chunkWriter;

    private KnowledgeIndexReconciliationService service;

    @BeforeEach
    void setUp() {
        service = new KnowledgeIndexReconciliationService(repository, indexService, chunkWriter);
    }

    @Test
    void repairsMissingAndStaleIndexesFromDurableSourceState() {
        UUID failedDocument = UUID.randomUUID();
        UUID healthyDocument = UUID.randomUUID();
        UUID documentToClean = UUID.randomUUID();
        UUID contentToIndex = UUID.randomUUID();
        UUID contentToClean = UUID.randomUUID();
        when(repository.findDocumentIdsNeedingIndex(50)).thenReturn(List.of(failedDocument, healthyDocument));
        when(repository.findDocumentIdsNeedingIndexDeletion(50)).thenReturn(List.of(documentToClean));
        when(repository.findContentIdsNeedingIndex(50)).thenReturn(List.of(contentToIndex));
        when(repository.findContentIdsNeedingIndexDeletion(50)).thenReturn(List.of(contentToClean));
        org.mockito.Mockito.doThrow(new IllegalStateException("broken source"))
                .when(indexService)
                .indexDocument(failedDocument);

        service.reconcileSources();

        verify(indexService).indexDocument(failedDocument);
        verify(indexService).indexDocument(healthyDocument);
        verify(chunkWriter).deleteDocumentChunks(documentToClean);
        verify(indexService).indexContent(contentToIndex);
        verify(chunkWriter).deleteContentChunks(contentToClean);
    }
}
