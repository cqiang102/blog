package com.caoqiang.blog.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.admin.application.service.AdminDashboardService;
import com.caoqiang.blog.ai.application.api.AiOverview;
import com.caoqiang.blog.ai.application.api.AiOverviewService;
import com.caoqiang.blog.content.application.api.ContentOverview;
import com.caoqiang.blog.content.application.api.ContentOverviewService;
import com.caoqiang.blog.friend.application.api.FriendOverviewService;
import com.caoqiang.blog.interaction.application.api.InteractionOverview;
import com.caoqiang.blog.interaction.application.api.InteractionOverviewService;
import com.caoqiang.blog.user.application.api.UserOverviewService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class AdminDashboardServiceTest {

    @Mock
    private ContentOverviewService contentOverviewService;

    @Mock
    private FriendOverviewService friendOverviewService;

    @Mock
    private UserOverviewService userOverviewService;

    @Mock
    private InteractionOverviewService interactionOverviewService;

    @Mock
    private AiOverviewService aiOverviewService;

    @Test
    void composesModuleOwnedMetricsInTheExistingResponseShape() {
        when(contentOverviewService.overview()).thenReturn(new ContentOverview(1, 2));
        when(friendOverviewService.countFriends()).thenReturn(3L);
        when(userOverviewService.countUsers()).thenReturn(4L);
        when(interactionOverviewService.overview()).thenReturn(new InteractionOverview(5, 6, 7));
        when(aiOverviewService.overview()).thenReturn(new AiOverview(8, 9));
        AdminDashboardService service = new AdminDashboardService(
                contentOverviewService,
                friendOverviewService,
                userOverviewService,
                interactionOverviewService,
                aiOverviewService);

        var result = service.dashboard();

        assertThat(result.contents()).isEqualTo(1);
        assertThat(result.media()).isEqualTo(2);
        assertThat(result.friends()).isEqualTo(3);
        assertThat(result.users()).isEqualTo(4);
        assertThat(result.comments()).isEqualTo(5);
        assertThat(result.likes()).isEqualTo(6);
        assertThat(result.views()).isEqualTo(7);
        assertThat(result.aiChats()).isEqualTo(8);
        assertThat(result.knowledgeDocs()).isEqualTo(9);
    }
}
