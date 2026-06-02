package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.auth.Role;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.content.ContentDetailResponse;
import com.caoqiang.blog.content.ContentService;
import com.caoqiang.blog.content.ContentStatus;
import com.caoqiang.blog.content.ContentSummaryResponse;
import com.caoqiang.blog.content.ContentType;
import com.caoqiang.blog.interaction.CommentResponse;
import com.caoqiang.blog.interaction.InteractionService;
import com.caoqiang.blog.interaction.LikeStateResponse;
import java.time.Instant;
import java.util.List;
import java.util.Map;
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
    private InteractionService interactionService;

    private AiToolService aiToolService;

    private AuthenticatedUser currentUser;

    @BeforeEach
    void setUp() {
        aiToolService = new AiToolService(contentService, interactionService);
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

        Map<String, Object> result = aiToolService.searchContent("测试", 5);

        assertThat(result.get("success")).isEqualTo(true);
        assertThat((long) result.get("total")).isEqualTo(1L);
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

        Map<String, Object> result = aiToolService.getContentDetail(contentId);

        assertThat(result.get("success")).isEqualTo(true);
    }

    @Test
    void likeContentSuccessfully() {
        UUID contentId = UUID.randomUUID();
        LikeStateResponse likeResponse = new LikeStateResponse(contentId, true, 11);

        when(interactionService.like(eq(currentUser), eq(contentId))).thenReturn(likeResponse);

        Map<String, Object> result = aiToolService.likeContent(currentUser, contentId);

        assertThat(result.get("success")).isEqualTo(true);
        assertThat(result.get("liked")).isEqualTo(true);
        assertThat((long) result.get("likeCount")).isEqualTo(11L);
    }

    @Test
    void unlikeContentSuccessfully() {
        UUID contentId = UUID.randomUUID();
        LikeStateResponse unlikeResponse = new LikeStateResponse(contentId, false, 9);

        when(interactionService.unlike(eq(currentUser), eq(contentId))).thenReturn(unlikeResponse);

        Map<String, Object> result = aiToolService.unlikeContent(currentUser, contentId);

        assertThat(result.get("success")).isEqualTo(true);
        assertThat(result.get("liked")).isEqualTo(false);
        assertThat((long) result.get("likeCount")).isEqualTo(9L);
    }

    @Test
    void commentContentSuccessfully() {
        UUID contentId = UUID.randomUUID();
        UUID commentId = UUID.randomUUID();
        CommentResponse.CommentAuthor author = new CommentResponse.CommentAuthor(
                UUID.randomUUID(), "测试用户", null
        );
        CommentResponse commentResponse = new CommentResponse(
                commentId, contentId, "测试标题", "测试评论", author, Instant.now()
        );

        when(interactionService.comment(eq(currentUser), eq(contentId), any())).thenReturn(commentResponse);

        Map<String, Object> result = aiToolService.commentContent(currentUser, contentId, "测试评论");

        assertThat(result.get("success")).isEqualTo(true);
        assertThat(result.get("commentId")).isEqualTo(commentId.toString());
        assertThat(result.get("body")).isEqualTo("测试评论");
    }
}
