package com.caoqiang.blog.admin.application.service;

import com.caoqiang.blog.admin.application.dto.AdminDashboardResponse;
import com.caoqiang.blog.ai.application.api.AiOverview;
import com.caoqiang.blog.ai.application.api.AiOverviewService;
import com.caoqiang.blog.content.application.api.ContentOverview;
import com.caoqiang.blog.content.application.api.ContentOverviewService;
import com.caoqiang.blog.friend.application.api.FriendOverviewService;
import com.caoqiang.blog.interaction.application.api.InteractionOverview;
import com.caoqiang.blog.interaction.application.api.InteractionOverviewService;
import com.caoqiang.blog.user.application.api.UserOverviewService;
import org.springframework.stereotype.Service;

/** Composes module-owned metrics for the administration dashboard. */
@Service
public class AdminDashboardService {

    private final ContentOverviewService contentOverviewService;
    private final FriendOverviewService friendOverviewService;
    private final UserOverviewService userOverviewService;
    private final InteractionOverviewService interactionOverviewService;
    private final AiOverviewService aiOverviewService;

    public AdminDashboardService(
            ContentOverviewService contentOverviewService,
            FriendOverviewService friendOverviewService,
            UserOverviewService userOverviewService,
            InteractionOverviewService interactionOverviewService,
            AiOverviewService aiOverviewService
    ) {
        this.contentOverviewService = contentOverviewService;
        this.friendOverviewService = friendOverviewService;
        this.userOverviewService = userOverviewService;
        this.interactionOverviewService = interactionOverviewService;
        this.aiOverviewService = aiOverviewService;
    }

    public AdminDashboardResponse dashboard() {
        ContentOverview content = contentOverviewService.overview();
        InteractionOverview interaction = interactionOverviewService.overview();
        AiOverview ai = aiOverviewService.overview();
        return new AdminDashboardResponse(
                content.contentCount(),
                content.mediaCount(),
                friendOverviewService.countFriends(),
                userOverviewService.countUsers(),
                interaction.commentCount(),
                interaction.likeCount(),
                interaction.viewCount(),
                ai.chatSessionCount(),
                ai.knowledgeDocCount()
        );
    }
}
