package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.ai.knowledge.application.service.EmbeddingService;
import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeReindexService;
import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeReindexWriter;
import com.caoqiang.blog.ai.knowledge.domain.model.FailedEmbeddingChunk;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import java.lang.reflect.Method;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.annotation.AnnotatedElementUtils;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@ExtendWith(MockitoExtension.class)
class KnowledgeReindexServiceTest {

    private static final Clock FIXED_CLOCK = Clock.fixed(Instant.parse("2026-06-26T08:00:00Z"), ZoneOffset.UTC);

    @Mock
    private KnowledgeChunkRepository repository;

    @Mock
    private EmbeddingService embeddingService;

    @Mock
    private KnowledgeReindexWriter writer;

    private KnowledgeReindexService service;

    @BeforeEach
    void setUp() {
        service = new KnowledgeReindexService(repository, embeddingService, writer, FIXED_CLOCK);
    }

    @Test
    void embeddingCallsRunOutsideAServiceTransactionAndFailuresDoNotStopTheBatch() throws Exception {
        FailedEmbeddingChunk first = candidate(1, "first");
        FailedEmbeddingChunk failed = candidate(2, "failed");
        FailedEmbeddingChunk last = candidate(3, "last");
        when(repository.findFailedEmbeddingCandidates(50)).thenReturn(List.of(first, failed, last));
        when(embeddingService.embed("first")).thenAnswer(invocation -> embeddingOutsideTransaction());
        when(embeddingService.embed("failed")).thenThrow(new IllegalStateException("provider unavailable"));
        when(embeddingService.embed("last")).thenAnswer(invocation -> embeddingOutsideTransaction());
        when(writer.markSucceeded(any(), anyString(), anyString())).thenReturn(true);
        when(writer.markFailed(any(), anyString(), anyString())).thenReturn(true);

        KnowledgeReindexService.ReindexResult result = service.manualReindex();

        assertThat(result).isEqualTo(new KnowledgeReindexService.ReindexResult(2, 1, 3));
        verify(embeddingService).embed("last");
        verify(writer)
                .markFailed(
                        failed.getId(),
                        "failed",
                        "{\"error\":\"embedding_generation_failed\",\"timestamp\":\"2026-06-26T08:00:00Z\",\"reindex_failed\":true}");

        Method manualReindex = KnowledgeReindexService.class.getMethod("manualReindex");
        assertThat(AnnotatedElementUtils.findMergedAnnotation(manualReindex, Transactional.class))
                .isNull();
        assertThat(AnnotatedElementUtils.findMergedAnnotation(KnowledgeReindexService.class, Transactional.class))
                .isNull();
    }

    @Test
    void scheduledRunUsesOldestRetryTimestampInsteadOfRepeatingTheLowestIds() {
        FailedEmbeddingChunk candidate = candidate(99, "not-retried-recently");
        when(repository.findFailedEmbeddingCandidatesForScheduledRetry(50)).thenReturn(List.of(candidate));
        when(embeddingService.embed(candidate.getContent())).thenReturn(new float[] {1.0F});
        when(writer.markSucceeded(any(), anyString(), anyString())).thenReturn(true);
        when(repository.countWithFailedEmbedding()).thenReturn(0L);

        service.reindexFailedChunks();

        verify(repository).findFailedEmbeddingCandidatesForScheduledRetry(50);
        verify(embeddingService).embed("not-retried-recently");
    }

    @Test
    void manualRunUsesKeysetBatchesAndStopsAtTheConfiguredBound() {
        List<List<FailedEmbeddingChunk>> batches = new ArrayList<>();
        for (int batch = 0; batch < 10; batch++) {
            List<FailedEmbeddingChunk> candidates = new ArrayList<>();
            for (int index = 0; index < 50; index++) {
                int ordinal = batch * 50 + index + 1;
                candidates.add(candidate(ordinal, "chunk-" + ordinal));
            }
            batches.add(candidates);
        }
        when(repository.findFailedEmbeddingCandidates(50)).thenReturn(batches.getFirst());
        when(repository.findFailedEmbeddingCandidatesAfter(any(), org.mockito.ArgumentMatchers.eq(50)))
                .thenReturn(batches.get(1))
                .thenReturn(batches.get(2))
                .thenReturn(batches.get(3))
                .thenReturn(batches.get(4))
                .thenReturn(batches.get(5))
                .thenReturn(batches.get(6))
                .thenReturn(batches.get(7))
                .thenReturn(batches.get(8))
                .thenReturn(batches.get(9));
        when(embeddingService.embed(anyString())).thenReturn(new float[] {1.0F});
        when(writer.markSucceeded(any(), anyString(), anyString())).thenReturn(true);

        KnowledgeReindexService.ReindexResult result = service.manualReindex();

        assertThat(result).isEqualTo(new KnowledgeReindexService.ReindexResult(500, 0, 500));
        verify(repository, times(9)).findFailedEmbeddingCandidatesAfter(any(), org.mockito.ArgumentMatchers.eq(50));
        verify(embeddingService, times(500)).embed(anyString());
    }

    @Test
    void staleSuccessfulResultIsCountedWithoutOverwritingFailureState() {
        FailedEmbeddingChunk candidate = candidate(1, "changed concurrently");
        when(repository.findFailedEmbeddingCandidates(50)).thenReturn(List.of(candidate));
        when(embeddingService.embed(candidate.getContent())).thenReturn(new float[] {1.0F});
        when(writer.markSucceeded(any(), anyString(), anyString())).thenReturn(false);

        KnowledgeReindexService.ReindexResult result = service.manualReindex();

        assertThat(result).isEqualTo(new KnowledgeReindexService.ReindexResult(0, 1, 1));
        verify(writer, never()).markFailed(any(), anyString(), anyString());
    }

    private float[] embeddingOutsideTransaction() {
        assertThat(TransactionSynchronizationManager.isActualTransactionActive())
                .isFalse();
        return new float[] {1.0F};
    }

    private FailedEmbeddingChunk candidate(int ordinal, String content) {
        UUID id = new UUID(0, ordinal);
        return new FailedEmbeddingChunk() {
            @Override
            public UUID getId() {
                return id;
            }

            @Override
            public String getContent() {
                return content;
            }
        };
    }
}
