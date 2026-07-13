package com.caoqiang.blog.interaction.application.api;

import com.caoqiang.blog.interaction.application.dto.CommentRequest;
import com.caoqiang.blog.interaction.application.service.InteractionCommandService;
import com.caoqiang.blog.interaction.application.service.InteractionQueryService;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;

/** Public interaction API for cross-module workflows. */
@Service
public class InteractionAccessService {

    private final InteractionCommandService commandService;
    private final InteractionQueryService queryService;

    public InteractionAccessService(
            InteractionCommandService commandService,
            InteractionQueryService queryService
    ) {
        this.commandService = commandService;
        this.queryService = queryService;
    }

    public LikeResult like(AuthenticatedUser user, UUID contentId) {
        var result = commandService.like(user, contentId);
        return new LikeResult(result.liked(), result.likeCount());
    }

    public LikeResult unlike(AuthenticatedUser user, UUID contentId) {
        var result = commandService.unlike(user, contentId);
        return new LikeResult(result.liked(), result.likeCount());
    }

    public CommentResult comment(AuthenticatedUser user, UUID contentId, String body) {
        var result = commandService.comment(user, contentId, new CommentRequest(body));
        return new CommentResult(result.id(), result.body());
    }

    public Comments comments(UUID contentId, int limit, UUID currentUserId) {
        var result = queryService.comments(contentId, 0, limit, currentUserId);
        List<CommentItem> items = result.items().stream().map(comment -> new CommentItem(
                comment.id(),
                comment.body(),
                comment.author() == null ? null : comment.author().nickname(),
                comment.createdAt()
        )).toList();
        return new Comments(items, result.total());
    }

    public void deleteComment(AuthenticatedUser user, UUID commentId) {
        commandService.deleteComment(user, commentId);
    }

    public record LikeResult(boolean liked, long likeCount) {
    }

    public record CommentResult(UUID id, String body) {
    }

    public record CommentItem(UUID id, String body, String authorNickname, Instant createdAt) {
    }

    public record Comments(List<CommentItem> items, long total) {
    }
}
