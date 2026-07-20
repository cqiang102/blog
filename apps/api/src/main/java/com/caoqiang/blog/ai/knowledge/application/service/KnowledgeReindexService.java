package com.caoqiang.blog.ai.knowledge.application.service;

import com.caoqiang.blog.ai.knowledge.domain.model.FailedEmbeddingChunk;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import com.caoqiang.blog.shared.util.VectorUtils;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/** Retries failed embeddings in bounded batches without holding a transaction around model calls. */
@Service
public class KnowledgeReindexService {

    private static final Logger log = LoggerFactory.getLogger(KnowledgeReindexService.class);

    static final int REINDEX_BATCH_SIZE = 50;
    static final int MAX_MANUAL_REINDEX_SIZE = 500;

    private final KnowledgeChunkRepository knowledgeChunkRepository;
    private final EmbeddingService embeddingService;
    private final KnowledgeReindexWriter reindexWriter;
    private final Clock clock;

    public KnowledgeReindexService(
            KnowledgeChunkRepository knowledgeChunkRepository,
            EmbeddingService embeddingService,
            KnowledgeReindexWriter reindexWriter,
            Clock clock) {
        this.knowledgeChunkRepository = knowledgeChunkRepository;
        this.embeddingService = embeddingService;
        this.reindexWriter = reindexWriter;
        this.clock = clock;
    }

    /** Retries one scheduled batch. A failure in one chunk never prevents the remaining retries. */
    @Scheduled(fixedDelay = 30 * 60 * 1000, initialDelay = 5 * 60 * 1000)
    public void reindexFailedChunks() {
        List<FailedEmbeddingChunk> candidates =
                knowledgeChunkRepository.findFailedEmbeddingCandidatesForScheduledRetry(REINDEX_BATCH_SIZE);
        BatchResult result = process(candidates);
        if (result.totalCount() > 0) {
            log.info(
                    "Knowledge reindex batch completed: success={}, failed={}, remaining={}",
                    result.successCount(),
                    result.failCount(),
                    knowledgeChunkRepository.countWithFailedEmbedding());
        }
    }

    /**
     * Retries failed chunks in fixed-size keyset batches.
     *
     * <p>One manual request processes at most {@value #MAX_MANUAL_REINDEX_SIZE} chunks so the admin
     * HTTP request cannot become unbounded. Remaining chunks are picked up by the next manual or
     * scheduled run.</p>
     */
    public ReindexResult manualReindex() {
        int successCount = 0;
        int failCount = 0;
        int processed = 0;
        UUID afterId = null;

        while (processed < MAX_MANUAL_REINDEX_SIZE) {
            int limit = Math.min(REINDEX_BATCH_SIZE, MAX_MANUAL_REINDEX_SIZE - processed);
            List<FailedEmbeddingChunk> candidates = afterId == null
                    ? knowledgeChunkRepository.findFailedEmbeddingCandidates(limit)
                    : knowledgeChunkRepository.findFailedEmbeddingCandidatesAfter(afterId, limit);
            if (candidates.isEmpty()) {
                break;
            }

            BatchResult batch = process(candidates);
            successCount += batch.successCount();
            failCount += batch.failCount();
            processed += batch.totalCount();
            afterId = candidates.getLast().getId();

            if (candidates.size() < limit) {
                break;
            }
        }

        return new ReindexResult(successCount, failCount, processed);
    }

    private BatchResult process(List<FailedEmbeddingChunk> candidates) {
        int successCount = 0;
        int failCount = 0;
        for (FailedEmbeddingChunk candidate : candidates) {
            try {
                float[] embedding = embeddingService.embed(candidate.getContent());
                boolean updated = reindexWriter.markSucceeded(
                        candidate.getId(), candidate.getContent(), VectorUtils.toPgVectorString(embedding));
                if (updated) {
                    successCount++;
                } else {
                    failCount++;
                    log.debug("Skipped stale reindex result: chunkId={}", candidate.getId());
                }
            } catch (Exception exception) {
                failCount++;
                recordFailure(candidate);
                log.warn("Embedding retry failed: chunkId={}", candidate.getId());
            }
        }
        return new BatchResult(successCount, failCount, candidates.size());
    }

    private void recordFailure(FailedEmbeddingChunk candidate) {
        try {
            reindexWriter.markFailed(candidate.getId(), candidate.getContent(), failureMetadata(clock.instant()));
        } catch (RuntimeException persistenceFailure) {
            log.error("Failed to persist embedding retry state: chunkId={}", candidate.getId(), persistenceFailure);
        }
    }

    private String failureMetadata(Instant failedAt) {
        return "{\"error\":\"embedding_generation_failed\",\"timestamp\":\"" + failedAt + "\",\"reindex_failed\":true}";
    }

    /** Result returned to the management API. */
    public record ReindexResult(int successCount, int failCount, int totalCount) {
        public boolean isAllSuccess() {
            return failCount == 0;
        }
    }

    /** Returns aggregate index health without loading chunk entities. */
    public IndexStatus getIndexStatus() {
        long totalChunks = knowledgeChunkRepository.countAll();
        long chunksWithEmbedding = knowledgeChunkRepository.countWithEmbedding();
        long failedChunks = knowledgeChunkRepository.countWithFailedEmbedding();
        return new IndexStatus(totalChunks, chunksWithEmbedding, failedChunks);
    }

    public record IndexStatus(long totalChunks, long chunksWithEmbedding, long failedChunks) {
        public boolean needsReindex() {
            return failedChunks > 0;
        }

        public double indexRate() {
            if (totalChunks == 0) {
                return 100.0;
            }
            return (double) chunksWithEmbedding / totalChunks * 100;
        }
    }

    private record BatchResult(int successCount, int failCount, int totalCount) {}
}
