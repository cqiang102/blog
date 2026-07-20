package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.ai.chat.application.dto.AiActionResult;
import com.caoqiang.blog.ai.chat.application.dto.AiContentDetailResult;
import com.caoqiang.blog.ai.chat.application.dto.AiSearchContentResult;
import com.caoqiang.blog.ai.chat.application.service.AiToolService;
import com.caoqiang.blog.content.application.api.ContentAccessDetail;
import com.caoqiang.blog.content.application.api.ContentAccessService;
import com.caoqiang.blog.content.application.api.ContentAccessSummary;
import com.caoqiang.blog.interaction.application.api.InteractionAccessService;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.response.PageResponse;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class AiToolServiceTest {

    @Mock
    private ContentAccessService contentAccessService;

    @Mock
    private InteractionAccessService interactionAccessService;

    private AiToolService aiToolService;

    private AuthenticatedUser currentUser;

    @BeforeEach
    void setUp() {
        aiToolService = new AiToolService(contentAccessService, interactionAccessService);
        currentUser = new AuthenticatedUser(UUID.randomUUID(), "test@example.com", "测试用户", Role.USER);
    }

    @Test
    void searchContentSuccessfully() {
        ContentAccessSummary summary = new ContentAccessSummary(UUID.randomUUID(), "测试标题", "测试摘要", "ARTICLE");
        PageResponse<ContentAccessSummary> page = new PageResponse<>(List.of(summary), 0, 5, 1);

        when(contentAccessService.searchPublished("测试", 5)).thenReturn(page);

        AiSearchContentResult result = aiToolService.searchContent("测试", 5);

        assertThat(result.total()).isEqualTo(1L);
        assertThat(result.results()).hasSize(1);
    }

    @Test
    void getContentDetailSuccessfully() {
        UUID contentId = UUID.randomUUID();
        ContentAccessDetail detail = new ContentAccessDetail(contentId, "测试标题", "测试摘要", "测试内容", "ARTICLE", 10, 100, 5);

        when(contentAccessService.publishedDetail(contentId)).thenReturn(detail);

        AiContentDetailResult result = aiToolService.getContentDetail(contentId);

        assertThat(result.error()).isNull();
        assertThat(result.id()).isEqualTo(contentId.toString());
    }

    @Test
    void likeContentSuccessfully() {
        UUID contentId = UUID.randomUUID();
        var likeResponse = new InteractionAccessService.LikeResult(true, 11);

        when(interactionAccessService.like(eq(currentUser), eq(contentId))).thenReturn(likeResponse);

        AiActionResult result = aiToolService.likeContent(currentUser, contentId);

        assertThat(result.error()).isNull();
        assertThat(result.liked()).isEqualTo(true);
        assertThat(result.likeCount()).isEqualTo(11L);
    }

    @Test
    void unlikeContentSuccessfully() {
        UUID contentId = UUID.randomUUID();
        var unlikeResponse = new InteractionAccessService.LikeResult(false, 9);

        when(interactionAccessService.unlike(eq(currentUser), eq(contentId))).thenReturn(unlikeResponse);

        AiActionResult result = aiToolService.unlikeContent(currentUser, contentId);

        assertThat(result.error()).isNull();
        assertThat(result.liked()).isEqualTo(false);
        assertThat(result.likeCount()).isEqualTo(9L);
    }

    @Test
    void commentContentSuccessfully() {
        UUID contentId = UUID.randomUUID();
        UUID commentId = UUID.randomUUID();
        var commentResponse = new InteractionAccessService.CommentResult(commentId, "测试评论");

        when(interactionAccessService.comment(currentUser, contentId, "测试评论")).thenReturn(commentResponse);

        AiActionResult result = aiToolService.commentContent(currentUser, contentId, "测试评论");

        assertThat(result.error()).isNull();
        assertThat(result.commentId()).isEqualTo(commentId.toString());
        assertThat(result.body()).isEqualTo("测试评论");
    }

    @Test
    void toolFailuresKeepBusinessMessagesButHideUnexpectedExceptionDetails() {
        UUID contentId = UUID.randomUUID();
        when(interactionAccessService.like(currentUser, contentId))
                .thenThrow(new BusinessException(HttpStatus.CONFLICT, "已经点赞"));
        when(interactionAccessService.unlike(currentUser, contentId))
                .thenThrow(new IllegalStateException("database-password=secret"));

        assertThat(aiToolService.likeContent(currentUser, contentId).error()).isEqualTo("已经点赞");
        assertThat(aiToolService.unlikeContent(currentUser, contentId).error()).isEqualTo("取消点赞失败，请稍后重试");
    }
}
