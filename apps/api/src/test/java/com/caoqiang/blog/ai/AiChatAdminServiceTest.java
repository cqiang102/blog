package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.ai.chat.application.dto.AdminAiChatDetailResponse;
import com.caoqiang.blog.ai.chat.application.service.AiChatAdminService;
import com.caoqiang.blog.ai.chat.domain.model.AiChatMessage;
import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.ai.chat.domain.model.AiMessageRole;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatMessageRepository;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatSessionRepository;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentMatchers;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class AiChatAdminServiceTest {

    @Mock
    private AiChatSessionRepository sessionRepository;

    @Mock
    private AiChatMessageRepository messageRepository;

    @Mock
    private UserAccountService userAccountService;

    @Test
    void detailReturnsSessionAndMessages() {
        IdentityUser user = user();
        AiChatSession session = new AiChatSession(user.id(), "关于我");
        AiChatMessage userMessage = new AiChatMessage(session, AiMessageRole.USER, "你是谁？");
        AiChatMessage assistantMessage = new AiChatMessage(session, AiMessageRole.ASSISTANT, "我是博客助手。");
        AiChatAdminService service = service();

        when(sessionRepository.findById(session.getId())).thenReturn(Optional.of(session));
        when(messageRepository.findBySessionIdOrderByCreatedAtAsc(session.getId()))
                .thenReturn(List.of(userMessage, assistantMessage));
        when(messageRepository.findFirstBySessionIdOrderByCreatedAtDesc(session.getId()))
                .thenReturn(Optional.of(assistantMessage));
        when(messageRepository.countBySessionId(session.getId())).thenReturn(2L);
        when(userAccountService.findById(user.id())).thenReturn(Optional.of(user));

        AdminAiChatDetailResponse response = service.detail(session.getId());

        assertThat(response.session().userEmail()).isEqualTo("reader@example.com");
        assertThat(response.session().messageCount()).isEqualTo(2);
        assertThat(response.session().lastMessage()).isEqualTo("我是博客助手。");
        assertThat(response.messages()).hasSize(2);
        assertThat(response.messages().getFirst().role()).isEqualTo(AiMessageRole.USER);
    }

    @Test
    void sessionsResolveIdentityKeywordsAndBatchUserSnapshots() {
        IdentityUser user = user();
        AiChatSession session = new AiChatSession(user.id(), "身份查询");
        AiChatAdminService service = service();
        when(userAccountService.findIdsMatchingIdentity("reader")).thenReturn(List.of(user.id()));
        when(sessionRepository.findAll(ArgumentMatchers.<Specification<AiChatSession>>any(), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(session)));
        when(userAccountService.findByIds(List.of(user.id()))).thenReturn(List.of(user));
        when(messageRepository.findFirstBySessionIdOrderByCreatedAtDesc(session.getId()))
                .thenReturn(Optional.empty());
        when(messageRepository.countBySessionId(session.getId())).thenReturn(0L);

        var response = service.sessions(0, 20, null, " Reader ");

        assertThat(response.items()).singleElement().satisfies(item -> {
            assertThat(item.userId()).isEqualTo(user.id());
            assertThat(item.userEmail()).isEqualTo(user.email());
        });
        verify(userAccountService).findIdsMatchingIdentity("reader");
        verify(userAccountService).findByIds(List.of(user.id()));
    }

    @Test
    void deleteRejectsMissingSession() {
        UUID id = UUID.randomUUID();
        AiChatAdminService service = service();
        when(sessionRepository.findById(id)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.delete(id)).isInstanceOfSatisfying(BusinessException.class, error -> {
            assertThat(error.status()).isEqualTo(HttpStatus.NOT_FOUND);
            assertThat(error.getMessage()).isEqualTo("AI 会话不存在");
        });
    }

    @Test
    void deleteRemovesExistingSession() {
        IdentityUser user = user();
        AiChatSession session = new AiChatSession(user.id(), "关于我");
        AiChatAdminService service = service();
        when(sessionRepository.findById(session.getId())).thenReturn(Optional.of(session));

        service.delete(session.getId());

        assertThat(session.isDeleted()).isTrue();
        verify(sessionRepository).save(session);
    }

    private AiChatAdminService service() {
        return new AiChatAdminService(sessionRepository, messageRepository, userAccountService);
    }

    private IdentityUser user() {
        return new IdentityUser(
                UUID.randomUUID(), "reader@example.com", "读者", null, null, null, "hash", Role.USER, true);
    }
}
