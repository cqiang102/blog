package com.caoqiang.blog.ai.knowledge.application.service;

import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import java.util.List;
import java.util.UUID;
import java.util.function.Consumer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * Repairs knowledge-index work which was lost after a source transaction committed.
 *
 * <p>The normal event listeners remain the low-latency path. This scheduled reconciliation uses
 * durable source and chunk timestamps as its source of truth, so a process crash or rejected async
 * task cannot leave a document permanently unindexed.</p>
 */
@Service
public class KnowledgeIndexReconciliationService {

    private static final Logger log = LoggerFactory.getLogger(KnowledgeIndexReconciliationService.class);

    static final int RECONCILIATION_BATCH_SIZE = 50;

    private final KnowledgeChunkRepository knowledgeChunkRepository;
    private final KnowledgeIndexService knowledgeIndexService;
    private final KnowledgeChunkWriter knowledgeChunkWriter;

    public KnowledgeIndexReconciliationService(
            KnowledgeChunkRepository knowledgeChunkRepository,
            KnowledgeIndexService knowledgeIndexService,
            KnowledgeChunkWriter knowledgeChunkWriter) {
        this.knowledgeChunkRepository = knowledgeChunkRepository;
        this.knowledgeIndexService = knowledgeIndexService;
        this.knowledgeChunkWriter = knowledgeChunkWriter;
    }

    /** Reconciles bounded source batches; one broken source never aborts the remaining repairs. */
    @Scheduled(fixedDelay = 30 * 60 * 1000, initialDelay = 7 * 60 * 1000)
    public void reconcileSources() {
        int repaired = 0;
        repaired += process(
                "knowledge document index",
                knowledgeChunkRepository.findDocumentIdsNeedingIndex(RECONCILIATION_BATCH_SIZE),
                knowledgeIndexService::indexDocument);
        repaired += process(
                "knowledge document cleanup",
                knowledgeChunkRepository.findDocumentIdsNeedingIndexDeletion(RECONCILIATION_BATCH_SIZE),
                knowledgeChunkWriter::deleteDocumentChunks);
        repaired += process(
                "content index",
                knowledgeChunkRepository.findContentIdsNeedingIndex(RECONCILIATION_BATCH_SIZE),
                knowledgeIndexService::indexContent);
        repaired += process(
                "content index cleanup",
                knowledgeChunkRepository.findContentIdsNeedingIndexDeletion(RECONCILIATION_BATCH_SIZE),
                knowledgeChunkWriter::deleteContentChunks);
        if (repaired > 0) {
            log.info("Knowledge index reconciliation completed: repaired={}", repaired);
        }
    }

    private int process(String operation, List<UUID> sourceIds, Consumer<UUID> repair) {
        int repaired = 0;
        for (UUID sourceId : sourceIds) {
            try {
                repair.accept(sourceId);
                repaired++;
            } catch (RuntimeException exception) {
                log.warn("Knowledge index reconciliation failed: operation={}, sourceId={}", operation, sourceId);
                log.debug("Knowledge index reconciliation failure details", exception);
            }
        }
        return repaired;
    }
}
