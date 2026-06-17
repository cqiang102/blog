package com.caoqiang.blog.ai.knowledge.application.service;

import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeChunk;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import com.caoqiang.blog.shared.util.VectorUtils;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 知识库重新索引服务。
 * <p>
 * 定时检查并重新索引嵌入失败的知识分块，提高知识库的完整性。
 * 当嵌入模型服务恢复后，自动补齐之前失败的向量嵌入。
 */
@Service
public class KnowledgeReindexService {

    private static final Logger log = LoggerFactory.getLogger(KnowledgeReindexService.class);

    /** 每次重新索引的最大分块数量，避免一次性处理过多 */
    private static final int MAX_REINDEX_BATCH_SIZE = 50;

    private final KnowledgeChunkRepository knowledgeChunkRepository;
    private final EmbeddingService embeddingService;

    public KnowledgeReindexService(
            KnowledgeChunkRepository knowledgeChunkRepository,
            EmbeddingService embeddingService
    ) {
        this.knowledgeChunkRepository = knowledgeChunkRepository;
        this.embeddingService = embeddingService;
    }

    /**
     * 定时重新索引嵌入失败的分块。
     * <p>
     * 每 30 分钟执行一次，检查并重新生成之前失败的向量嵌入。
     * 单个分块重新索引失败不影响其他分块的处理。
     */
    @Scheduled(fixedDelay = 30 * 60 * 1000, initialDelay = 5 * 60 * 1000)
    @Transactional
    public void reindexFailedChunks() {
        List<KnowledgeChunk> failedChunks = knowledgeChunkRepository.findChunksWithFailedEmbedding();
        
        if (failedChunks.isEmpty()) {
            log.debug("No failed embedding chunks found for reindexing");
            return;
        }

        log.info("Found {} failed embedding chunks for reindexing", failedChunks.size());
        
        int successCount = 0;
        int failCount = 0;
        
        // 限制批次大小，避免长时间占用资源
        List<KnowledgeChunk> chunksToProcess = failedChunks.subList(0, Math.min(failedChunks.size(), MAX_REINDEX_BATCH_SIZE));
        
        for (KnowledgeChunk chunk : chunksToProcess) {
            try {
                float[] embedding = embeddingService.embed(chunk.getContent());
                chunk.setEmbedding(VectorUtils.toPgVectorString(embedding));
                chunk.setMetadata(null); // 清除错误标记
                knowledgeChunkRepository.save(chunk);
                successCount++;
                log.debug("Successfully reindexed chunk: {}", chunk.getId());
            } catch (Exception e) {
                failCount++;
                log.warn("Failed to reindex chunk {}: {}", chunk.getId(), e.getMessage());
                // 更新错误时间戳
                chunk.setMetadata("{\"error\":\"embedding_generation_failed\",\"timestamp\":\"" + java.time.Instant.now() + "\",\"reindex_failed\":true}");
                knowledgeChunkRepository.save(chunk);
            }
        }
        
        log.info("Reindex completed: success={}, failed={}, remaining={}", 
                successCount, failCount, failedChunks.size() - chunksToProcess.size());
    }

    /**
     * 手动触发重新索引所有失败的分块。
     *
     * @return 重新索引的结果统计
     */
    @Transactional
    public ReindexResult manualReindex() {
        List<KnowledgeChunk> failedChunks = knowledgeChunkRepository.findChunksWithFailedEmbedding();
        
        if (failedChunks.isEmpty()) {
            return new ReindexResult(0, 0, 0);
        }

        int successCount = 0;
        int failCount = 0;
        
        for (KnowledgeChunk chunk : failedChunks) {
            try {
                float[] embedding = embeddingService.embed(chunk.getContent());
                chunk.setEmbedding(VectorUtils.toPgVectorString(embedding));
                chunk.setMetadata(null); // 清除错误标记
                knowledgeChunkRepository.save(chunk);
                successCount++;
            } catch (Exception e) {
                failCount++;
                log.warn("Manual reindex failed for chunk {}: {}", chunk.getId(), e.getMessage());
                // 更新错误时间戳
                chunk.setMetadata("{\"error\":\"embedding_generation_failed\",\"timestamp\":\"" + java.time.Instant.now() + "\",\"reindex_failed\":true}");
                knowledgeChunkRepository.save(chunk);
            }
        }
        
        return new ReindexResult(successCount, failCount, failedChunks.size());
    }

    /**
     * 重新索引结果记录。
     */
    public record ReindexResult(int successCount, int failCount, int totalCount) {
        public boolean isAllSuccess() {
            return failCount == 0;
        }
    }

    /**
     * 获取知识库索引状态。
     *
     * @return 索引状态统计
     */
    public IndexStatus getIndexStatus() {
        long totalChunks = knowledgeChunkRepository.countAll();
        long chunksWithEmbedding = knowledgeChunkRepository.countWithEmbedding();
        long failedChunks = knowledgeChunkRepository.countWithFailedEmbedding();
        
        return new IndexStatus(totalChunks, chunksWithEmbedding, failedChunks);
    }

    /**
     * 索引状态记录。
     */
    public record IndexStatus(long totalChunks, long chunksWithEmbedding, long failedChunks) {
        /**
         * 是否需要重新索引（存在失败的分块）。
         */
        public boolean needsReindex() {
            return failedChunks > 0;
        }

        /**
         * 索引完成率（0-100）。
         */
        public double indexRate() {
            if (totalChunks == 0) return 100.0;
            return (double) chunksWithEmbedding / totalChunks * 100;
        }
    }
}