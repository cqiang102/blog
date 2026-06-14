package com.caoqiang.blog.ai.knowledge.application.service;

import com.caoqiang.blog.ai.knowledge.application.dto.KnowledgeSearchResult;
import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeDoc;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeDocRepository;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.shared.util.VectorUtils;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.application.service.ContentService;
import com.caoqiang.blog.content.application.dto.ContentSummaryResponse;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.stereotype.Service;

/**
 * 知识库搜索服务
 * <p>
 * 提供基于向量相似度的知识库搜索能力，用于 AI 聊天时检索相关博客内容。
 * <p>
 * 核心职责：
 * <ul>
 *   <li>向量相似度搜索 - 使用 EmbeddingModel 将查询转换为向量，与知识库中的内容片段进行相似度匹配</li>
 *   <li>文本回退搜索 - 当向量搜索失败时，回退到基于关键词的内容搜索</li>
 *   <li>结果聚合 - 将搜索结果与内容元数据（标题等）关联</li>
 * </ul>
 * <p>
 * 搜索策略：
 * <ol>
 *   <li>优先使用向量相似度搜索（pgvector）</li>
 *   <li>向量搜索失败时回退到文本搜索</li>
 *   <li>返回最多 5 条相关结果</li>
 * </ol>
 */
@Service
public class KnowledgeSearchService {

    private static final Logger log = LoggerFactory.getLogger(KnowledgeSearchService.class);

    private final ContentService contentService;
    private final ContentRepository contentRepository;
    private final KnowledgeChunkRepository knowledgeChunkRepository;
    private final KnowledgeDocRepository knowledgeDocRepository;
    private final EmbeddingModel embeddingModel;

    public KnowledgeSearchService(
            ContentService contentService,
            ContentRepository contentRepository,
            KnowledgeChunkRepository knowledgeChunkRepository,
            KnowledgeDocRepository knowledgeDocRepository,
            EmbeddingModel embeddingModel
    ) {
        this.contentService = contentService;
        this.contentRepository = contentRepository;
        this.knowledgeChunkRepository = knowledgeChunkRepository;
        this.knowledgeDocRepository = knowledgeDocRepository;
        this.embeddingModel = embeddingModel;
    }

    public List<KnowledgeSearchResult> search(String query) {
        try {
            float[] queryEmbedding = embeddingModel.embed(query);
            String embeddingStr = VectorUtils.toPgVectorString(queryEmbedding);
            List<Object[]> similarChunks = knowledgeChunkRepository.findSimilarChunks(embeddingStr, 5);

            if (!similarChunks.isEmpty()) {
                List<UUID> contentIds = similarChunks.stream()
                        .map(chunk -> chunk[2] != null ? (UUID) chunk[2] : null)
                        .filter(java.util.Objects::nonNull)
                        .distinct()
                        .toList();

                List<UUID> docIds = similarChunks.stream()
                        .map(chunk -> chunk[1] != null ? (UUID) chunk[1] : null)
                        .filter(java.util.Objects::nonNull)
                        .distinct()
                        .toList();

                Map<UUID, Content> contentMap = contentRepository.findAllById(contentIds).stream()
                        .collect(java.util.stream.Collectors.toMap(Content::getId, c -> c));

                Map<UUID, KnowledgeDoc> docMap = knowledgeDocRepository.findAllById(docIds).stream()
                        .collect(java.util.stream.Collectors.toMap(KnowledgeDoc::getId, d -> d));

                List<KnowledgeSearchResult> results = new ArrayList<>();
                for (Object[] chunk : similarChunks) {
                    UUID docId = chunk[1] != null ? (UUID) chunk[1] : null;
                    UUID contentId = chunk[2] != null ? (UUID) chunk[2] : null;
                    String content = (String) chunk[4];
                    double score = chunk[6] != null ? ((Number) chunk[6]).doubleValue() : 0;

                    String title = null;
                    String sourceId = null;
                    if (contentId != null && contentMap.containsKey(contentId)) {
                        title = contentMap.get(contentId).getTitle();
                        sourceId = contentId.toString();
                    } else if (docId != null && docMap.containsKey(docId)) {
                        title = docMap.get(docId).getTitle();
                        sourceId = docId.toString();
                    }

                    results.add(new KnowledgeSearchResult(content, score, sourceId, title));
                }
                return results;
            }
        } catch (Exception e) {
            log.warn("向量搜索失败，回退到文本搜索: {}", e.getMessage());
        }

        List<KnowledgeSearchResult> results = new ArrayList<>();
        PageResponse<ContentSummaryResponse> searchResults = contentService.list(
                query, null, null, null, null, 0, 5
        );
        for (ContentSummaryResponse item : searchResults.items()) {
            results.add(new KnowledgeSearchResult(
                    item.summary() != null ? item.summary() : "",
                    0.0,
                    item.id().toString(),
                    item.title()
            ));
        }
        return results;
    }
}
