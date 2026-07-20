package com.caoqiang.blog.ai.knowledge.application.service;

import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeChunk;
import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeDoc;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeDocRepository;
import com.caoqiang.blog.content.application.api.ContentKnowledgeService;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Atomically replaces prepared chunks without calling the external embedding model. */
@Service
public class KnowledgeChunkWriter {

    private final KnowledgeDocRepository knowledgeDocRepository;
    private final KnowledgeChunkRepository knowledgeChunkRepository;
    private final ContentKnowledgeService contentKnowledgeService;

    public KnowledgeChunkWriter(
            KnowledgeDocRepository knowledgeDocRepository,
            KnowledgeChunkRepository knowledgeChunkRepository,
            ContentKnowledgeService contentKnowledgeService) {
        this.knowledgeDocRepository = knowledgeDocRepository;
        this.knowledgeChunkRepository = knowledgeChunkRepository;
        this.contentKnowledgeService = contentKnowledgeService;
    }

    @Transactional
    public boolean replaceDocumentChunks(
            UUID documentId, String expectedBody, List<KnowledgeIndexService.PreparedChunk> preparedChunks) {
        KnowledgeDoc document = knowledgeDocRepository.findById(documentId).orElse(null);
        if (document == null) {
            return true;
        }
        if (!document.isEnabled()
                || document.getBody() == null
                || document.getBody().isBlank()) {
            knowledgeChunkRepository.deleteByDocId(documentId);
            return true;
        }
        if (!Objects.equals(document.getBody(), expectedBody)) {
            return false;
        }

        knowledgeChunkRepository.deleteByDocId(documentId);
        knowledgeChunkRepository.saveAll(preparedChunks.stream()
                .map(chunk -> documentChunk(document, chunk))
                .toList());
        return true;
    }

    @Transactional
    public boolean replaceContentChunks(
            UUID contentId, String expectedText, List<KnowledgeIndexService.PreparedChunk> preparedChunks) {
        String currentText = contentKnowledgeService
                .findIndexable(contentId)
                .map(KnowledgeIndexService::contentText)
                .orElse(null);
        if (currentText == null || currentText.isBlank()) {
            knowledgeChunkRepository.deleteByContentId(contentId);
            return true;
        }
        if (!Objects.equals(currentText, expectedText)) {
            return false;
        }

        knowledgeChunkRepository.deleteByContentId(contentId);
        knowledgeChunkRepository.saveAll(preparedChunks.stream()
                .map(chunk -> contentChunk(contentId, chunk))
                .toList());
        return true;
    }

    @Transactional
    public void deleteContentChunks(UUID contentId) {
        knowledgeChunkRepository.deleteByContentId(contentId);
    }

    @Transactional
    public void deleteDocumentChunks(UUID documentId) {
        knowledgeChunkRepository.deleteByDocId(documentId);
    }

    private KnowledgeChunk documentChunk(KnowledgeDoc document, KnowledgeIndexService.PreparedChunk prepared) {
        KnowledgeChunk chunk = new KnowledgeChunk(document, prepared.index(), prepared.content());
        applyPreparedValues(chunk, prepared);
        return chunk;
    }

    private KnowledgeChunk contentChunk(UUID contentId, KnowledgeIndexService.PreparedChunk prepared) {
        KnowledgeChunk chunk = new KnowledgeChunk(contentId, prepared.index(), prepared.content());
        applyPreparedValues(chunk, prepared);
        return chunk;
    }

    private void applyPreparedValues(KnowledgeChunk target, KnowledgeIndexService.PreparedChunk prepared) {
        target.setEmbedding(prepared.embedding());
        target.setMetadata(prepared.metadata());
    }
}
