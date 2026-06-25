package com.caoqiang.blog.interaction;

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
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.user.application.service.ProfileService;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import java.time.Instant;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class InteractionCommandServiceTest {

    @Mock
    private ContentRepository contentRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private CommentRepository commentRepository;

    @Mock
    private LikeRepository likeRepository;

    @Mock
    private ViewRecordRepository viewRecordRepository;

    @Mock
    private DomainEventPublisher domainEventPublisher;

    @Mock
    private ProfileService profileService;

    private InteractionCommandService interactionCommandService;

    private Content testContent;
    private User testUser;
    private AuthenticatedUser currentUser;

    @BeforeEach
    void setUp() {
        interactionCommandService = new InteractionCommandService(
                contentRepository, userRepository, commentRepository, likeRepository,
                viewRecordRepository, domainEventPublisher, profileService
        );

        testContent = new Content(
                "测试内容",
                "test-content",
                ContentType.ARTICLE,
                ContentStatus.PUBLISHED,
                "测试摘要",
                "# 测试正文",
                false,
                Instant.now(),
                Set.of()
        );

        testUser = User.register("test@example.com", "hash", "测试用户");
        currentUser = new AuthenticatedUser(testUser.getId(), "test@example.com", "测试用户", Role.USER);
    }

    @Test
    void recordViewForAuthenticatedUser() {
        when(contentRepository.findByIdAndStatusAndDeletedAtIsNull(
                testContent.getId(),
                ContentStatus.PUBLISHED
        ))
                .thenReturn(Optional.of(testContent));
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(viewRecordRepository.insertIfAbsent(
                any(UUID.class),
                eq(testContent.getId()),
                eq(testUser.getId()),
                any(),
                any(),
                eq("Mozilla/5.0")
        )).thenReturn(1);

        ViewStateResponse response = interactionCommandService.recordView(
                currentUser, testContent.getId(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isTrue();
        verify(viewRecordRepository).insertIfAbsent(
                any(UUID.class),
                eq(testContent.getId()),
                eq(testUser.getId()),
                any(),
                any(),
                eq("Mozilla/5.0")
        );
        verify(contentRepository).incrementViewCount(testContent.getId(), 1);
    }

    @Test
    void skipDuplicateViewForAuthenticatedUser() {
        when(contentRepository.findByIdAndStatusAndDeletedAtIsNull(
                testContent.getId(),
                ContentStatus.PUBLISHED
        ))
                .thenReturn(Optional.of(testContent));
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(viewRecordRepository.insertIfAbsent(
                any(UUID.class),
                eq(testContent.getId()),
                eq(testUser.getId()),
                any(),
                any(),
                eq("Mozilla/5.0")
        )).thenReturn(0);

        ViewStateResponse response = interactionCommandService.recordView(
                currentUser, testContent.getId(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isTrue();
        verify(contentRepository, never()).incrementViewCount(any(UUID.class), anyLong());
    }

    @Test
    void recordViewForAnonymousUser() {
        when(contentRepository.findByIdAndStatusAndDeletedAtIsNull(
                testContent.getId(),
                ContentStatus.PUBLISHED
        ))
                .thenReturn(Optional.of(testContent));
        when(viewRecordRepository.insertIfAbsent(
                any(UUID.class),
                eq(testContent.getId()),
                eq(null),
                any(),
                any(),
                eq("Mozilla/5.0")
        )).thenReturn(1);

        ViewStateResponse response = interactionCommandService.recordView(
                null, testContent.getId(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isTrue();
        verify(contentRepository).incrementViewCount(testContent.getId(), 1);
    }

    @Test
    void skipDuplicateViewForAnonymousUser() {
        when(contentRepository.findByIdAndStatusAndDeletedAtIsNull(
                testContent.getId(),
                ContentStatus.PUBLISHED
        ))
                .thenReturn(Optional.of(testContent));
        when(viewRecordRepository.insertIfAbsent(
                any(UUID.class),
                eq(testContent.getId()),
                eq(null),
                any(),
                any(),
                eq("Mozilla/5.0")
        )).thenReturn(0);

        ViewStateResponse response = interactionCommandService.recordView(
                null, testContent.getId(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isTrue();
        verify(contentRepository, never()).incrementViewCount(any(UUID.class), anyLong());
    }

    @Test
    void skipViewWhenContentIsNotPublished() {
        when(contentRepository.findByIdAndStatusAndDeletedAtIsNull(
                testContent.getId(),
                ContentStatus.PUBLISHED
        ))
                .thenReturn(Optional.empty());

        ViewStateResponse response = interactionCommandService.recordView(
                null, testContent.getId(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isFalse();
        assertThat(response.viewCount()).isZero();
        verify(contentRepository, never()).incrementViewCount(any(UUID.class), anyLong());
    }

    @Test
    void incrementLikeCountOnlyWhenInsertSucceeds() {
        when(contentRepository.findByIdAndStatusAndDeletedAtIsNull(
                testContent.getId(),
                ContentStatus.PUBLISHED
        )).thenReturn(Optional.of(testContent));
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(likeRepository.insertIfAbsent(any(UUID.class), eq(testContent.getId()), eq(testUser.getId())))
                .thenReturn(1);

        LikeStateResponse response = interactionCommandService.like(currentUser, testContent.getId());

        assertThat(response.liked()).isTrue();
        verify(contentRepository).incrementLikeCount(testContent.getId(), 1);
        verify(domainEventPublisher).publishEvent(any());
    }

    @Test
    void skipLikeCountWhenConcurrentInsertAlreadyWon() {
        when(contentRepository.findByIdAndStatusAndDeletedAtIsNull(
                testContent.getId(),
                ContentStatus.PUBLISHED
        )).thenReturn(Optional.of(testContent));
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(likeRepository.insertIfAbsent(any(UUID.class), eq(testContent.getId()), eq(testUser.getId())))
                .thenReturn(0);

        LikeStateResponse response = interactionCommandService.like(currentUser, testContent.getId());

        assertThat(response.liked()).isTrue();
        verify(contentRepository, never()).incrementLikeCount(any(UUID.class), anyLong());
        verify(domainEventPublisher, never()).publishEvent(any());
    }

    @Test
    void deletingVisibleCommentUsesLockedLookupAndDecrementsCount() {
        Comment comment = new Comment(testContent, testUser, "待删除评论");
        when(commentRepository.findByIdForUpdate(comment.getId())).thenReturn(Optional.of(comment));

        interactionCommandService.deleteComment(currentUser, comment.getId());

        assertThat(comment.getStatus()).isEqualTo(CommentStatus.DELETED);
        verify(commentRepository).findByIdForUpdate(comment.getId());
        verify(contentRepository).incrementCommentCount(testContent.getId(), -1);
    }

    @Test
    void resolvesAuthorAvatarWhenCreatingComment() {
        testUser.setAvatarUrl("/minio/blog-media/avatars/me.png");
        Comment savedComment = new Comment(testContent, testUser, "新评论");
        when(contentRepository.findByIdAndStatusAndDeletedAtIsNull(
                testContent.getId(),
                ContentStatus.PUBLISHED
        )).thenReturn(Optional.of(testContent));
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(commentRepository.save(any(Comment.class))).thenReturn(savedComment);
        when(profileService.generatePresignedAvatarUrl(testUser.getAvatarUrl()))
                .thenReturn("http://localhost:9000/blog-media/avatars/me.png?X-Amz-Signature=abc");

        CommentResponse response = interactionCommandService.comment(
                currentUser,
                testContent.getId(),
                new CommentRequest("新评论")
        );

        assertThat(response.author().avatarUrl())
                .isEqualTo("http://localhost:9000/blog-media/avatars/me.png?X-Amz-Signature=abc");
        verify(profileService).generatePresignedAvatarUrl(testUser.getAvatarUrl());
    }

    @Test
    void rejectsCommentThatIsEmptyAfterHtmlSanitization() {
        when(contentRepository.findByIdAndStatusAndDeletedAtIsNull(
                testContent.getId(),
                ContentStatus.PUBLISHED
        )).thenReturn(Optional.of(testContent));
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));

        assertThatThrownBy(() -> interactionCommandService.comment(
                currentUser,
                testContent.getId(),
                new CommentRequest("<b></b>")
        ))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("评论内容不能为空");

        verify(commentRepository, never()).save(any(Comment.class));
        verify(contentRepository, never()).incrementCommentCount(any(UUID.class), anyLong());
    }
}
