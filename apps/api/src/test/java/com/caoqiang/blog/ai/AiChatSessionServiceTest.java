package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.ai.chat.application.dto.AiChatHistoryMessage;
import com.caoqiang.blog.ai.chat.application.dto.AiChatSessionResponse;
import com.caoqiang.blog.ai.chat.application.dto.AiCreateSessionRequest;
import com.caoqiang.blog.ai.chat.application.service.AiChatSessionService;
import com.caoqiang.blog.ai.chat.domain.model.AiChatMessage;
import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.ai.chat.domain.model.AiMessageRole;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatMessageRepository;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatSessionRepository;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class AiChatSessionServiceTest {

    @Mock
    private UserAccountService userAccountService;

    @Mock
    private AiChatSessionRepository sessionRepository;

    @Mock
    private AiChatMessageRepository messageRepository;

    private AiChatSessionService service;
    private UUID userId;
    private AuthenticatedUser principal;
    private IdentityUser identity;

    @BeforeEach
    void setUp() {
        service = new AiChatSessionService(userAccountService, sessionRepository, messageRepository);
        userId = UUID.randomUUID();
        principal = new AuthenticatedUser(userId, "reader@example.com", "读者", Role.USER);
        identity = new IdentityUser(
                userId, principal.email(), principal.nickname(), null, null, null, "password-hash", Role.USER, true);
    }

    @Test
    void rejectsAPrincipalWhoseAccountIsNoLongerActive() {
        when(userAccountService.findActiveById(userId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.requireActiveUser(principal))
                .isInstanceOfSatisfying(BusinessException.class, error -> {
                    assertThat(error.status()).isEqualTo(HttpStatus.UNAUTHORIZED);
                    assertThat(error.getMessage()).isEqualTo("登录状态无效");
                });
    }

    @Test
    void resolvesAnExplicitOwnedSessionWithItsVisibleMessageCount() {
        AiChatSession session = new AiChatSession(userId, "指定会话");
        AiChatMessage olderQuestion = new AiChatMessage(session, AiMessageRole.USER, "先前问题");
        AiChatMessage newerAnswer = new AiChatMessage(session, AiMessageRole.ASSISTANT, "先前回答");
        when(sessionRepository.findByIdAndUserIdAndDeletedFalse(session.getId(), userId))
                .thenReturn(Optional.of(session));
        when(messageRepository.countBySessionIdAndDeletedFalse(session.getId())).thenReturn(7L);
        when(messageRepository.findTop20BySessionIdAndDeletedFalseOrderByCreatedAtDesc(session.getId()))
                .thenReturn(List.of(newerAnswer, olderQuestion));

        AiChatSessionService.ResolvedSession result = service.resolveForChat(identity, session.getId());

        assertThat(result.session()).isSameAs(session);
        assertThat(result.messageCount()).isEqualTo(7);
        assertThat(result.history())
                .containsExactly(
                        new AiChatHistoryMessage(AiMessageRole.USER, "先前问题"),
                        new AiChatHistoryMessage(AiMessageRole.ASSISTANT, "先前回答"));
        verify(sessionRepository, never()).save(any());
    }

    @Test
    void reusesTheMostRecentlyUpdatedSessionWhenNoIdIsProvided() {
        AiChatSession recentSession = new AiChatSession(userId, "最近会话");
        when(sessionRepository.findFirstByUserIdAndDeletedFalseOrderByUpdatedAtDesc(userId))
                .thenReturn(Optional.of(recentSession));
        when(messageRepository.countBySessionIdAndDeletedFalse(recentSession.getId()))
                .thenReturn(4L);

        AiChatSessionService.ResolvedSession result = service.resolveForChat(identity, null);

        assertThat(result.session()).isSameAs(recentSession);
        assertThat(result.messageCount()).isEqualTo(4);
        verify(sessionRepository, never()).save(any());
    }

    @Test
    void createsADefaultSessionWhenTheUserHasNoSession() {
        when(sessionRepository.findFirstByUserIdAndDeletedFalseOrderByUpdatedAtDesc(userId))
                .thenReturn(Optional.empty());
        when(sessionRepository.save(any(AiChatSession.class))).thenAnswer(invocation -> invocation.getArgument(0));

        AiChatSessionService.ResolvedSession result = service.resolveForChat(identity, null);

        assertThat(result.session().getUserId()).isEqualTo(userId);
        assertThat(result.session().getTitle()).isEqualTo("新会话");
        assertThat(result.messageCount()).isZero();
        verify(messageRepository)
                .countBySessionIdAndDeletedFalse(result.session().getId());
    }

    @Test
    void enforcesThePerUserSessionLimitBeforeSaving() {
        stubActiveUser();
        when(sessionRepository.countByUserIdAndDeletedFalse(userId)).thenReturn(20L);

        assertThatThrownBy(() -> service.createSession(principal, new AiCreateSessionRequest("再建一个")))
                .isInstanceOfSatisfying(BusinessException.class, error -> {
                    assertThat(error.status()).isEqualTo(HttpStatus.CONFLICT);
                    assertThat(error.getMessage()).contains("20个");
                });

        verify(sessionRepository, never()).save(any());
    }

    @Test
    void trimsAndCapsTheSessionTitleAndMapsTheCreatedSession() {
        stubActiveUser();
        when(sessionRepository.countByUserIdAndDeletedFalse(userId)).thenReturn(2L);
        when(sessionRepository.save(any(AiChatSession.class))).thenAnswer(invocation -> invocation.getArgument(0));

        AiChatSessionResponse response =
                service.createSession(principal, new AiCreateSessionRequest("  " + "会".repeat(45) + "  "));

        assertThat(response.id()).isNotNull();
        assertThat(response.title()).hasSize(40).isEqualTo("会".repeat(40));
        assertThat(response.messageCount()).isZero();
    }

    @Test
    void mapsSessionRowsAndMessageCountsWithoutAdditionalQueries() {
        stubActiveUser();
        AiChatSession first = new AiChatSession(userId, "第一段");
        AiChatSession second = new AiChatSession(userId, "第二段");
        when(sessionRepository.findTop20WithMessageCount(userId))
                .thenReturn(List.of(new Object[] {first, 6L}, new Object[] {second, 1L}));

        List<AiChatSessionResponse> result = service.listSessions(principal);

        assertThat(result)
                .extracting(AiChatSessionResponse::title, AiChatSessionResponse::messageCount)
                .containsExactly(
                        org.assertj.core.groups.Tuple.tuple("第一段", 6), org.assertj.core.groups.Tuple.tuple("第二段", 1));
        verifyNoInteractions(messageRepository);
    }

    @Test
    void deletesOnlyAnOwnedSession() {
        stubActiveUser();
        AiChatSession session = new AiChatSession(userId, "待删除");
        when(sessionRepository.findByIdAndUserIdAndDeletedFalse(session.getId(), userId))
                .thenReturn(Optional.of(session));

        service.deleteSession(principal, session.getId());

        assertThat(session.isDeleted()).isTrue();
        verify(sessionRepository).save(session);
    }

    @Test
    void refusesToDeleteASessionOwnedByAnotherUser() {
        stubActiveUser();
        UUID sessionId = UUID.randomUUID();
        when(sessionRepository.findByIdAndUserIdAndDeletedFalse(sessionId, userId))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.deleteSession(principal, sessionId))
                .isInstanceOfSatisfying(BusinessException.class, error -> {
                    assertThat(error.status()).isEqualTo(HttpStatus.NOT_FOUND);
                    assertThat(error.getMessage()).isEqualTo("AI 会话不存在");
                });

        verify(sessionRepository, never()).save(any());
    }

    @Test
    void clampsPaginationAddsAStableSortAndMapsMessageFields() {
        stubActiveUser();
        AiChatSession session = new AiChatSession(userId, "消息分页");
        when(sessionRepository.findByIdAndUserIdAndDeletedFalse(session.getId(), userId))
                .thenReturn(Optional.of(session));

        AiChatMessage userMessage = new AiChatMessage(session, AiMessageRole.USER, "问题");
        userMessage.markVisible();
        AiChatMessage answer = new AiChatMessage(session, AiMessageRole.ASSISTANT, "回答");
        answer.markBlocked("测试原因");
        when(messageRepository.findBySessionIdAndDeletedFalseOrderByCreatedAtAsc(
                        org.mockito.ArgumentMatchers.eq(session.getId()), any(Pageable.class)))
                .thenReturn(new PageImpl<>(List.of(userMessage, answer), PageRequest.of(0, 50), 72));

        var result = service.sessionMessages(principal, session.getId(), -3, 500);

        assertThat(result.page()).isZero();
        assertThat(result.size()).isEqualTo(50);
        assertThat(result.total()).isEqualTo(72);
        assertThat(result.items())
                .extracting(item -> item.role(), item -> item.content(), item -> item.auditStatus())
                .containsExactly(
                        org.assertj.core.groups.Tuple.tuple("USER", "问题", "VISIBLE"),
                        org.assertj.core.groups.Tuple.tuple("ASSISTANT", "回答", "BLOCKED"));

        ArgumentCaptor<Pageable> pageableCaptor = ArgumentCaptor.forClass(Pageable.class);
        verify(messageRepository)
                .findBySessionIdAndDeletedFalseOrderByCreatedAtAsc(
                        org.mockito.ArgumentMatchers.eq(session.getId()), pageableCaptor.capture());
        Pageable pageable = pageableCaptor.getValue();
        assertThat(pageable.getPageNumber()).isZero();
        assertThat(pageable.getPageSize()).isEqualTo(50);
        assertThat(pageable.getSort().getOrderFor("createdAt").getDirection()).isEqualTo(Sort.Direction.ASC);
        assertThat(pageable.getSort().getOrderFor("id").getDirection()).isEqualTo(Sort.Direction.ASC);
    }

    private void stubActiveUser() {
        when(userAccountService.findActiveById(userId)).thenReturn(Optional.of(identity));
    }
}
