package com.caoqiang.blog.interaction;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.interaction.application.service.CommentAuditResultService;
import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.interaction.domain.repository.CommentRepository;
import com.caoqiang.blog.user.domain.model.User;
import java.time.Instant;
import java.util.Optional;
import java.util.Set;
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
    private ContentRepository contentRepository;

    private CommentAuditResultService service;
    private Content content;
    private Comment comment;

    @BeforeEach
    void setUp() {
        service = new CommentAuditResultService(commentRepository, contentRepository);
        content = new Content(
                "评论审核测试",
                "comment-audit-test",
                ContentType.ARTICLE,
                ContentStatus.PUBLISHED,
                "摘要",
                "正文",
                false,
                Instant.parse("2026-06-01T00:00:00Z"),
                Set.of()
        );
        comment = new Comment(
                content,
                User.register("reader@example.com", "hash", "读者"),
                "测试评论"
        );
        when(commentRepository.findByIdForUpdate(comment.getId())).thenReturn(Optional.of(comment));
    }

    @Test
    void blockingVisibleCommentDecrementsContentCount() {
        service.apply(comment.getId(), CommentStatus.BLOCKED, "不适合展示");

        assertThat(comment.getStatus()).isEqualTo(CommentStatus.BLOCKED);
        verify(contentRepository).incrementCommentCount(content.getId(), -1);
    }

    @Test
    void auditDoesNotRestoreDeletedComment() {
        comment.markDeleted();

        service.apply(comment.getId(), CommentStatus.VISIBLE, "正常");

        assertThat(comment.getStatus()).isEqualTo(CommentStatus.DELETED);
        verifyNoInteractions(contentRepository);
    }

    @Test
    void auditDoesNotOverrideManualBlock() {
        comment.setStatus(CommentStatus.BLOCKED);

        service.apply(comment.getId(), CommentStatus.VISIBLE, "正常");

        assertThat(comment.getStatus()).isEqualTo(CommentStatus.BLOCKED);
        verify(contentRepository, never()).incrementCommentCount(content.getId(), 1);
        verifyNoInteractions(contentRepository);
    }
}
