package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.ai.chat.application.dto.AiActionResult;
import com.caoqiang.blog.ai.chat.application.dto.AiContentDetailResult;
import com.caoqiang.blog.ai.chat.application.dto.AiSearchContentResult;
import com.caoqiang.blog.ai.chat.application.service.AiToolService;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.content.application.dto.ContentDetailResponse;
import com.caoqiang.blog.content.application.service.ContentService;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.application.dto.ContentSummaryResponse;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.interaction.application.dto.CommentResponse;
import com.caoqiang.blog.interaction.application.service.InteractionCommandService;
import com.caoqiang.blog.interaction.application.dto.LikeStateResponse;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class AiToolServiceTest {

    @Mock
    private ContentService contentService;

    @Mock
    private InteractionCommandService interactionCommandService;

    private AiToolService aiToolService;

    private AuthenticatedUser currentUser;

    @BeforeEach
    void setUp() {
        aiToolService = new AiToolService(contentService, interactionCommandService);
        currentUser = new AuthenticatedUser(UUID.randomUUID(), "test@example.com", "测试用户", Role.USER);
    }

    @Test
    void searchContentSuccessfully() {
        ContentSummaryResponse summary = new ContentSummaryResponse(
                UUID.randomUUID(), "测试标题", "test-slug", ContentType.ARTICLE,
                "测试摘要", "", false, 10, Instant.now(), List.of("tag1")
        );
        PageResponse<ContentSummaryResponse> page = new PageResponse<>(List.of(summary), 0, 10, 1);

        when(contentService.list(any(), isNull(), isNull(), isNull(), isNull(), eq(0), eq(5))).thenReturn(page);

        AiSearchContentResult result = aiToolService.searchContent("测试", 5);

        assertThat(result.total()).isEqualTo(1L);
        assertThat(result.results()).hasSize(1);
    }

    @Test
    void getContentDetailSuccessfully() {
        UUID contentId = UUID.randomUUID();
        ContentDetailResponse detail = new ContentDetailResponse(
                contentId, "测试标题", "test-slug", ContentType.ARTICLE, ContentStatus.PUBLISHED,
                "测试摘要", "测试内容", "", List.of("tag1"), List.of(),
                false, 10, 100, 5, Instant.now()
        );

        when(contentService.detail(eq(contentId), isNull())).thenReturn(detail);

        AiContentDetailResult result = aiToolService.getContentDetail(contentId);

        assertThat(result.error()).isNull();
        assertThat(result.id()).isEqualTo(contentId.toString());
    }

    @Test
    void likeContentSuccessfully() {
        UUID contentId = UUID.randomUUID();
        LikeStateResponse likeResponse = new LikeStateResponse(contentId, true, 11);

        when(interactionCommandService.like(eq(currentUser), eq(contentId))).thenReturn(likeResponse);

        AiActionResult result = aiToolService.likeContent(currentUser, contentId);

        assertThat(result.error()).isNull();
        assertThat(result.liked()).isEqualTo(true);
        assertThat(result.likeCount()).isEqualTo(11L);
    }

    @Test
    void unlikeContentSuccessfully() {
        UUID contentId = UUID.randomUUID();
        LikeStateResponse unlikeResponse = new LikeStateResponse(contentId, false, 9);

        when(interactionCommandService.unlike(eq(currentUser), eq(contentId))).thenReturn(unlikeResponse);

        AiActionResult result = aiToolService.unlikeContent(currentUser, contentId);

        assertThat(result.error()).isNull();
        assertThat(result.liked()).isEqualTo(false);
        assertThat(result.likeCount()).isEqualTo(9L);
    }

    @Test
    void commentContentSuccessfully() {
        UUID contentId = UUID.randomUUID();
        UUID commentId = UUID.randomUUID();
        CommentResponse.CommentAuthor author = new CommentResponse.CommentAuthor(
                UUID.randomUUID(), "测试用户", null
        );
        CommentResponse commentResponse = new CommentResponse(
                commentId, contentId, "测试标题", "测试评论", author, CommentStatus.VISIBLE, Instant.now()
        );

        when(interactionCommandService.comment(eq(currentUser), eq(contentId), any())).thenReturn(commentResponse);

        AiActionResult result = aiToolService.commentContent(currentUser, contentId, "测试评论");

        assertThat(result.error()).isNull();
        assertThat(result.commentId()).isEqualTo(commentId.toString());
        assertThat(result.body()).isEqualTo("测试评论");
    }
}
