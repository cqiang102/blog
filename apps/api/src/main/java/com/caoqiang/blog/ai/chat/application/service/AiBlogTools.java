package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.ai.chat.application.dto.AiCommentItem;
import com.caoqiang.blog.ai.chat.application.dto.AiCommentListResult;
import com.caoqiang.blog.ai.chat.application.dto.AiContentDetailResult;
import com.caoqiang.blog.ai.chat.application.dto.AiContentItem;
import com.caoqiang.blog.ai.chat.application.dto.AiSearchContentResult;

import com.caoqiang.blog.ai.chat.application.dto.AiActionResult;
import com.caoqiang.blog.ai.knowledge.application.dto.KnowledgeSearchResult;
import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeDoc;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeDocRepository;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.shared.util.VectorUtils;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.application.dto.ContentDetailResponse;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.application.service.ContentService;
import com.caoqiang.blog.content.application.dto.ContentSummaryResponse;
import com.caoqiang.blog.interaction.application.dto.CommentRequest;
import com.caoqiang.blog.interaction.application.dto.CommentResponse;
import com.caoqiang.blog.interaction.application.service.InteractionCommandService;
import com.caoqiang.blog.interaction.application.service.InteractionQueryService;
import com.caoqiang.blog.interaction.application.dto.LikeStateResponse;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.ai.chat.model.ToolContext;
import org.springframework.ai.tool.annotation.Tool;
import org.springframework.ai.tool.annotation.ToolParam;
import org.springframework.stereotype.Component;

/**
 * Spring AI @Tool 工具类，为 AI 模型提供博客操作能力。
 * <p>
 * 通过 {@code @Tool} 注解声明 8 个工具方法，使 AI 能够：
 * <ul>
 *   <li>搜索和查看博客文章</li>
 *   <li>搜索知识库（向量相似度 + 文本回退）</li>
 *   <li>对文章点赞/取消点赞</li>
 *   <li>对文章发表评论/查询评论/删除评论</li>
 * </ul>
 * 需要用户身份的操作通过 Spring AI 的请求级 {@link ToolContext} 获取当前登录用户。
 */
@Component
public class AiBlogTools {

    public static final String AUTHENTICATED_USER_CONTEXT_KEY = "authenticatedUser";

    private static final Logger log = LoggerFactory.getLogger(AiBlogTools.class);

    private final ContentService contentService;
    private final ContentRepository contentRepository;
    private final InteractionCommandService interactionCommandService;
    private final InteractionQueryService interactionQueryService;
    private final KnowledgeChunkRepository knowledgeChunkRepository;
    private final KnowledgeDocRepository knowledgeDocRepository;
    private final EmbeddingModel embeddingModel;

    public AiBlogTools(
            ContentService contentService,
            ContentRepository contentRepository,
            InteractionCommandService interactionCommandService,
            InteractionQueryService interactionQueryService,
            KnowledgeChunkRepository knowledgeChunkRepository,
            KnowledgeDocRepository knowledgeDocRepository,
            EmbeddingModel embeddingModel
    ) {
        this.contentService = contentService;
        this.contentRepository = contentRepository;
        this.interactionCommandService = interactionCommandService;
        this.interactionQueryService = interactionQueryService;
        this.knowledgeChunkRepository = knowledgeChunkRepository;
        this.knowledgeDocRepository = knowledgeDocRepository;
        this.embeddingModel = embeddingModel;
    }

    /**
     * 搜索博客文章。根据关键词搜索已发布的博客内容，返回匹配的文章列表。
     *
     * @param query 搜索关键词
     * @param limit 返回结果数量上限（最大 10）
     * @return 搜索结果
     */
    @Tool(description = "搜索博客文章。根据关键词搜索已发布的博客内容，返回匹配的文章列表（含标题、摘要、类型）。当用户想查找或浏览博客内容时调用。")
    public AiSearchContentResult searchContent(
            @ToolParam(description = "搜索关键词") String query,
            @ToolParam(description = "返回结果数量上限，最大10") int limit
    ) {
        PageResponse<ContentSummaryResponse> results = contentService.list(
                query, null, null, null, null, 0, Math.min(limit, 10)
        );
        return new AiSearchContentResult(
                results.items().stream()
                        .map(item -> new AiContentItem(
                                item.id().toString(),
                                item.title(),
                                item.summary() != null ? item.summary() : "",
                                item.type().name()
                        ))
                        .toList(),
                results.total()
        );
    }

    /**
     * 获取博客文章详情。根据文章 ID 获取完整内容。
     *
     * @param contentId 文章的 UUID
     * @return 内容详情结果
     */
    @Tool(description = "获取博客文章详情。根据文章ID获取完整内容，包括正文、点赞数、浏览数、评论数等。当用户想了解某篇文章的具体内容时调用。")
    public AiContentDetailResult getContentDetail(
            @ToolParam(description = "文章的UUID") UUID contentId
    ) {
        try {
            ContentDetailResponse detail = contentService.detail(contentId, null);
            return AiContentDetailResult.success(
                    detail.id().toString(),
                    detail.title(),
                    detail.summary() != null ? detail.summary() : "",
                    detail.bodyMarkdown() != null ? detail.bodyMarkdown() : "",
                    detail.type().name(),
                    detail.likeCount(),
                    detail.viewCount(),
                    detail.commentCount()
            );
        } catch (Exception e) {
            return AiContentDetailResult.error("内容不存在或已归档");
        }
    }

    /**
     * 搜索知识库。优先使用向量相似度搜索，失败时回退到文本搜索。
     *
     * @param query 搜索关键词
     * @return 搜索结果列表
     */
    @Tool(description = "搜索知识库。根据关键词搜索博客内容的向量索引，返回匹配的内容片段及其来源文章。用于回答用户关于博客内容、技术观点等问题。")
    public List<KnowledgeSearchResult> searchKnowledge(
            @ToolParam(description = "搜索关键词") String query
    ) {
        try {
            float[] queryEmbedding = embeddingModel.embed(query);
            String embeddingStr = VectorUtils.toPgVectorString(queryEmbedding);
            List<Object[]> similarChunks = knowledgeChunkRepository.findSimilarChunks(embeddingStr, 5);

            if (!similarChunks.isEmpty()) {
                // 收集所有 contentId 和 docId，批量查询
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

        // 向量搜索失败时，回退到文本搜索
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

    /**
     * 对博客文章点赞。需要用户登录。
     *
     * @param contentId 文章的 UUID
     * @return 操作结果
     */
    @Tool(description = "对博客文章点赞。当用户表示喜欢某篇文章或想给文章点赞时调用。")
    public AiActionResult likeContent(
            @ToolParam(description = "文章的UUID") UUID contentId,
            ToolContext toolContext
    ) {
        AuthenticatedUser currentUser = currentUser(toolContext);
        if (currentUser == null) {
            return AiActionResult.error("请先登录");
        }
        try {
            LikeStateResponse result = interactionCommandService.like(currentUser, contentId);
            return AiActionResult.likeSuccess(result.liked(), result.likeCount());
        } catch (Exception e) {
            return AiActionResult.error(e.getMessage());
        }
    }

    /**
     * 取消对博客文章的点赞。需要用户登录。
     *
     * @param contentId 文章的 UUID
     * @return 操作结果
     */
    @Tool(description = "取消对博客文章的点赞。当用户想取消之前的点赞时调用。")
    public AiActionResult unlikeContent(
            @ToolParam(description = "文章的UUID") UUID contentId,
            ToolContext toolContext
    ) {
        AuthenticatedUser currentUser = currentUser(toolContext);
        if (currentUser == null) {
            return AiActionResult.error("请先登录");
        }
        try {
            LikeStateResponse result = interactionCommandService.unlike(currentUser, contentId);
            return AiActionResult.likeSuccess(result.liked(), result.likeCount());
        } catch (Exception e) {
            return AiActionResult.error(e.getMessage());
        }
    }

    /**
     * 对博客文章发表评论。需要用户登录。
     *
     * @param contentId 文章的 UUID
     * @param body      评论内容
     * @return 操作结果
     */
    @Tool(description = "对博客文章发表评论。当用户想对某篇文章发表评论或留言时调用。")
    public AiActionResult commentContent(
            @ToolParam(description = "文章的UUID") UUID contentId,
            @ToolParam(description = "评论内容") String body,
            ToolContext toolContext
    ) {
        AuthenticatedUser currentUser = currentUser(toolContext);
        if (currentUser == null) {
            return AiActionResult.error("请先登录");
        }
        try {
            CommentResponse result = interactionCommandService.comment(currentUser, contentId, new CommentRequest(body));
            return AiActionResult.commentSuccess(result.id(), result.body());
        } catch (Exception e) {
            return AiActionResult.error(e.getMessage());
        }
    }

    /**
     * 查询文章的评论列表。返回评论的 ID、内容、作者和时间，可用于后续删除评论操作。
     *
     * @param contentId 文章的 UUID
     * @param limit     返回结果数量上限（最大 20）
     * @return 评论列表
     */
    @Tool(description = "查询文章的评论列表。返回评论的ID、内容、作者和时间信息。当用户想查看某篇文章的评论、查找自己的评论、或需要获取评论ID以便删除评论时调用。")
    public AiCommentListResult listComments(
            @ToolParam(description = "文章的UUID") UUID contentId,
            @ToolParam(description = "返回结果数量上限，最大20") int limit,
            ToolContext toolContext
    ) {
        AuthenticatedUser currentUser = currentUser(toolContext);
        UUID currentUserId = currentUser != null ? currentUser.id() : null;
        try {
            PageResponse<CommentResponse> result = interactionQueryService.comments(
                    contentId, 0, Math.min(limit, 20), currentUserId
            );
            List<AiCommentItem> items = result.items().stream()
                    .map(c -> new AiCommentItem(
                            c.id(),
                            c.body(),
                            c.author() != null ? c.author().nickname() : "匿名",
                            c.createdAt()
                    ))
                    .toList();
            return AiCommentListResult.success(items, result.total());
        } catch (Exception e) {
            return AiCommentListResult.error(e.getMessage());
        }
    }

    /**
     * 删除自己的评论。需要用户登录，只能删除自己发布的评论。
     *
     * @param commentId 评论的 UUID
     * @return 操作结果
     */
    @Tool(description = "删除自己的评论。当用户想删除之前发表的评论时调用。只能删除自己发布的评论。")
    public AiActionResult deleteComment(
            @ToolParam(description = "评论的UUID") UUID commentId,
            ToolContext toolContext
    ) {
        AuthenticatedUser currentUser = currentUser(toolContext);
        if (currentUser == null) {
            return AiActionResult.error("请先登录");
        }
        try {
            interactionCommandService.deleteComment(currentUser, commentId);
            return AiActionResult.deleteSuccess();
        } catch (Exception e) {
            return AiActionResult.error(e.getMessage());
        }
    }

    private AuthenticatedUser currentUser(ToolContext toolContext) {
        Object value = toolContext.getContext().get(AUTHENTICATED_USER_CONTEXT_KEY);
        return value instanceof AuthenticatedUser user ? user : null;
    }

}
