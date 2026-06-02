package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.user.User;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class AiChatAdminServiceTest {

    @Mock
    private AiChatSessionRepository sessionRepository;

    @Mock
    private AiChatMessageRepository messageRepository;

    @Test
    void detailReturnsSessionAndMessages() {
        User user = User.register("reader@example.com", "hash", "读者");
        AiChatSession session = new AiChatSession(user, "关于我");
        AiChatMessage userMessage = new AiChatMessage(session, AiMessageRole.USER, "你是谁？");
        AiChatMessage assistantMessage = new AiChatMessage(session, AiMessageRole.ASSISTANT, "我是博客助手。");
        AiChatAdminService service = new AiChatAdminService(sessionRepository, messageRepository);

        when(sessionRepository.findById(session.getId())).thenReturn(Optional.of(session));
        when(messageRepository.findBySessionIdOrderByCreatedAtAsc(session.getId()))
                .thenReturn(List.of(userMessage, assistantMessage));
        when(messageRepository.findFirstBySessionIdOrderByCreatedAtDesc(session.getId()))
                .thenReturn(Optional.of(assistantMessage));
        when(messageRepository.countBySessionId(session.getId())).thenReturn(2L);

        AdminAiChatDetailResponse response = service.detail(session.getId());

        assertThat(response.session().userEmail()).isEqualTo("reader@example.com");
        assertThat(response.session().messageCount()).isEqualTo(2);
        assertThat(response.session().lastMessage()).isEqualTo("我是博客助手。");
        assertThat(response.messages()).hasSize(2);
        assertThat(response.messages().getFirst().role()).isEqualTo(AiMessageRole.USER);
    }

    @Test
    void deleteRejectsMissingSession() {
        UUID id = UUID.randomUUID();
        AiChatAdminService service = new AiChatAdminService(sessionRepository, messageRepository);
        when(sessionRepository.findById(id)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(id))
                .isInstanceOfSatisfying(BusinessException.class, error -> {
                    assertThat(error.status()).isEqualTo(HttpStatus.NOT_FOUND);
                    assertThat(error.getMessage()).isEqualTo("AI 会话不存在");
                });
    }

    @Test
    void deleteRemovesExistingSession() {
        User user = User.register("reader@example.com", "hash", "读者");
        AiChatSession session = new AiChatSession(user, "关于我");
        AiChatAdminService service = new AiChatAdminService(sessionRepository, messageRepository);
        when(sessionRepository.findById(session.getId())).thenReturn(Optional.of(session));

        service.delete(session.getId());

        verify(sessionRepository).delete(session);
    }
}
