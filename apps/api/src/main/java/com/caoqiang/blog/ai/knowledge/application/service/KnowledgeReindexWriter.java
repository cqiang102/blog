package com.caoqiang.blog.ai.knowledge.application.service;

import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Applies one reindex result in an isolated short transaction. */
@Service
public class KnowledgeReindexWriter {

    private final KnowledgeChunkRepository knowledgeChunkRepository;

    public KnowledgeReindexWriter(KnowledgeChunkRepository knowledgeChunkRepository) {
        this.knowledgeChunkRepository = knowledgeChunkRepository;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean markSucceeded(UUID chunkId, String expectedContent, String embedding) {
        return knowledgeChunkRepository.updateEmbeddingIfContentMatches(chunkId, expectedContent, embedding) == 1;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean markFailed(UUID chunkId, String expectedContent, String metadata) {
        return knowledgeChunkRepository.updateEmbeddingFailureIfContentMatches(chunkId, expectedContent, metadata) == 1;
    }
}
