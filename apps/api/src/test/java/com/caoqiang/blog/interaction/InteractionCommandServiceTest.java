package com.caoqiang.blog.interaction;

import com.caoqiang.blog.content.application.api.ContentInteractionService;
import com.caoqiang.blog.content.application.api.ContentInteractionSnapshot;
import com.caoqiang.blog.interaction.application.service.InteractionReferenceData;
import com.caoqiang.blog.interaction.application.dto.CommentRequest;
import com.caoqiang.blog.interaction.application.dto.CommentResponse;
import com.caoqiang.blog.interaction.application.dto.LikeStateResponse;
import com.caoqiang.blog.interaction.application.dto.ViewStateResponse;
import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.interaction.domain.model.Like;
import com.caoqiang.blog.interaction.domain.model.ViewRecord;
import com.caoqiang.blog.interaction.domain.repository.CommentRepository;
import com.caoqiang.blog.interaction.domain.repository.LikeRepository;
import com.caoqiang.blog.interaction.domain.repository.ViewRecordRepository;
import com.caoqiang.blog.interaction.application.service.InteractionCommandService;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.domain.event.DomainEventPublisher;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class InteractionCommandServiceTest {

    @Mock
    private ContentInteractionService contentInteractionService;

    @Mock
    private UserAccountService userAccountService;

    @Mock
    private CommentRepository commentRepository;

    @Mock
    private LikeRepository likeRepository;

    @Mock
    private ViewRecordRepository viewRecordRepository;

    @Mock
    private DomainEventPublisher domainEventPublisher;

    @Mock
    private InteractionReferenceData referenceData;

    private InteractionCommandService interactionCommandService;

    private ContentInteractionSnapshot testContent;
    private IdentityUser testUser;
    private AuthenticatedUser currentUser;

    @BeforeEach
    void setUp() {
        interactionCommandService = new InteractionCommandService(
                contentInteractionService, userAccountService, commentRepository, likeRepository,
                viewRecordRepository, domainEventPublisher, referenceData
        );

        testContent = new ContentInteractionSnapshot(UUID.randomUUID(), "测试内容", 0, 0, 0);
        testUser = new IdentityUser(
                UUID.randomUUID(), "test@example.com", "测试用户", null,
                null, null, "hash", Role.USER, true
        );
        currentUser = new AuthenticatedUser(testUser.id(), "test@example.com", "测试用户", Role.USER);
    }

    @Test
    void recordViewForAuthenticatedUser() {
        when(contentInteractionService.findPublished(testContent.id())).thenReturn(Optional.of(testContent));
        when(userAccountService.findActiveById(testUser.id())).thenReturn(Optional.of(testUser));
        when(viewRecordRepository.insertIfAbsent(
                any(UUID.class),
                eq(testContent.id()),
                eq(testUser.id()),
                any(),
                any(),
                eq("Mozilla/5.0")
        )).thenReturn(1);

        ViewStateResponse response = interactionCommandService.recordView(
                currentUser, testContent.id(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isTrue();
        verify(viewRecordRepository).insertIfAbsent(
                any(UUID.class),
                eq(testContent.id()),
                eq(testUser.id()),
                any(),
                any(),
                eq("Mozilla/5.0")
        );
        verify(contentInteractionService).incrementViewCount(testContent.id(), 1);
    }

    @Test
    void skipDuplicateViewForAuthenticatedUser() {
        when(contentInteractionService.findPublished(testContent.id())).thenReturn(Optional.of(testContent));
        when(userAccountService.findActiveById(testUser.id())).thenReturn(Optional.of(testUser));
        when(viewRecordRepository.insertIfAbsent(
                any(UUID.class),
                eq(testContent.id()),
                eq(testUser.id()),
                any(),
                any(),
                eq("Mozilla/5.0")
        )).thenReturn(0);

        ViewStateResponse response = interactionCommandService.recordView(
                currentUser, testContent.id(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isTrue();
        verify(contentInteractionService, never()).incrementViewCount(any(UUID.class), anyLong());
    }

    @Test
    void recordViewForAnonymousUser() {
        when(contentInteractionService.findPublished(testContent.id())).thenReturn(Optional.of(testContent));
        when(viewRecordRepository.insertIfAbsent(
                any(UUID.class),
                eq(testContent.id()),
                eq(null),
                any(),
                any(),
                eq("Mozilla/5.0")
        )).thenReturn(1);

        ViewStateResponse response = interactionCommandService.recordView(
                null, testContent.id(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isTrue();
        verify(contentInteractionService).incrementViewCount(testContent.id(), 1);
    }

    @Test
    void skipDuplicateViewForAnonymousUser() {
        when(contentInteractionService.findPublished(testContent.id())).thenReturn(Optional.of(testContent));
        when(viewRecordRepository.insertIfAbsent(
                any(UUID.class),
                eq(testContent.id()),
                eq(null),
                any(),
                any(),
                eq("Mozilla/5.0")
        )).thenReturn(0);

        ViewStateResponse response = interactionCommandService.recordView(
                null, testContent.id(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isTrue();
        verify(contentInteractionService, never()).incrementViewCount(any(UUID.class), anyLong());
    }

    @Test
    void skipViewWhenContentIsNotPublished() {
        when(contentInteractionService.findPublished(testContent.id())).thenReturn(Optional.empty());

        ViewStateResponse response = interactionCommandService.recordView(
                null, testContent.id(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isFalse();
        assertThat(response.viewCount()).isZero();
        verify(contentInteractionService, never()).incrementViewCount(any(UUID.class), anyLong());
    }

    @Test
    void incrementLikeCountOnlyWhenInsertSucceeds() {
        when(contentInteractionService.findPublished(testContent.id())).thenReturn(Optional.of(testContent));
        when(userAccountService.findActiveById(testUser.id())).thenReturn(Optional.of(testUser));
        when(likeRepository.insertIfAbsent(any(UUID.class), eq(testContent.id()), eq(testUser.id())))
                .thenReturn(1);

        LikeStateResponse response = interactionCommandService.like(currentUser, testContent.id());

        assertThat(response.liked()).isTrue();
        verify(contentInteractionService).incrementLikeCount(testContent.id(), 1);
        verify(domainEventPublisher).publishEvent(any());
    }

    @Test
    void skipLikeCountWhenConcurrentInsertAlreadyWon() {
        when(contentInteractionService.findPublished(testContent.id())).thenReturn(Optional.of(testContent));
        when(userAccountService.findActiveById(testUser.id())).thenReturn(Optional.of(testUser));
        when(likeRepository.insertIfAbsent(any(UUID.class), eq(testContent.id()), eq(testUser.id())))
                .thenReturn(0);

        LikeStateResponse response = interactionCommandService.like(currentUser, testContent.id());

        assertThat(response.liked()).isTrue();
        verify(contentInteractionService, never()).incrementLikeCount(any(UUID.class), anyLong());
        verify(domainEventPublisher, never()).publishEvent(any());
    }

    @Test
    void deletingVisibleCommentUsesLockedLookupAndDecrementsCount() {
        Comment comment = new Comment(testContent.id(), testUser.id(), "待删除评论");
        when(commentRepository.findByIdForUpdate(comment.getId())).thenReturn(Optional.of(comment));

        interactionCommandService.deleteComment(currentUser, comment.getId());

        assertThat(comment.getStatus()).isEqualTo(CommentStatus.DELETED);
        verify(commentRepository).findByIdForUpdate(comment.getId());
        verify(contentInteractionService).incrementCommentCount(testContent.id(), -1);
    }

    @Test
    void resolvesAuthorAvatarWhenCreatingComment() {
        testUser = new IdentityUser(
                testUser.id(), testUser.email(), testUser.nickname(), "/minio/blog-media/avatars/me.png",
                null, null, "hash", Role.USER, true
        );
        Comment savedComment = new Comment(testContent.id(), testUser.id(), "新评论");
        when(contentInteractionService.findPublished(testContent.id())).thenReturn(Optional.of(testContent));
        when(userAccountService.findActiveById(testUser.id())).thenReturn(Optional.of(testUser));
        when(commentRepository.save(any(Comment.class))).thenReturn(savedComment);
        when(referenceData.avatarUrl(testUser))
                .thenReturn("http://localhost:9000/blog-media/avatars/me.png?X-Amz-Signature=abc");

        CommentResponse response = interactionCommandService.comment(
                currentUser,
                testContent.id(),
                new CommentRequest("新评论")
        );

        assertThat(response.author().avatarUrl())
                .isEqualTo("http://localhost:9000/blog-media/avatars/me.png?X-Amz-Signature=abc");
        verify(referenceData).avatarUrl(testUser);
    }

    @Test
    void rejectsCommentThatIsEmptyAfterHtmlSanitization() {
        when(contentInteractionService.findPublished(testContent.id())).thenReturn(Optional.of(testContent));
        when(userAccountService.findActiveById(testUser.id())).thenReturn(Optional.of(testUser));

        assertThatThrownBy(() -> interactionCommandService.comment(
                currentUser,
                testContent.id(),
                new CommentRequest("<b></b>")
        ))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("评论内容不能为空");

        verify(commentRepository, never()).save(any(Comment.class));
        verify(contentInteractionService, never()).incrementCommentCount(any(UUID.class), anyLong());
    }
}
