package com.caoqiang.blog.ai.knowledge.application.service;

import com.caoqiang.blog.ai.knowledge.application.dto.KnowledgeSearchResult;
import com.caoqiang.blog.ai.knowledge.application.dto.KnowledgeSearchSourceType;
import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeDoc;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeDocRepository;
import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.content.application.api.ContentKnowledgeService;
import com.caoqiang.blog.content.application.api.ContentKnowledgeSource;
import com.caoqiang.blog.shared.util.VectorUtils;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

/**
 * 知识库搜索服务
 * <p>
 * 提供基于向量相似度的知识库搜索能力，用于 AI 聊天时检索相关博客内容。
 * <p>
 * 核心职责：
 * <ul>
 *   <li>关键词搜索 - 优先处理标题、正文中的精确词语和专有名词</li>
 *   <li>向量相似度搜索 - 关键词未命中时进行语义检索，并过滤低相关结果</li>
 *   <li>结果聚合 - 将搜索结果与内容元数据（标题等）关联</li>
 * </ul>
 * <p>
 * 搜索策略：
 * <ol>
 *   <li>空查询浏览当前知识来源</li>
 *   <li>精确关键词优先，未命中时使用 pgvector 语义搜索</li>
 *   <li>返回最多 5 条相关结果</li>
 * </ol>
 */
@Service
public class KnowledgeSearchService {

    private static final Logger log = LoggerFactory.getLogger(KnowledgeSearchService.class);
    private static final int MAX_RESULTS = 5;
    private static final int VECTOR_CANDIDATE_LIMIT = MAX_RESULTS * 5;
    private static final int EMBEDDING_DIMENSIONS = 768;
    private static final int MAX_EXCERPT_LENGTH = 1200;

    private final BlogProperties blogProperties;
    private final ContentKnowledgeService contentKnowledgeService;
    private final KnowledgeChunkRepository knowledgeChunkRepository;
    private final KnowledgeDocRepository knowledgeDocRepository;
    private final EmbeddingService embeddingService;

    public KnowledgeSearchService(
            BlogProperties blogProperties,
            ContentKnowledgeService contentKnowledgeService,
            KnowledgeChunkRepository knowledgeChunkRepository,
            KnowledgeDocRepository knowledgeDocRepository,
            EmbeddingService embeddingService) {
        this.blogProperties = blogProperties;
        this.contentKnowledgeService = contentKnowledgeService;
        this.knowledgeChunkRepository = knowledgeChunkRepository;
        this.knowledgeDocRepository = knowledgeDocRepository;
        this.embeddingService = embeddingService;
    }

    /**
     * 搜索知识库和已发布内容。
     * <p>
     * 精确关键词命中优先于向量结果，避免短标题或专有名词被语义模型错排。
     * 空查询用于浏览当前可用知识来源。关键词未命中时才执行向量搜索。
     */
    public List<KnowledgeSearchResult> search(String query) {
        String normalizedQuery = query == null ? "" : query.trim();
        if (normalizedQuery.isEmpty()) {
            return browse();
        }

        List<KnowledgeSearchResult> keywordResults = keywordSearch(normalizedQuery);
        if (!keywordResults.isEmpty()) {
            return keywordResults;
        }

        try {
            float[] queryEmbedding = embeddingService.embed(normalizedQuery);
            String embeddingStr = VectorUtils.toPgVectorString(queryEmbedding);
            List<Object[]> similarChunks =
                    knowledgeChunkRepository.findSimilarChunks(embeddingStr, VECTOR_CANDIDATE_LIMIT);
            return mapVectorResults(similarChunks);
        } catch (Exception e) {
            log.warn(
                    "Knowledge vector search failed after retries: queryLength={}, error={}",
                    normalizedQuery.length(),
                    e.getMessage());
            return List.of();
        }
    }

    private List<KnowledgeSearchResult> keywordSearch(String query) {
        LinkedHashMap<String, KnowledgeSearchResult> results = new LinkedHashMap<>();
        List<KnowledgeDoc> docs = knowledgeDocRepository.searchEnabled(query, PageRequest.of(0, MAX_RESULTS));
        for (KnowledgeDoc doc : docs) {
            addResult(
                    results,
                    new KnowledgeSearchResult(
                            excerpt(doc.getBody(), doc.getTitle(), query),
                            1.0,
                            doc.getId().toString(),
                            KnowledgeSearchSourceType.KNOWLEDGE_DOC,
                            doc.getTitle()));
        }

        List<ContentKnowledgeSource> searchResults = contentKnowledgeService.searchPublished(query, MAX_RESULTS);
        for (ContentKnowledgeSource item : searchResults) {
            addResult(
                    results,
                    new KnowledgeSearchResult(
                            excerpt(item.summary(), item.title(), query),
                            1.0,
                            item.id().toString(),
                            KnowledgeSearchSourceType.CONTENT,
                            item.title()));
        }
        return results.values().stream().limit(MAX_RESULTS).toList();
    }

    private List<KnowledgeSearchResult> browse() {
        LinkedHashMap<String, KnowledgeSearchResult> results = new LinkedHashMap<>();
        List<KnowledgeDoc> docs =
                knowledgeDocRepository.findByEnabledTrueOrderByUpdatedAtDesc(PageRequest.of(0, MAX_RESULTS));
        for (KnowledgeDoc doc : docs) {
            addResult(
                    results,
                    new KnowledgeSearchResult(
                            excerpt(doc.getBody(), doc.getTitle(), null),
                            1.0,
                            doc.getId().toString(),
                            KnowledgeSearchSourceType.KNOWLEDGE_DOC,
                            doc.getTitle()));
        }

        int remaining = MAX_RESULTS - results.size();
        if (remaining > 0) {
            List<ContentKnowledgeSource> contents = contentKnowledgeService.searchPublished(null, remaining);
            for (ContentKnowledgeSource item : contents) {
                addResult(
                        results,
                        new KnowledgeSearchResult(
                                excerpt(item.summary(), item.title(), null),
                                1.0,
                                item.id().toString(),
                                KnowledgeSearchSourceType.CONTENT,
                                item.title()));
            }
        }
        return results.values().stream().limit(MAX_RESULTS).toList();
    }

    private List<KnowledgeSearchResult> mapVectorResults(List<Object[]> similarChunks) {
        double minSimilarity = blogProperties.getAi().getKnowledgeMinSimilarity();
        List<Object[]> acceptedChunks = similarChunks.stream()
                .filter(chunk -> score(chunk) >= minSimilarity)
                .toList();
        if (acceptedChunks.isEmpty()) {
            return List.of();
        }

        List<UUID> contentIds = acceptedChunks.stream()
                .map(chunk -> chunk[2] instanceof UUID id ? id : null)
                .filter(Objects::nonNull)
                .distinct()
                .toList();
        List<UUID> docIds = acceptedChunks.stream()
                .map(chunk -> chunk[1] instanceof UUID id ? id : null)
                .filter(Objects::nonNull)
                .distinct()
                .toList();

        Map<UUID, ContentKnowledgeSource> contentMap = contentKnowledgeService.findPublishedByIds(contentIds).stream()
                .collect(
                        java.util.stream.Collectors.toMap(ContentKnowledgeSource::id, content -> content, (a, b) -> a));
        Map<UUID, KnowledgeDoc> docMap = knowledgeDocRepository.findAllById(docIds).stream()
                .filter(KnowledgeDoc::isEnabled)
                .collect(java.util.stream.Collectors.toMap(KnowledgeDoc::getId, doc -> doc, (a, b) -> a));

        LinkedHashMap<String, KnowledgeSearchResult> results = new LinkedHashMap<>();
        for (Object[] chunk : acceptedChunks) {
            UUID docId = chunk[1] instanceof UUID id ? id : null;
            UUID contentId = chunk[2] instanceof UUID id ? id : null;
            String title = null;
            String sourceId = null;
            KnowledgeSearchSourceType sourceType = null;
            if (contentId != null && contentMap.containsKey(contentId)) {
                title = contentMap.get(contentId).title();
                sourceId = contentId.toString();
                sourceType = KnowledgeSearchSourceType.CONTENT;
            } else if (docId != null && docMap.containsKey(docId)) {
                title = docMap.get(docId).getTitle();
                sourceId = docId.toString();
                sourceType = KnowledgeSearchSourceType.KNOWLEDGE_DOC;
            }
            if (sourceId == null) {
                continue;
            }
            addResult(
                    results,
                    new KnowledgeSearchResult(
                            chunk[4] instanceof String content ? content : "",
                            score(chunk),
                            sourceId,
                            sourceType,
                            title));
        }
        return results.values().stream().limit(MAX_RESULTS).toList();
    }

    private double score(Object[] chunk) {
        return chunk.length > 6 && chunk[6] instanceof Number number ? number.doubleValue() : 0.0;
    }

    private String excerpt(String value, String fallback, String query) {
        String text = value == null || value.isBlank() ? fallback : value.trim();
        if (text == null) {
            return "";
        }
        if (text.length() <= MAX_EXCERPT_LENGTH) {
            return text;
        }
        int start = 0;
        if (query != null && !query.isBlank()) {
            int match = text.toLowerCase(java.util.Locale.ROOT).indexOf(query.toLowerCase(java.util.Locale.ROOT));
            if (match >= 0) {
                start = Math.max(0, match - MAX_EXCERPT_LENGTH / 3);
            }
        }
        start = Math.min(start, text.length() - MAX_EXCERPT_LENGTH);
        return text.substring(start, start + MAX_EXCERPT_LENGTH);
    }

    private void addResult(LinkedHashMap<String, KnowledgeSearchResult> results, KnowledgeSearchResult result) {
        if (result.sourceId() != null && result.sourceType() != null) {
            results.putIfAbsent(result.sourceType() + ":" + result.sourceId(), result);
        }
    }
}
