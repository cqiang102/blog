package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.ai.chat.application.dto.AiChatMessageResponse;
import com.caoqiang.blog.ai.chat.application.dto.AiChatRequest;
import com.caoqiang.blog.ai.chat.application.dto.AiChatResponse;
import com.caoqiang.blog.ai.chat.application.dto.AiChatSessionResponse;
import com.caoqiang.blog.ai.chat.application.dto.AiCreateSessionRequest;
import com.caoqiang.blog.ai.chat.application.dto.AiQuotaResponse;
import com.caoqiang.blog.ai.chat.domain.model.AiChatMessage;
import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatMessageRepository;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatSessionRepository;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.Executor;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicReference;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import reactor.core.scheduler.Schedulers;
import reactor.core.Disposable;

/**
 * AI 聊天核心服务。
 * <p>
 * 职责：管理用户的 AI 对话会话、消息持久化、每日配额控制，以及同步/流式两种对话模式。
 * 在架构中位于 Controller 与 Spring AI ChatClient 之间，是 AI 聊天功能的业务中枢。
 * <p>
 * 关键特性：
 * <ul>
 *   <li>会话管理：自动创建或复用会话，限制单会话最大消息数（{@value #MAX_MESSAGES_PER_SESSION}）</li>
 *   <li>配额控制：通过数据库原子预留实现每日提问次数限制</li>
 *   <li>同步对话：通过 {@link #chat} 一次性返回完整回答</li>
 *   <li>流式对话：通过 {@link #streamChat} 使用 SSE 逐 token 推送回答</li>
 *   <li>工具调用上下文：通过 Spring AI ToolContext 将当前用户显式传递给工具层</li>
 * </ul>
 */
@Service
public class AiChatService {

    private static final Logger log = LoggerFactory.getLogger(AiChatService.class);

    /** 单个会话允许的最大消息数，防止上下文窗口溢出和存储膨胀 */
    private static final int MAX_MESSAGES_PER_SESSION = 40;
    /** 每用户最大会话数，防止滥用 */
    private static final int MAX_SESSIONS_PER_USER = 20;
    /** 会话标题最大字符数，超出部分截断 */
    private static final int MAX_SESSION_TITLE_LENGTH = 40;
    /** 默认会话标题 */
    private static final String DEFAULT_SESSION_TITLE = "新会话";
    /** 配额重置时区：UTC+8，与国内用户习惯一致 */
    private static final ZoneOffset QUOTA_ZONE = ZoneOffset.ofHours(8);
    /** SSE 事件名称：token 片段 */
    private static final String SSE_EVENT_TOKEN = "token";
    /** SSE 事件名称：流完成 */
    private static final String SSE_EVENT_DONE = "done";
    /** SSE 事件名称：错误 */
    private static final String SSE_EVENT_ERROR = "error";

    private final BlogProperties blogProperties;
    private final Clock clock;
    private final UserRepository userRepository;
    private final AiChatSessionRepository sessionRepository;
    private final AiChatMessageRepository messageRepository;
    private final ChatClient chatClient;
    private final AiBlogTools blogTools;
    private final Executor aiStreamExecutor;
    private final AiQuotaService quotaService;
    private final AiChatPersistenceService persistenceService;

    public AiChatService(
            BlogProperties blogProperties,
            Clock clock,
            UserRepository userRepository,
            AiChatSessionRepository sessionRepository,
            AiChatMessageRepository messageRepository,
            ChatClient chatClient,
            AiBlogTools blogTools,
            @Qualifier("aiStreamExecutor") Executor aiStreamExecutor,
            AiQuotaService quotaService,
            AiChatPersistenceService persistenceService
    ) {
        this.blogProperties = blogProperties;
        this.clock = clock;
        this.userRepository = userRepository;
        this.sessionRepository = sessionRepository;
        this.messageRepository = messageRepository;
        this.chatClient = chatClient;
        this.blogTools = blogTools;
        this.aiStreamExecutor = aiStreamExecutor;
        this.quotaService = quotaService;
        this.persistenceService = persistenceService;
    }

    /**
     * 同步对话接口。发送用户消息并一次性返回完整 AI 回答。
     * <p>
     * 处理流程：预留配额 → 解析会话 → 调用 AI 生成回答 → 保存用户消息和助手消息。
     * 任何失败都会释放已预留配额。
     *
     * @param currentUser 当前登录用户
     * @param request     聊天请求，包含消息内容和可选的会话 ID
     * @return 包含会话 ID、回答文本、剩余提问次数、剩余消息数的响应
     */
    public AiChatResponse chat(AuthenticatedUser currentUser, AiChatRequest request) {
        User user = activeUser(currentUser);
        int dailyLimit = blogProperties.getAi().getDailyQuestionLimit();

        AiQuotaService.Reservation reservation = quotaService.reserve(user.getId(), dailyLimit);
        boolean completed = false;
        try {
            AiChatSession session = resolveSession(user, request.sessionId());
            long messageCount = messageRepository.countBySessionIdAndDeletedFalse(session.getId());
            if (messageCount + 2 > MAX_MESSAGES_PER_SESSION) {
                throw new BusinessException(HttpStatus.CONFLICT, "该会话消息数已达上限，请创建新会话");
            }

            String userMessageText = request.message().trim();
            String answer = generateAnswer(
                    userMessageText,
                    session.getId().toString(),
                    currentUser
            );
            long finalMessageCount = persistenceService.persistExchange(
                    user.getId(),
                    session.getId(),
                    userMessageText,
                    answer,
                    MAX_MESSAGES_PER_SESSION
            );
            completed = true;
            return new AiChatResponse(
                    session.getId(),
                    answer,
                    Math.max(0, dailyLimit - reservation.used()),
                    (int) (MAX_MESSAGES_PER_SESSION - finalMessageCount)
            );
        } finally {
            if (!completed) {
                releaseReservation(reservation);
            }
        }
    }

    /**
     * 流式对话接口。通过 SSE（Server-Sent Events）逐 token 推送 AI 回答。
     * <p>
     * 在异步线程中执行 AI 调用，通过 SseEmitter 向客户端推送事件：
     * <ul>
     *   <li>{@code token} 事件：每个 token 片段</li>
     *   <li>{@code done} 事件：流结束时携带完整响应</li>
     *   <li>{@code error} 事件：发生错误时的错误信息</li>
     * </ul>
     *
     * @param currentUser 当前登录用户
     * @param request     聊天请求，包含消息内容和可选的会话 ID
     * @return SSE 发射器，客户端通过此对象接收流式数据
     */
    public SseEmitter streamChat(AuthenticatedUser currentUser, AiChatRequest request) {
        SseEmitter emitter = new SseEmitter(600_000L);
        // 兜底：确保异常路径也能 complete emitter
        emitter.onTimeout(() -> {
            log.debug("SseEmitter timeout");
            emitter.complete();
        });
        emitter.onError(error -> {
            log.debug("SseEmitter error: {}", error.getMessage());
            emitter.complete();
        });
        try {
            aiStreamExecutor.execute(() -> doStreamChat(currentUser, request, emitter));
        } catch (RejectedExecutionException exception) {
            log.warn("AI stream executor is saturated");
            sendSseError(emitter, "AI 服务繁忙，请稍后重试");
        }
        return emitter;
    }

    /**
     * 流式对话的实际执行逻辑（在 aiStreamExecutor 线程中运行）。
     * <p>
     * 流程：预检查 → 向量搜索知识库 → 流式调用 AI → 持久化结果。
     * 用户身份通过请求级 ToolContext 显式传递，线程切换不会丢失或串用身份。
     */
    private void doStreamChat(AuthenticatedUser currentUser, AiChatRequest request, SseEmitter emitter) {
        User user;
        try {
            user = activeUser(currentUser);
        } catch (Exception e) {
            log.warn("streamChat 认证失败: {}", e.getMessage());
            sendSseError(emitter, "登录状态无效");
            return;
        }

        int dailyLimit = blogProperties.getAi().getDailyQuestionLimit();

        AiQuotaService.Reservation reservation;
        try {
            reservation = quotaService.reserve(user.getId(), dailyLimit);
        } catch (BusinessException exception) {
            log.warn("streamChat 配额用完: userId={}", user.getId());
            sendSseError(emitter, exception.getMessage());
            return;
        }

        AiChatSession session;
        try {
            session = resolveSession(user, request.sessionId());
        } catch (Exception e) {
            releaseReservation(reservation);
            log.warn("streamChat 会话解析失败: userId={}, error={}", user.getId(), e.getMessage());
            sendSseError(emitter, "会话不存在");
            return;
        }

        long messageCount = messageRepository.countBySessionIdAndDeletedFalse(session.getId());
        if (messageCount + 2 > MAX_MESSAGES_PER_SESSION) {
            releaseReservation(reservation);
            log.warn("streamChat 会话消息数达上限: sessionId={}, count={}", session.getId(), messageCount);
            sendSseError(emitter, "该会话消息数已达上限，请创建新会话");
            return;
        }

        String userMessageText = request.message().trim();
        log.info("streamChat 开始: userId={}, sessionId={}, messageLength={}",
                user.getId(), session.getId(), userMessageText.length());

        StringBuffer fullAnswer = new StringBuffer();
        AtomicBoolean quotaFinalized = new AtomicBoolean();
        AtomicReference<Disposable> subscriptionRef = new AtomicReference<>();
        Runnable cancelStream = () -> {
            Disposable subscription = subscriptionRef.get();
            if (subscription != null && !subscription.isDisposed()) {
                subscription.dispose();
            }
            releaseReservedQuota(reservation, quotaFinalized);
        };
        emitter.onCompletion(cancelStream);
        emitter.onTimeout(cancelStream);
        emitter.onError(error -> cancelStream.run());

        try {
            String conversationId = session.getId().toString();
            Disposable subscription = chatClient.prompt()
                    .user(userMessageText)
                    .advisors(a -> a.param(ChatMemory.CONVERSATION_ID, conversationId))
                    .tools(blogTools)
                    .toolContext(Map.of(
                            AiBlogTools.AUTHENTICATED_USER_CONTEXT_KEY,
                            currentUser
                    ))
                    .stream()
                    .chatResponse()
                    .publishOn(Schedulers.boundedElastic())
                    .subscribe(
                            response -> {
                                String token = extractToken(response);
                                if (token != null) {
                                    fullAnswer.append(token);
                                    try {
                                        emitter.send(SseEmitter.event().name(SSE_EVENT_TOKEN).data(token));
                                    } catch (Exception sendError) {
                                        log.debug("SSE client disconnected: sessionId={}", session.getId());
                                        cancelStream.run();
                                    }
                                }
                            },
                            error -> {
                                log.error("streamChat AI 流式调用失败: userId={}, sessionId={}, error={}",
                                        user.getId(), session.getId(), error.getMessage(), error);
                                releaseReservedQuota(reservation, quotaFinalized);
                                sendSseError(emitter, "AI 服务暂时不可用，请稍后重试");
                            },
                            () -> {
                                persistStreamResult(fullAnswer, userMessageText, user, session,
                                        dailyLimit, reservation, quotaFinalized, emitter);
                            }
                    );
            subscriptionRef.set(subscription);
        } catch (Exception e) {
            log.error("streamChat 异常: userId={}, error={}", user.getId(), e.getMessage(), e);
            releaseReservedQuota(reservation, quotaFinalized);
            sendSseError(emitter, "AI 服务暂时不可用，请稍后重试");
        }
    }

    /**
     * 从 AI 流式响应中提取 token 文本。
     *
     * @return token 文本，如果响应无效则返回 null
     */
    private String extractToken(org.springframework.ai.chat.model.ChatResponse response) {
        if (response.getResult() != null && response.getResult().getOutput() != null) {
            String token = response.getResult().getOutput().getText();
            if (token != null && !token.isEmpty()) {
                return token;
            }
        }
        return null;
    }

    /**
     * 流式调用完成后持久化消息和配额，发送 done 事件。
     * <p>
     * 此方法在 Schedulers.boundedElastic 线程上执行。
     * 只有在 AI 调用成功完成后才持久化数据，保证数据一致性。
     */
    private void persistStreamResult(
            StringBuffer fullAnswer,
            String userMessageText,
            User user,
            AiChatSession session,
            int dailyLimit,
            AiQuotaService.Reservation reservation,
            AtomicBoolean quotaFinalized,
            SseEmitter emitter
    ) {
        String answerText = fullAnswer.toString();
        log.info("streamChat 完成: userId={}, sessionId={}, answerLen={}",
                user.getId(), session.getId(), answerText.length());

        if (!quotaFinalized.compareAndSet(false, true)) {
            return;
        }
        long finalMessageCount;
        try {
            finalMessageCount = persistenceService.persistExchange(
                    user.getId(),
                    session.getId(),
                    userMessageText,
                    answerText,
                    MAX_MESSAGES_PER_SESSION
            );
        } catch (Exception e) {
            log.error("Failed to persist AI chat stream", e);
            releaseReservation(reservation);
            sendSseError(emitter, "保存对话失败，请稍后重试");
            return;
        }

        try {
            emitter.send(SseEmitter.event()
                    .name(SSE_EVENT_DONE)
                    .data(new AiChatResponse(
                            session.getId(),
                            answerText,
                            Math.max(0, dailyLimit - reservation.used()),
                            (int) (MAX_MESSAGES_PER_SESSION - finalMessageCount)
                    )));
        } catch (Exception e) {
            log.debug("SSE client disconnected before done event: sessionId={}", session.getId());
        } finally {
            emitter.complete();
        }
    }

    /**
     * 查询当前用户的每日 AI 配额使用情况。
     */
    @Transactional(readOnly = true)
    public AiQuotaResponse quota(AuthenticatedUser currentUser) {
        User user = activeUser(currentUser);
        int used = quotaService.used(user.getId());
        int dailyLimit = blogProperties.getAi().getDailyQuestionLimit();
        return new AiQuotaResponse(
                LocalDate.now(clock.withZone(QUOTA_ZONE)),
                dailyLimit,
                used
        );
    }

    /**
     * 创建新的 AI 聊天会话。
     */
    @Transactional
    public AiChatSessionResponse createSession(AuthenticatedUser currentUser, AiCreateSessionRequest request) {
        User user = activeUser(currentUser);

        long sessionCount = sessionRepository.countByUserIdAndDeletedFalse(user.getId());
        if (sessionCount >= MAX_SESSIONS_PER_USER) {
            throw new BusinessException(HttpStatus.CONFLICT,
                    "会话数量已达上限（" + MAX_SESSIONS_PER_USER + "个），请先删除旧会话再创建");
        }

        String title = request.title() != null ? request.title().trim() : DEFAULT_SESSION_TITLE;
        if (title.length() > MAX_SESSION_TITLE_LENGTH) {
            title = title.substring(0, MAX_SESSION_TITLE_LENGTH);
        }
        AiChatSession session = sessionRepository.save(new AiChatSession(user, title));
        return toSessionResponse(session, 0);
    }

    /**
     * 获取当前用户最近的 20 个 AI 聊天会话列表。
     */
    @Transactional(readOnly = true)
    public List<AiChatSessionResponse> listSessions(AuthenticatedUser currentUser) {
        User user = activeUser(currentUser);
        List<Object[]> results = sessionRepository.findTop20WithMessageCount(user.getId());
        return results.stream()
                .map(row -> toSessionResponse((AiChatSession) row[0], ((Long) row[1]).intValue()))
                .toList();
    }

    /**
     * 删除指定的 AI 聊天会话（逻辑删除）。
     */
    @Transactional
    public void deleteSession(AuthenticatedUser currentUser, UUID sessionId) {
        User user = activeUser(currentUser);
        AiChatSession session = sessionRepository.findByIdAndUserIdAndDeletedFalse(sessionId, user.getId())
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));
        session.markDeleted();
        sessionRepository.save(session);
    }

    /**
     * 分页获取指定会话的消息列表。
     */
    @Transactional(readOnly = true)
    public PageResponse<AiChatMessageResponse> sessionMessages(
            AuthenticatedUser currentUser, UUID sessionId, int page, int size
    ) {
        User user = activeUser(currentUser);
        AiChatSession session = sessionRepository.findByIdAndUserIdAndDeletedFalse(sessionId, user.getId())
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));

        int safePage = Math.max(0, page);
        int safeSize = Math.clamp(size, 1, 50);
        PageRequest pageRequest = PageRequest.of(safePage, safeSize, Sort.by(Sort.Direction.ASC, "createdAt"));

        Page<AiChatMessage> messagePage = messageRepository.findBySessionIdAndDeletedFalseOrderByCreatedAtAsc(
                session.getId(), pageRequest);

        List<AiChatMessageResponse> items = messagePage.getContent().stream()
                .map(m -> new AiChatMessageResponse(m.getId(), m.getRole().name(), m.getContent(), m.getAuditStatus(), m.getCreatedAt()))
                .toList();

        return new PageResponse<>(items, messagePage.getNumber(), messagePage.getSize(), messagePage.getTotalElements());
    }

    /**
     * 解析会话：如果提供了 sessionId 则查找对应会话，否则复用用户最近的会话或自动创建新会话。
     */
    private AiChatSession resolveSession(User user, UUID sessionId) {
        if (sessionId != null) {
            return sessionRepository.findByIdAndUserIdAndDeletedFalse(sessionId, user.getId())
                    .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));
        }
        return sessionRepository.findFirstByUserIdAndDeletedFalseOrderByUpdatedAtDesc(user.getId())
                .orElseGet(() -> sessionRepository.save(new AiChatSession(user, DEFAULT_SESSION_TITLE)));
    }

    /**
     * 调用 Spring AI ChatClient 生成同步回答。
     * <p>
     * 用户身份通过 ToolContext 与本次请求绑定。
     */
    private String generateAnswer(
            String userMessage,
            String conversationId,
            AuthenticatedUser currentUser
    ) {
        try {
            return chatClient.prompt()
                    .user(userMessage)
                    .advisors(a -> a.param(ChatMemory.CONVERSATION_ID, conversationId))
                    .tools(blogTools)
                    .toolContext(Map.of(
                            AiBlogTools.AUTHENTICATED_USER_CONTEXT_KEY,
                            currentUser
                    ))
                    .call()
                    .content();
        } catch (Exception e) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "AI 服务暂时不可用");
        }
    }

    private void releaseReservedQuota(
            AiQuotaService.Reservation reservation,
            AtomicBoolean quotaFinalized
    ) {
        if (quotaFinalized.compareAndSet(false, true)) {
            releaseReservation(reservation);
        }
    }

    private void releaseReservation(AiQuotaService.Reservation reservation) {
        try {
            quotaService.release(reservation);
        } catch (Exception exception) {
            log.error(
                    "Failed to release AI quota reservation for user {}",
                    reservation.userId(),
                    exception
            );
        }
    }

    /**
     * 根据认证信息获取活跃用户实体，若用户不存在或已禁用则抛出异常。
     */
    private User activeUser(AuthenticatedUser currentUser) {
        return userRepository.findById(currentUser.id())
                .filter(User::isActive)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
    }

    private AiChatSessionResponse toSessionResponse(AiChatSession session, int messageCount) {
        return new AiChatSessionResponse(
                session.getId(), session.getTitle(), messageCount,
                session.getCreatedAt(), session.getUpdatedAt()
        );
    }

    private void sendSseError(SseEmitter emitter, String message) {
        try {
            emitter.send(SseEmitter.event().name(SSE_EVENT_ERROR).data(message));
        } catch (Exception ignored) {
            // 发射器可能已关闭
        } finally {
            try {
                emitter.complete();
            } catch (Exception ignored) {
                // 发射器可能已经完成
            }
        }
    }
}
