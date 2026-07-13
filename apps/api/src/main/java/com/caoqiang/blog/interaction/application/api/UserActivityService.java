package com.caoqiang.blog.interaction.application.api;

import com.caoqiang.blog.interaction.application.dto.UserActivityResponse;
import com.caoqiang.blog.interaction.application.service.InteractionCommandService;
import com.caoqiang.blog.interaction.application.service.InteractionQueryService;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.response.PageResponse;
import java.util.UUID;
import org.springframework.stereotype.Service;

/** Public interaction-module API for the current-user activity surface. */
@Service
public class UserActivityService {

    private final InteractionQueryService queryService;
    private final InteractionCommandService commandService;

    public UserActivityService(
            InteractionQueryService queryService,
            InteractionCommandService commandService
    ) {
        this.queryService = queryService;
        this.commandService = commandService;
    }

    public PageResponse<UserActivityItem> comments(AuthenticatedUser user, int page, int size) {
        return map(queryService.myComments(user, page, size));
    }

    public PageResponse<UserActivityItem> likes(AuthenticatedUser user, int page, int size) {
        return map(queryService.myLikes(user, page, size));
    }

    public PageResponse<UserActivityItem> views(AuthenticatedUser user, int page, int size) {
        return map(queryService.myViews(user, page, size));
    }

    public void deleteComment(AuthenticatedUser user, UUID commentId) {
        commandService.deleteComment(user, commentId);
    }

    public void deleteLike(AuthenticatedUser user, UUID contentId) {
        commandService.deleteMyLike(user, contentId);
    }

    public void deleteView(AuthenticatedUser user, UUID viewRecordId) {
        commandService.deleteMyView(user, viewRecordId);
    }

    private PageResponse<UserActivityItem> map(PageResponse<UserActivityResponse> source) {
        return new PageResponse<>(
                source.items().stream().map(item -> new UserActivityItem(
                        item.id(),
                        item.type(),
                        item.contentId(),
                        item.title(),
                        item.createdAt()
                )).toList(),
                source.page(),
                source.size(),
                source.total()
        );
    }
}
