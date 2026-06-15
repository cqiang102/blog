package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.ai.chat.application.dto.AiActionResult;
import com.caoqiang.blog.ai.chat.application.dto.AiCommentItem;
import com.caoqiang.blog.ai.chat.application.dto.AiCommentListResult;
import com.caoqiang.blog.ai.chat.application.dto.AiContentDetailResult;
import com.caoqiang.blog.ai.chat.application.dto.AiContentItem;
import com.caoqiang.blog.ai.chat.application.dto.AiSearchContentResult;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.content.application.dto.ContentDetailResponse;
import com.caoqiang.blog.content.application.service.ContentQueryService;
import com.caoqiang.blog.content.application.dto.ContentSummaryResponse;
import com.caoqiang.blog.interaction.application.dto.CommentRequest;
import com.caoqiang.blog.interaction.application.dto.CommentResponse;
import com.caoqiang.blog.interaction.application.service.InteractionCommandService;
import com.caoqiang.blog.interaction.application.service.InteractionQueryService;
import com.caoqiang.blog.interaction.application.dto.LikeStateResponse;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * AI 工具执行服务。
 * <p>
 * 封装博客内容操作和用户交互功能，供 AI 调用工具时使用。
 * 与 {@link AiBlogTools} 不同，本服务以编程方式调用，不依赖 {@code @Tool} 注解。
 */
@Service
public class AiToolService {

    private final ContentQueryService contentQueryService;
    private final InteractionCommandService interactionCommandService;
    private final InteractionQueryService interactionQueryService;

    public AiToolService(
            ContentQueryService contentQueryService,
            InteractionCommandService interactionCommandService,
            InteractionQueryService interactionQueryService
    ) {
        this.contentQueryService = contentQueryService;
        this.interactionCommandService = interactionCommandService;
        this.interactionQueryService = interactionQueryService;
    }

    /**
     * 搜索博客文章。
     *
     * @param query 搜索关键词
     * @param limit 返回结果数量上限（最大 10）
     * @return 搜索结果
     */
    public AiSearchContentResult searchContent(String query, int limit) {
        PageResponse<ContentSummaryResponse> results = contentQueryService.list(
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
     * 获取博客文章详情。
     *
     * @param contentId 文章的 UUID
     * @return 内容详情结果
     */
    public AiContentDetailResult getContentDetail(UUID contentId) {
        try {
            ContentDetailResponse detail = contentQueryService.detail(contentId, null);
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
     * 对博客文章点赞。
     *
     * @param currentUser 当前登录用户
     * @param contentId   文章的 UUID
     * @return 操作结果
     */
    public AiActionResult likeContent(AuthenticatedUser currentUser, UUID contentId) {
        try {
            LikeStateResponse result = interactionCommandService.like(currentUser, contentId);
            return AiActionResult.likeSuccess(result.liked(), result.likeCount());
        } catch (Exception e) {
            return AiActionResult.error(e.getMessage());
        }
    }

    /**
     * 取消对博客文章的点赞。
     *
     * @param currentUser 当前登录用户
     * @param contentId   文章的 UUID
     * @return 操作结果
     */
    public AiActionResult unlikeContent(AuthenticatedUser currentUser, UUID contentId) {
        try {
            LikeStateResponse result = interactionCommandService.unlike(currentUser, contentId);
            return AiActionResult.likeSuccess(result.liked(), result.likeCount());
        } catch (Exception e) {
            return AiActionResult.error(e.getMessage());
        }
    }

    /**
     * 对博客文章发表评论。
     *
     * @param currentUser 当前登录用户
     * @param contentId   文章的 UUID
     * @param body        评论内容
     * @return 操作结果
     */
    public AiActionResult commentContent(AuthenticatedUser currentUser, UUID contentId, String body) {
        try {
            CommentResponse result = interactionCommandService.comment(currentUser, contentId, new CommentRequest(body));
            return AiActionResult.commentSuccess(result.id(), result.body());
        } catch (Exception e) {
            return AiActionResult.error(e.getMessage());
        }
    }

    /**
     * 查询文章的评论列表。
     *
     * @param contentId   文章的 UUID
     * @param limit       返回结果数量上限
     * @param currentUserId 当前登录用户 ID（可选，用于查看自己的被屏蔽评论）
     * @return 评论列表
     */
    public AiCommentListResult listComments(UUID contentId, int limit, UUID currentUserId) {
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
     * 删除自己的评论。
     *
     * @param currentUser 当前登录用户
     * @param commentId   评论的 UUID
     * @return 操作结果
     */
    public AiActionResult deleteComment(AuthenticatedUser currentUser, UUID commentId) {
        try {
            interactionCommandService.deleteComment(currentUser, commentId);
            return AiActionResult.deleteSuccess();
        } catch (Exception e) {
            return AiActionResult.error(e.getMessage());
        }
    }
}
