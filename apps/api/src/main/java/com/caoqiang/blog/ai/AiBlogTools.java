package com.caoqiang.blog.ai;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.content.Content;
import com.caoqiang.blog.content.ContentDetailResponse;
import com.caoqiang.blog.content.ContentRepository;
import com.caoqiang.blog.content.ContentService;
import com.caoqiang.blog.content.ContentStatus;
import com.caoqiang.blog.content.ContentSummaryResponse;
import com.caoqiang.blog.interaction.CommentRequest;
import com.caoqiang.blog.interaction.CommentResponse;
import com.caoqiang.blog.interaction.InteractionService;
import com.caoqiang.blog.interaction.LikeStateResponse;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Component;

/**
 * Spring AI @Tool 工具类，为 AI 模型提供博客操作能力。
 * <p>
 * 通过 {@code @Tool} 注解声明 7 个工具方法，使 AI 能够：
 * <ul>
 *   <li>搜索和查看博客文章</li>
 *   <li>搜索知识库（向量相似度 + 文本回退）</li>
 *   <li>对文章点赞/取消点赞</li>
 *   <li>对文章发表评论/删除评论</li>
 * </ul>
 * 需要用户身份的操作通过 {@link AiUserContext} 获取当前登录用户。
 */
@Component
public class AiBlogTools {

    private final ContentService contentService;
    private final ContentRepository contentRepository;
    private final InteractionService interactionService;
    private final KnowledgeChunkRepository knowledgeChunkRepository;
    private final KnowledgeDocRepository knowledgeDocRepository;
    private final EmbeddingModel embeddingModel;

    public AiBlogTools(
            ContentService contentService,
            ContentRepository contentRepository,
            InteractionService interactionService,
            KnowledgeChunkRepository knowledgeChunkRepository,
            KnowledgeDocRepository knowledgeDocRepository,
            EmbeddingModel embeddingModel
    ) {
        this.contentService = contentService;
        this.contentRepository = contentRepository;
        this.interactionService = interactionService;
        this.knowledgeChunkRepository = knowledgeChunkRepository;
        this.knowledgeDocRepository = knowledgeDocRepository;
        this.embeddingModel = embeddingModel;
    }

    /**
     * 搜索博客文章。根据关键词搜索已发布的博客内容，返回匹配的文章列表。
     *
     * @param query 搜索关键词
     * @param limit 返回结果数量上限（最大 10）
     * @return 包含 results 列表和 total 总数的 Map
     */
    @Tool(description = "搜索博客文章。根据关键词搜索已发布的博客内容，返回匹配的文章列表（含标题、摘要、类型）。当用户想查找或浏览博客内容时调用。")
    public Map<String, Object> searchContent(
            @ToolParam(description = "搜索关键词") String query,
            @ToolParam(description = "返回结果数量上限，最大10") int limit
    ) {
        PageResponse<ContentSummaryResponse> results = contentService.list(
                query, null, null, null, null, 0, Math.min(limit, 10)
        );
        return Map.of(
                "results", results.items().stream().map(item -> Map.of(
                        "id", item.id().toString(),
                        "title", item.title(),
                        "summary", item.summary() != null ? item.summary() : "",
                        "type", item.type().name()
                )).toList(),
                "total", results.total()
        );
    }

    /**
     * 获取博客文章详情。根据文章 ID 获取完整内容。
     *
     * @param contentId 文章的 UUID
     * @return 包含文章详情（标题、正文、点赞数等）或错误信息的 Map
     */
    @Tool(description = "获取博客文章详情。根据文章ID获取完整内容，包括正文、点赞数、浏览数、评论数等。当用户想了解某篇文章的具体内容时调用。")
    public Map<String, Object> getContentDetail(
            @ToolParam(description = "文章的UUID") UUID contentId
    ) {
        try {
            ContentDetailResponse detail = contentService.detail(contentId, null);
            return Map.of(
                    "id", detail.id().toString(),
                    "title", detail.title(),
                    "summary", detail.summary() != null ? detail.summary() : "",
                    "markdown", detail.bodyMarkdown() != null ? detail.bodyMarkdown() : "",
                    "type", detail.type().name(),
                    "likeCount", detail.likeCount(),
                    "viewCount", detail.viewCount(),
                    "commentCount", detail.commentCount()
            );
        } catch (Exception e) {
            return Map.of("error", "内容不存在或已归档");
        }
    }

    /**
     * 搜索知识库。优先使用向量相似度搜索，失败时回退到文本搜索。
     *
     * @param query 搜索关键词
     * @return 包含内容片段、相似度分数、来源文章信息的列表
     */
    @Tool(description = "搜索知识库。根据关键词搜索博客内容的向量索引，返回匹配的内容片段及其来源文章。用于回答用户关于博客内容、技术观点等问题。")
    public List<Map<String, Object>> searchKnowledge(
            @ToolParam(description = "搜索关键词") String query
    ) {
        try {
            float[] queryEmbedding = embeddingModel.embed(query);
            String embeddingStr = vectorToString(queryEmbedding);
            List<Object[]> similarChunks = knowledgeChunkRepository.findSimilarChunks(embeddingStr, 5);

            if (!similarChunks.isEmpty()) {
                List<Map<String, Object>> results = new ArrayList<>();
                for (Object[] chunk : similarChunks) {
                    UUID contentId = chunk[2] != null ? (UUID) chunk[2] : null;
                    String content = (String) chunk[3];
                    double score = chunk[5] != null ? ((Number) chunk[5]).doubleValue() : 0;

                    Map<String, Object> result = new java.util.HashMap<>();
                    result.put("content", content);
                    result.put("score", score);

                    // 如果有 contentId，获取文章标题
                    if (contentId != null) {
                        contentRepository.findById(contentId).ifPresent(c -> {
                            result.put("contentId", contentId.toString());
                            result.put("title", c.getTitle());
                        });
                    }

                    results.add(result);
                }
                return results;
            }
        } catch (Exception ignored) {
        }

        // 向量搜索失败时，回退到文本搜索
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

    /**
     * 对博客文章点赞。需要用户登录。
     *
     * @param contentId 文章的 UUID
     * @return 包含 liked 状态和 likeCount 的 Map，未登录时返回错误信息
     */
    @Tool(description = "对博客文章点赞。当用户表示喜欢某篇文章或想给文章点赞时调用。")
    public Map<String, Object> likeContent(
            @ToolParam(description = "文章的UUID") UUID contentId
    ) {
        AuthenticatedUser currentUser = AiUserContext.get();
        if (currentUser == null) {
            return Map.of("error", "请先登录");
        }
        try {
            LikeStateResponse result = interactionService.like(currentUser, contentId);
            return Map.of("liked", result.liked(), "likeCount", result.likeCount());
        } catch (Exception e) {
            return Map.of("error", e.getMessage());
        }
    }

    /**
     * 取消对博客文章的点赞。需要用户登录。
     *
     * @param contentId 文章的 UUID
     * @return 包含 liked 状态和 likeCount 的 Map，未登录时返回错误信息
     */
    @Tool(description = "取消对博客文章的点赞。当用户想取消之前的点赞时调用。")
    public Map<String, Object> unlikeContent(
            @ToolParam(description = "文章的UUID") UUID contentId
    ) {
        AuthenticatedUser currentUser = AiUserContext.get();
        if (currentUser == null) {
            return Map.of("error", "请先登录");
        }
        try {
            LikeStateResponse result = interactionService.unlike(currentUser, contentId);
            return Map.of("liked", result.liked(), "likeCount", result.likeCount());
        } catch (Exception e) {
            return Map.of("error", e.getMessage());
        }
    }

    /**
     * 对博客文章发表评论。需要用户登录。
     *
     * @param contentId 文章的 UUID
     * @param body      评论内容
     * @return 包含 commentId 和 body 的 Map，未登录时返回错误信息
     */
    @Tool(description = "对博客文章发表评论。当用户想对某篇文章发表评论或留言时调用。")
    public Map<String, Object> commentContent(
            @ToolParam(description = "文章的UUID") UUID contentId,
            @ToolParam(description = "评论内容") String body
    ) {
        AuthenticatedUser currentUser = AiUserContext.get();
        if (currentUser == null) {
            return Map.of("error", "请先登录");
        }
        try {
            CommentResponse result = interactionService.comment(currentUser, contentId, new CommentRequest(body));
            return Map.of(
                    "commentId", result.id().toString(),
                    "body", result.body()
            );
        } catch (Exception e) {
            return Map.of("error", e.getMessage());
        }
    }

    /**
     * 删除自己的评论。需要用户登录，只能删除自己发布的评论。
     *
     * @param commentId 评论的 UUID
     * @return 包含 deleted 状态的 Map，未登录时返回错误信息
     */
    @Tool(description = "删除自己的评论。当用户想删除之前发表的评论时调用。只能删除自己发布的评论。")
    public Map<String, Object> deleteComment(
            @ToolParam(description = "评论的UUID") UUID commentId
    ) {
        AuthenticatedUser currentUser = AiUserContext.get();
        if (currentUser == null) {
            return Map.of("error", "请先登录");
        }
        try {
            interactionService.deleteComment(currentUser, commentId);
            return Map.of("deleted", true);
        } catch (Exception e) {
            return Map.of("error", e.getMessage());
        }
    }

    /** 将 float 数组转换为 PostgreSQL vector 类型的字符串格式 "[1.0,2.0,3.0]"。 */
    private String vectorToString(float[] embedding) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < embedding.length; i++) {
            if (i > 0) sb.append(",");
            sb.append(embedding[i]);
        }
        sb.append("]");
        return sb.toString();
    }
}
