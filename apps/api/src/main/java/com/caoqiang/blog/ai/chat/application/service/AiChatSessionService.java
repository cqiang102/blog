package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.ai.chat.application.dto.AiChatHistoryMessage;
import com.caoqiang.blog.ai.chat.application.dto.AiChatMessageResponse;
import com.caoqiang.blog.ai.chat.application.dto.AiChatSessionResponse;
import com.caoqiang.blog.ai.chat.application.dto.AiCreateSessionRequest;
import com.caoqiang.blog.ai.chat.domain.model.AiChatMessage;
import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatMessageRepository;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatSessionRepository;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.shared.util.PageUtils;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 管理用户自己的 AI 会话及消息历史。
 *
 * <p>本服务集中负责会话归属校验、创建上限、消息分页、会话解析和响应映射；
 * AI 回答生成由同步和流式聊天服务编排，本服务不依赖模型或传输层。</p>
 */
@Service
public class AiChatSessionService {

    private static final int MAX_SESSIONS_PER_USER = 20;
    private static final int MAX_SESSION_TITLE_LENGTH = 40;
    private static final int MAX_MESSAGE_PAGE_SIZE = 50;
    private static final String DEFAULT_SESSION_TITLE = "新会话";

    private final UserAccountService userAccountService;
    private final AiChatSessionRepository sessionRepository;
    private final AiChatMessageRepository messageRepository;

    public AiChatSessionService(
            UserAccountService userAccountService,
            AiChatSessionRepository sessionRepository,
            AiChatMessageRepository messageRepository) {
        this.userAccountService = userAccountService;
        this.sessionRepository = sessionRepository;
        this.messageRepository = messageRepository;
    }

    /**
     * 根据认证主体解析有效账号。
     *
     * @param currentUser 已认证主体
     * @return 有效用户快照
     * @throws BusinessException 账号不存在或已停用时抛出
     */
    @Transactional(readOnly = true)
    public IdentityUser requireActiveUser(AuthenticatedUser currentUser) {
        return userAccountService
                .findActiveById(currentUser.id())
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
    }

    /**
     * 为聊天操作解析会话并读取当前消息数。
     * 未传会话 ID 时复用最近更新的会话；没有可用会话时创建默认会话。
     */
    @Transactional
    public ResolvedSession resolveForChat(IdentityUser user, UUID sessionId) {
        AiChatSession session = resolveSession(user, sessionId);
        long messageCount = messageRepository.countBySessionIdAndDeletedFalse(session.getId());
        List<AiChatHistoryMessage> history = new ArrayList<>(
                messageRepository.findTop20BySessionIdAndDeletedFalseOrderByCreatedAtDesc(session.getId()).stream()
                        .filter(message -> message.getRole()
                                        == com.caoqiang.blog.ai.chat.domain.model.AiMessageRole.USER
                                || message.getRole() == com.caoqiang.blog.ai.chat.domain.model.AiMessageRole.ASSISTANT)
                        .map(message -> new AiChatHistoryMessage(message.getRole(), message.getContent()))
                        .toList());
        Collections.reverse(history);
        return new ResolvedSession(session, messageCount, List.copyOf(history));
    }

    /** 创建新的用户 AI 会话。 */
    @Transactional
    public AiChatSessionResponse createSession(AuthenticatedUser currentUser, AiCreateSessionRequest request) {
        IdentityUser user = requireActiveUser(currentUser);

        long sessionCount = sessionRepository.countByUserIdAndDeletedFalse(user.id());
        if (sessionCount >= MAX_SESSIONS_PER_USER) {
            throw new BusinessException(HttpStatus.CONFLICT, "会话数量已达上限（" + MAX_SESSIONS_PER_USER + "个），请先删除旧会话再创建");
        }

        String title = request.title() != null ? request.title().trim() : DEFAULT_SESSION_TITLE;
        if (title.length() > MAX_SESSION_TITLE_LENGTH) {
            title = title.substring(0, MAX_SESSION_TITLE_LENGTH);
        }
        AiChatSession session = sessionRepository.save(new AiChatSession(user.id(), title));
        return toSessionResponse(session, 0);
    }

    /** 返回当前用户最近更新的 20 个 AI 会话。 */
    @Transactional(readOnly = true)
    public List<AiChatSessionResponse> listSessions(AuthenticatedUser currentUser) {
        IdentityUser user = requireActiveUser(currentUser);
        return sessionRepository.findTop20WithMessageCount(user.id()).stream()
                .map(this::toSessionResponse)
                .toList();
    }

    /** 逻辑删除当前用户拥有的 AI 会话。 */
    @Transactional
    public void deleteSession(AuthenticatedUser currentUser, UUID sessionId) {
        IdentityUser user = requireActiveUser(currentUser);
        AiChatSession session = ownedSession(sessionId, user.id());
        session.markDeleted();
        sessionRepository.save(session);
    }

    /** 分页返回当前用户指定会话的消息。 */
    @Transactional(readOnly = true)
    public PageResponse<AiChatMessageResponse> sessionMessages(
            AuthenticatedUser currentUser, UUID sessionId, int page, int size) {
        IdentityUser user = requireActiveUser(currentUser);
        AiChatSession session = ownedSession(sessionId, user.id());

        PageRequest pageRequest = PageUtils.of(
                page,
                size,
                MAX_MESSAGE_PAGE_SIZE,
                Sort.by(Sort.Direction.ASC, "createdAt").and(Sort.by(Sort.Direction.ASC, "id")));
        Page<AiChatMessage> messagePage =
                messageRepository.findBySessionIdAndDeletedFalseOrderByCreatedAtAsc(session.getId(), pageRequest);
        List<AiChatMessageResponse> items =
                messagePage.getContent().stream().map(this::toMessageResponse).toList();
        return new PageResponse<>(
                items, messagePage.getNumber(), messagePage.getSize(), messagePage.getTotalElements());
    }

    private AiChatSession resolveSession(IdentityUser user, UUID sessionId) {
        if (sessionId != null) {
            return ownedSession(sessionId, user.id());
        }
        return sessionRepository
                .findFirstByUserIdAndDeletedFalseOrderByUpdatedAtDesc(user.id())
                .orElseGet(() -> sessionRepository.save(new AiChatSession(user.id(), DEFAULT_SESSION_TITLE)));
    }

    private AiChatSession ownedSession(UUID sessionId, UUID userId) {
        return sessionRepository
                .findByIdAndUserIdAndDeletedFalse(sessionId, userId)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));
    }

    private AiChatSessionResponse toSessionResponse(Object[] row) {
        return toSessionResponse((AiChatSession) row[0], ((Number) row[1]).intValue());
    }

    private AiChatSessionResponse toSessionResponse(AiChatSession session, int messageCount) {
        return new AiChatSessionResponse(
                session.getId(), session.getTitle(), messageCount, session.getCreatedAt(), session.getUpdatedAt());
    }

    private AiChatMessageResponse toMessageResponse(AiChatMessage message) {
        return new AiChatMessageResponse(
                message.getId(),
                message.getRole().name(),
                message.getContent(),
                message.getAuditStatus(),
                message.getCreatedAt());
    }

    /** 聊天编排使用的会话、消息数及最近历史快照。 */
    public record ResolvedSession(AiChatSession session, long messageCount, List<AiChatHistoryMessage> history) {}
}
