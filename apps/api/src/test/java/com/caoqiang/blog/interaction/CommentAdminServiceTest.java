package com.caoqiang.blog.interaction;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.content.application.api.ContentInteractionService;
import com.caoqiang.blog.content.application.api.ContentInteractionSnapshot;
import com.caoqiang.blog.interaction.application.dto.AdminCommentResponse;
import com.caoqiang.blog.interaction.application.service.CommentAdminService;
import com.caoqiang.blog.interaction.application.service.InteractionReferenceData;
import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.interaction.domain.repository.CommentRepository;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class CommentAdminServiceTest {

    @Mock
    private CommentRepository commentRepository;

    @Mock
    private ContentInteractionService contentInteractionService;

    @Mock
    private UserAccountService userAccountService;

    @Test
    void deletingVisibleCommentDecrementsContentCommentCount() {
        Comment comment = visibleComment();
        CommentAdminService service = service(comment);
        when(commentRepository.findByIdForUpdate(comment.getId())).thenReturn(Optional.of(comment));

        AdminCommentResponse response = service.setStatus(comment.getId(), CommentStatus.DELETED);

        assertThat(response.status()).isEqualTo(CommentStatus.DELETED);
        assertThat(comment.getStatus()).isEqualTo(CommentStatus.DELETED);
        verify(contentInteractionService).incrementCommentCount(comment.getContentId(), -1);
    }

    @Test
    void restoringDeletedCommentIncrementsContentCommentCount() {
        Comment comment = visibleComment();
        comment.markDeleted();
        CommentAdminService service = service(comment);
        when(commentRepository.findByIdForUpdate(comment.getId())).thenReturn(Optional.of(comment));

        AdminCommentResponse response = service.setStatus(comment.getId(), CommentStatus.VISIBLE);

        assertThat(response.status()).isEqualTo(CommentStatus.VISIBLE);
        assertThat(comment.getStatus()).isEqualTo(CommentStatus.VISIBLE);
        verify(contentInteractionService).incrementCommentCount(comment.getContentId(), 1);
    }

    @Test
    void settingSameStatusDoesNotChangeContentCommentCount() {
        Comment comment = visibleComment();
        CommentAdminService service = service(comment);
        when(commentRepository.findByIdForUpdate(comment.getId())).thenReturn(Optional.of(comment));

        AdminCommentResponse response = service.setStatus(comment.getId(), CommentStatus.VISIBLE);

        assertThat(response.status()).isEqualTo(CommentStatus.VISIBLE);
        verify(contentInteractionService, never()).incrementCommentCount(comment.getContentId(), 1);
        verify(contentInteractionService, never()).incrementCommentCount(comment.getContentId(), -1);
    }

    private Comment visibleComment() {
        return new Comment(UUID.randomUUID(), UUID.randomUUID(), "写得不错");
    }

    private CommentAdminService service(Comment comment) {
        when(contentInteractionService.findByIds(org.mockito.ArgumentMatchers.anyCollection()))
                .thenReturn(List.of(new ContentInteractionSnapshot(comment.getContentId(), "评论测试内容", 0, 0, 1)));
        when(userAccountService.findByIds(org.mockito.ArgumentMatchers.anyCollection()))
                .thenReturn(List.of(new IdentityUser(
                        comment.getUserId(), "reader@example.com", "读者", null, null, null, "hash", Role.USER, true)));
        return new CommentAdminService(
                commentRepository,
                contentInteractionService,
                new InteractionReferenceData(contentInteractionService, userAccountService));
    }
}
