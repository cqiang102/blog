package com.caoqiang.blog.interaction;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.content.application.api.ContentInteractionService;
import com.caoqiang.blog.interaction.application.service.CommentAuditResultService;
import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.interaction.domain.repository.CommentRepository;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class CommentAuditResultServiceTest {

    @Mock
    private CommentRepository commentRepository;

    @Mock
    private ContentInteractionService contentInteractionService;

    private CommentAuditResultService service;
    private UUID contentId;
    private Comment comment;

    @BeforeEach
    void setUp() {
        service = new CommentAuditResultService(commentRepository, contentInteractionService);
        contentId = UUID.randomUUID();
        comment = new Comment(contentId, UUID.randomUUID(), "测试评论");
        when(commentRepository.findByIdForUpdate(comment.getId())).thenReturn(Optional.of(comment));
    }

    @Test
    void blockingVisibleCommentDecrementsContentCount() {
        service.apply(comment.getId(), CommentStatus.BLOCKED, "不适合展示");

        assertThat(comment.getStatus()).isEqualTo(CommentStatus.BLOCKED);
        verify(contentInteractionService).incrementCommentCount(contentId, -1);
    }

    @Test
    void auditDoesNotRestoreDeletedComment() {
        comment.markDeleted();

        service.apply(comment.getId(), CommentStatus.VISIBLE, "正常");

        assertThat(comment.getStatus()).isEqualTo(CommentStatus.DELETED);
        verifyNoInteractions(contentInteractionService);
    }

    @Test
    void auditDoesNotOverrideManualBlock() {
        comment.setStatus(CommentStatus.BLOCKED);

        service.apply(comment.getId(), CommentStatus.VISIBLE, "正常");

        assertThat(comment.getStatus()).isEqualTo(CommentStatus.BLOCKED);
        verify(contentInteractionService, never()).incrementCommentCount(contentId, 1);
        verifyNoInteractions(contentInteractionService);
    }
}
