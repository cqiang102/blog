package com.caoqiang.blog.ai;

import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.common.VectorUtils;
import com.caoqiang.blog.content.Content;
import com.caoqiang.blog.content.ContentRepository;
import com.caoqiang.blog.content.ContentService;
import com.caoqiang.blog.content.ContentSummaryResponse;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.stereotype.Service;

@Service
public class KnowledgeSearchService {

    private static final Logger log = LoggerFactory.getLogger(KnowledgeSearchService.class);

    private final ContentService contentService;
    private final ContentRepository contentRepository;
    private final KnowledgeChunkRepository knowledgeChunkRepository;
    private final EmbeddingModel embeddingModel;

    public KnowledgeSearchService(
            ContentService contentService,
            ContentRepository contentRepository,
            KnowledgeChunkRepository knowledgeChunkRepository,
            EmbeddingModel embeddingModel
    ) {
        this.contentService = contentService;
        this.contentRepository = contentRepository;
        this.knowledgeChunkRepository = knowledgeChunkRepository;
        this.embeddingModel = embeddingModel;
    }

    public List<Map<String, Object>> search(String query) {
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

                Map<UUID, Content> contentMap = contentRepository.findAllById(contentIds).stream()
                        .collect(java.util.stream.Collectors.toMap(Content::getId, c -> c));

                List<Map<String, Object>> results = new ArrayList<>();
                for (Object[] chunk : similarChunks) {
                    UUID contentId = chunk[2] != null ? (UUID) chunk[2] : null;
                    String content = (String) chunk[3];
                    double score = chunk[5] != null ? ((Number) chunk[5]).doubleValue() : 0;

                    Map<String, Object> result = new java.util.HashMap<>();
                    result.put("content", content);
                    result.put("score", score);

                    if (contentId != null && contentMap.containsKey(contentId)) {
                        Content c = contentMap.get(contentId);
                        result.put("contentId", contentId.toString());
                        result.put("title", c.getTitle());
                    }

                    results.add(result);
                }
                return results;
            }
        } catch (Exception e) {
            log.warn("向量搜索失败，回退到文本搜索: {}", e.getMessage());
        }

        List<Map<String, Object>> results = new ArrayList<>();
        PageResponse<ContentSummaryResponse> searchResults = contentService.list(
                query, null, null, null, null, 0, 5
        );
        for (ContentSummaryResponse item : searchResults.items()) {
            results.add(Map.of(
                    "contentId", item.id().toString(),
                    "title", item.title(),
                    "content", item.summary() != null ? item.summary() : "",
                    "score", 0.0
            ));
        }
        return results;
    }
}
