package com.caoqiang.blog.interaction;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.content.entity.Content;
import com.caoqiang.blog.content.repository.ContentRepository;
import com.caoqiang.blog.content.entity.ContentStatus;
import com.caoqiang.blog.content.entity.ContentType;
import com.caoqiang.blog.user.User;
import java.time.Instant;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class CommentAdminServiceTest {

    @Mock
    private CommentRepository commentRepository;

    @Mock
    private ContentRepository contentRepository;

    @Test
    void deletingVisibleCommentDecrementsContentCommentCount() {
        Comment comment = visibleComment();
        CommentAdminService service = new CommentAdminService(commentRepository, contentRepository);
        when(commentRepository.findById(comment.getId())).thenReturn(Optional.of(comment));

        AdminCommentResponse response = service.setStatus(comment.getId(), CommentStatus.DELETED);

        assertThat(response.status()).isEqualTo(CommentStatus.DELETED);
        assertThat(comment.getStatus()).isEqualTo(CommentStatus.DELETED);
        verify(contentRepository).incrementCommentCount(comment.getContent().getId(), -1);
    }

    @Test
    void restoringDeletedCommentIncrementsContentCommentCount() {
        Comment comment = visibleComment();
        comment.markDeleted();
        CommentAdminService service = new CommentAdminService(commentRepository, contentRepository);
        when(commentRepository.findById(comment.getId())).thenReturn(Optional.of(comment));

        AdminCommentResponse response = service.setStatus(comment.getId(), CommentStatus.VISIBLE);

        assertThat(response.status()).isEqualTo(CommentStatus.VISIBLE);
        assertThat(comment.getStatus()).isEqualTo(CommentStatus.VISIBLE);
        verify(contentRepository).incrementCommentCount(comment.getContent().getId(), 1);
    }

    @Test
    void settingSameStatusDoesNotChangeContentCommentCount() {
        Comment comment = visibleComment();
        CommentAdminService service = new CommentAdminService(commentRepository, contentRepository);
        when(commentRepository.findById(comment.getId())).thenReturn(Optional.of(comment));

        AdminCommentResponse response = service.setStatus(comment.getId(), CommentStatus.VISIBLE);

        assertThat(response.status()).isEqualTo(CommentStatus.VISIBLE);
        verify(contentRepository, never()).incrementCommentCount(comment.getContent().getId(), 1);
        verify(contentRepository, never()).incrementCommentCount(comment.getContent().getId(), -1);
    }

    private Comment visibleComment() {
        Content content = new Content(
                "评论测试内容",
                "comment-test",
                ContentType.ARTICLE,
                ContentStatus.PUBLISHED,
                "摘要",
                "正文",
                false,
                Instant.parse("2026-06-01T00:00:00Z"),
                Set.of()
        );
        User user = User.register("reader@example.com", "hash", "读者");
        return new Comment(content, user, "写得不错");
    }
}
