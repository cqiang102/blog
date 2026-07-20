package com.caoqiang.blog.interaction;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.RETURNS_DEEP_STUBS;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.interaction.application.service.CommentAuditResultService;
import com.caoqiang.blog.interaction.application.service.CommentAuditService;
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
import org.springframework.ai.chat.client.ChatClient;
import tools.jackson.databind.ObjectMapper;

@ExtendWith(MockitoExtension.class)
class CommentAuditServiceTest {

    @Mock
    private CommentRepository commentRepository;

    @Mock
    private CommentAuditResultService resultService;

    private ChatClient chatClient;
    private CommentAuditService service;
    private Comment comment;
    private UUID commentId;

    @BeforeEach
    void setUp() {
        chatClient = mock(ChatClient.class, RETURNS_DEEP_STUBS);
        service = new CommentAuditService(commentRepository, resultService, chatClient, new ObjectMapper());
        comment = mock(Comment.class);
        commentId = UUID.randomUUID();
        when(comment.getBody()).thenReturn("测试评论");
        when(commentRepository.findById(commentId)).thenReturn(Optional.of(comment));
    }

    @Test
    void delegatesParsedBlockResultToTransactionalWriter() {
        when(chatClient.prompt().user(anyString()).call().content())
                .thenReturn("{\"status\":\"BLOCK\",\"reason\":\"不适合展示\"}");

        service.audit(commentId);

        verify(resultService).apply(commentId, CommentStatus.BLOCKED, "不适合展示");
    }
}
