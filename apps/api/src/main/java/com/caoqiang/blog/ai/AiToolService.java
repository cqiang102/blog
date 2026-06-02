package com.caoqiang.blog.ai;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.content.ContentDetailResponse;
import com.caoqiang.blog.content.ContentService;
import com.caoqiang.blog.content.ContentSummaryResponse;
import com.caoqiang.blog.interaction.CommentRequest;
import com.caoqiang.blog.interaction.CommentResponse;
import com.caoqiang.blog.interaction.InteractionService;
import com.caoqiang.blog.interaction.LikeStateResponse;
import java.util.Map;
import java.util.UUID;
import org.springframework.stereotype.Service;

@Service
public class AiToolService {

    private final ContentService contentService;
    private final InteractionService interactionService;

    public AiToolService(ContentService contentService, InteractionService interactionService) {
        this.contentService = contentService;
        this.interactionService = interactionService;
    }

    public Map<String, Object> searchContent(String query, int limit) {
        PageResponse<ContentSummaryResponse> results = contentService.list(
                query, null, null, null, null, 0, Math.min(limit, 10)
        );

        return Map.of(
                "success", true,
                "results", results.items().stream().map(item -> Map.of(
                        "id", item.id().toString(),
                        "title", item.title(),
                        "summary", item.summary() != null ? item.summary() : "",
                        "type", item.type().name()
                )).toList(),
                "total", results.total()
        );
    }

    public Map<String, Object> getContentDetail(UUID contentId) {
        try {
            ContentDetailResponse detail = contentService.detail(contentId, null);
            return Map.of(
                    "success", true,
                    "content", Map.of(
                            "id", detail.id().toString(),
                            "title", detail.title(),
                            "summary", detail.summary() != null ? detail.summary() : "",
                            "markdown", detail.bodyMarkdown() != null ? detail.bodyMarkdown() : "",
                            "type", detail.type().name(),
                            "likeCount", detail.likeCount(),
                            "viewCount", detail.viewCount(),
                            "commentCount", detail.commentCount()
                    )
            );
        } catch (Exception e) {
            return Map.of(
                    "success", false,
                    "error", "内容不存在或已归档"
            );
        }
    }

    public Map<String, Object> likeContent(AuthenticatedUser currentUser, UUID contentId) {
        try {
            LikeStateResponse result = interactionService.like(currentUser, contentId);
            return Map.of(
                    "success", true,
                    "liked", result.liked(),
                    "likeCount", result.likeCount()
            );
        } catch (Exception e) {
            return Map.of(
                    "success", false,
                    "error", e.getMessage()
            );
        }
    }

    public Map<String, Object> unlikeContent(AuthenticatedUser currentUser, UUID contentId) {
        try {
            LikeStateResponse result = interactionService.unlike(currentUser, contentId);
            return Map.of(
                    "success", true,
                    "liked", result.liked(),
                    "likeCount", result.likeCount()
            );
        } catch (Exception e) {
            return Map.of(
                    "success", false,
                    "error", e.getMessage()
            );
        }
    }

    public Map<String, Object> commentContent(AuthenticatedUser currentUser, UUID contentId, String body) {
        try {
            CommentResponse result = interactionService.comment(currentUser, contentId, new CommentRequest(body));
            return Map.of(
                    "success", true,
                    "commentId", result.id().toString(),
                    "body", result.body()
            );
        } catch (Exception e) {
            return Map.of(
                    "success", false,
                    "error", e.getMessage()
            );
        }
    }

    public Map<String, Object> deleteComment(AuthenticatedUser currentUser, UUID commentId) {
        try {
            interactionService.deleteComment(currentUser, commentId);
            return Map.of(
                    "success", true,
                    "deleted", true
            );
        } catch (Exception e) {
            return Map.of(
                    "success", false,
                    "error", e.getMessage()
            );
        }
    }
}
