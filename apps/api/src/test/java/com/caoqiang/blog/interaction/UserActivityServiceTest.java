package com.caoqiang.blog.interaction;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.interaction.application.api.UserActivityService;
import com.caoqiang.blog.interaction.application.dto.UserActivityResponse;
import com.caoqiang.blog.interaction.application.service.InteractionCommandService;
import com.caoqiang.blog.interaction.application.service.InteractionQueryService;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.response.PageResponse;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class UserActivityServiceTest {

    @Mock
    private InteractionQueryService queryService;
    @Mock
    private InteractionCommandService commandService;

    @Test
    void mapsActivityPagesAndDelegatesDeletesThroughThePublicContract() {
        AuthenticatedUser user = new AuthenticatedUser(
                UUID.randomUUID(), "reader@example.com", "reader", Role.USER
        );
        UUID commentId = UUID.randomUUID();
        UUID contentId = UUID.randomUUID();
        UUID viewId = UUID.randomUUID();
        Instant createdAt = Instant.parse("2026-07-13T10:00:00Z");
        when(queryService.myComments(user, 0, 20)).thenReturn(
                new PageResponse<>(List.of(
                        UserActivityResponse.comment(commentId, contentId, "Architecture", createdAt)
                ), 0, 20, 1)
        );
        UserActivityService service = new UserActivityService(queryService, commandService);

        var result = service.comments(user, 0, 20);
        service.deleteComment(user, commentId);
        service.deleteLike(user, contentId);
        service.deleteView(user, viewId);

        assertThat(result.total()).isEqualTo(1);
        assertThat(result.items()).singleElement().satisfies(item -> {
            assertThat(item.id()).isEqualTo(commentId);
            assertThat(item.contentId()).isEqualTo(contentId);
            assertThat(item.title()).isEqualTo("Architecture");
            assertThat(item.createdAt()).isEqualTo(createdAt);
        });
        verify(commandService).deleteComment(user, commentId);
        verify(commandService).deleteMyLike(user, contentId);
        verify(commandService).deleteMyView(user, viewId);
    }
}
