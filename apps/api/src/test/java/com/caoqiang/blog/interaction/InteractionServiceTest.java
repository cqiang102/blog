package com.caoqiang.blog.interaction;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.content.entity.Content;
import com.caoqiang.blog.content.repository.ContentRepository;
import com.caoqiang.blog.content.entity.ContentStatus;
import com.caoqiang.blog.content.entity.ContentType;
import com.caoqiang.blog.user.User;
import com.caoqiang.blog.user.UserRepository;
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
class InteractionServiceTest {

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
    private CommentAuditService commentAuditService;

    private InteractionService interactionService;

    private Content testContent;
    private User testUser;
    private AuthenticatedUser currentUser;

    @BeforeEach
    void setUp() {
        interactionService = new InteractionService(
                contentRepository, userRepository, commentRepository, likeRepository, viewRecordRepository, commentAuditService
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
        when(contentRepository.findByIdAndStatus(testContent.getId(), ContentStatus.PUBLISHED))
                .thenReturn(Optional.of(testContent));
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(viewRecordRepository.existsByContentIdAndUserId(testContent.getId(), testUser.getId()))
                .thenReturn(false);

        ViewStateResponse response = interactionService.recordView(
                currentUser, testContent.getId(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isTrue();
        verify(viewRecordRepository).save(any(ViewRecord.class));
        verify(contentRepository).incrementViewCount(testContent.getId(), 1);
    }

    @Test
    void skipDuplicateViewForAuthenticatedUser() {
        when(contentRepository.findByIdAndStatus(testContent.getId(), ContentStatus.PUBLISHED))
                .thenReturn(Optional.of(testContent));
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(viewRecordRepository.existsByContentIdAndUserId(testContent.getId(), testUser.getId()))
                .thenReturn(true);

        ViewStateResponse response = interactionService.recordView(
                currentUser, testContent.getId(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isTrue();
        verify(viewRecordRepository, never()).save(any(ViewRecord.class));
        verify(contentRepository, never()).incrementViewCount(any(UUID.class), anyLong());
    }

    @Test
    void recordViewForAnonymousUser() {
        when(contentRepository.findByIdAndStatus(testContent.getId(), ContentStatus.PUBLISHED))
                .thenReturn(Optional.of(testContent));
        when(viewRecordRepository.existsByContentIdAndAnonymousId(eq(testContent.getId()), any()))
                .thenReturn(false);

        ViewStateResponse response = interactionService.recordView(
                null, testContent.getId(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isTrue();
        verify(viewRecordRepository).save(any(ViewRecord.class));
    }

    @Test
    void skipDuplicateViewForAnonymousUser() {
        when(contentRepository.findByIdAndStatus(testContent.getId(), ContentStatus.PUBLISHED))
                .thenReturn(Optional.of(testContent));
        when(viewRecordRepository.existsByContentIdAndAnonymousId(eq(testContent.getId()), any()))
                .thenReturn(true);

        ViewStateResponse response = interactionService.recordView(
                null, testContent.getId(), "192.168.1.1", "Mozilla/5.0"
        );

        assertThat(response.recorded()).isTrue();
        verify(viewRecordRepository, never()).save(any(ViewRecord.class));
    }
}
