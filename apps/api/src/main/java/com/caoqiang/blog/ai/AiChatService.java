package com.caoqiang.blog.ai;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.user.User;
import com.caoqiang.blog.user.UserRepository;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Executor;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

import reactor.core.scheduler.Schedulers;

/**
 * AI 聊天核心服务。
 * <p>
 * 职责：管理用户的 AI 对话会话、消息持久化、每日配额控制，以及同步/流式两种对话模式。
 * 在架构中位于 Controller 与 Spring AI ChatClient 之间，是 AI 聊天功能的业务中枢。
 * <p>
 * 关键特性：
 * <ul>
 *   <li>会话管理：自动创建或复用会话，限制单会话最大消息数（{@value #MAX_MESSAGES_PER_SESSION}）</li>
 *   <li>配额控制：基于 Redis 缓存 + 数据库双重保障的每日提问次数限制</li>
 *   <li>同步对话：通过 {@link #chat} 一次性返回完整回答</li>
 *   <li>流式对话：通过 {@link #streamChat} 使用 SSE 逐 token 推送回答</li>
 *   <li>工具调用上下文：通过 {@link AiUserContext} 将当前用户传递给 AI 工具层</li>
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
    /** Redis 中每日配额缓存的 key 前缀 */
    private static final String QUOTA_CACHE_PREFIX = "ai:quota:";
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
    private final AiDailyQuotaRepository quotaRepository;
    private final ChatClient chatClient;
    private final AiBlogTools blogTools;
    private final StringRedisTemplate redisTemplate;
    private final Executor aiStreamExecutor;

    public AiChatService(
            BlogProperties blogProperties,
            Clock clock,
            UserRepository userRepository,
            AiChatSessionRepository sessionRepository,
            AiChatMessageRepository messageRepository,
            AiDailyQuotaRepository quotaRepository,
            ChatClient chatClient,
            AiBlogTools blogTools,
            StringRedisTemplate redisTemplate,
            @Qualifier("aiStreamExecutor") Executor aiStreamExecutor
    ) {
        this.blogProperties = blogProperties;
        this.clock = clock;
        this.userRepository = userRepository;
        this.sessionRepository = sessionRepository;
        this.messageRepository = messageRepository;
        this.quotaRepository = quotaRepository;
        this.chatClient = chatClient;
        this.blogTools = blogTools;
        this.redisTemplate = redisTemplate;
        this.aiStreamExecutor = aiStreamExecutor;
    }

    /**
     * 同步对话接口。发送用户消息并一次性返回完整 AI 回答。
     * <p>
     * 处理流程：校验配额 → 解析会话 → 调用 AI 生成回答 → 保存用户消息和助手消息 → 更新配额。
     * AI 调用成功后才持久化消息和配额，保证数据一致性。
     *
     * @param currentUser 当前登录用户
     * @param request     聊天请求，包含消息内容和可选的会话 ID
     * @return 包含会话 ID、回答文本、剩余提问次数、剩余消息数的响应
     */
    @Transactional
    public AiChatResponse chat(AuthenticatedUser currentUser, AiChatRequest request) {
        User user = activeUser(currentUser);
        int dailyLimit = blogProperties.getAi().getDailyQuestionLimit();
        int currentCount = getCachedQuotaCount(user.getId());

        if (currentCount >= dailyLimit) {
            throw new BusinessException(HttpStatus.TOO_MANY_REQUESTS, "今日 AI 提问次数已用完");
        }

        AiChatSession session = resolveSession(user, request.sessionId());
        long messageCount = messageRepository.countBySessionId(session.getId());
        if (messageCount >= MAX_MESSAGES_PER_SESSION) {
            throw new BusinessException(HttpStatus.CONFLICT, "该会话消息数已达上限，请创建新会话");
        }

        String userMessageText = request.message().trim();
        // AiUserContext 必须在当前线程（事务线程）上 set/clear 配对，避免 ThreadLocal 泄漏
        AiUserContext.set(currentUser);
        String answer;
        try {
            answer = generateAnswer(userMessageText, session.getId().toString());
        } finally {
            AiUserContext.clear();
        }

        // AI 调用成功后才持久化消息和配额，失败则整个事务回滚，保证数据一致性
        messageRepository.save(new AiChatMessage(session, AiMessageRole.USER, userMessageText));
        messageRepository.save(new AiChatMessage(session, AiMessageRole.ASSISTANT, answer));
        incrementQuota(user);

        return new AiChatResponse(
                session.getId(), answer,
                Math.max(0, dailyLimit - (currentCount + 1)),
                (int) (MAX_MESSAGES_PER_SESSION - messageCount - 2)
        );
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
        SseEmitter emitter = new SseEmitter(0L);
        // 通过 lambda 捕获 currentUser 引用传递到异步线程，而非依赖 ThreadLocal（ThreadLocal 不跨线程传播）
        aiStreamExecutor.execute(() -> doStreamChat(currentUser, request, emitter));
        return emitter;
    }

    /**
     * 流式对话的实际执行逻辑（在 aiStreamExecutor 线程中运行）。
     * <p>
     * 流程：预检查 → 向量搜索知识库 → 流式调用 AI → 持久化结果。
     * AiUserContext 在 aiStreamExecutor 线程上设置和清除，保证 ThreadLocal 配对执行。
     * subscribe 的 error/complete 回调运行在 boundedElastic 线程上，不操作此 ThreadLocal。
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
        int currentCount = getCachedQuotaCount(user.getId());
        if (currentCount >= dailyLimit) {
            log.warn("streamChat 配额用完: userId={}, used={}/{}", user.getId(), currentCount, dailyLimit);
            sendSseError(emitter, "今日 AI 提问次数已用完");
            return;
        }

        AiChatSession session;
        try {
            session = resolveSession(user, request.sessionId());
        } catch (Exception e) {
            log.warn("streamChat 会话解析失败: userId={}, error={}", user.getId(), e.getMessage());
            sendSseError(emitter, "会话不存在");
            return;
        }

        long messageCount = messageRepository.countBySessionId(session.getId());
        if (messageCount >= MAX_MESSAGES_PER_SESSION) {
            log.warn("streamChat 会话消息数达上限: sessionId={}, count={}", session.getId(), messageCount);
            sendSseError(emitter, "该会话消息数已达上限，请创建新会话");
            return;
        }

        String userMessageText = request.message().trim();
        log.info("streamChat 开始: userId={}, sessionId={}, message={}", user.getId(), session.getId(), userMessageText);

        StringBuilder fullAnswer = new StringBuilder();
        try {
            // 在 aiStreamExecutor 线程上设置 AiUserContext，供 AI 工具层获取当前用户
            AiUserContext.set(currentUser);
            String conversationId = session.getId().toString();
            chatClient.prompt()
                    .user(userMessageText)
                    .advisors(a -> a.param(ChatMemory.CONVERSATION_ID, conversationId))
                    .tools(blogTools)
                    .stream()
                    .chatResponse()
                    .publishOn(Schedulers.boundedElastic())
                    .subscribe(
                            response -> {
                                // token 回调在 boundedElastic 线程上，无需操作 AiUserContext
                                String token = extractToken(response);
                                if (token != null) {
                                    fullAnswer.append(token);
                                    try {
                                        emitter.send(SseEmitter.event().name(SSE_EVENT_TOKEN).data(token));
                                    } catch (Exception ignored) {
                                        // 客户端可能已断开连接
                                    }
                                }
                            },
                            error -> {
                                // error 回调在 boundedElastic 线程上，无需操作 AiUserContext（未在此线程设置）
                                log.error("streamChat AI 流式调用失败: userId={}, sessionId={}, error={}",
                                        user.getId(), session.getId(), error.getMessage(), error);
                                sendSseError(emitter, "AI 服务暂时不可用: " + error.getMessage());
                            },
                            () -> {
                                // complete 回调在 boundedElastic 线程上，无需操作 AiUserContext
                                // AI 调用成功后才持久化消息和配额
                                persistStreamResult(fullAnswer, userMessageText, user, session,
                                        messageCount, dailyLimit, emitter);
                            }
                    );
        } catch (Exception e) {
            log.error("streamChat 异常: userId={}, error={}", user.getId(), e.getMessage(), e);
            sendSseError(emitter, "AI 服务暂时不可用: " + e.getMessage());
        } finally {
            // 必须在设置 AiUserContext 的同一线程（aiStreamExecutor）上清除
            AiUserContext.clear();
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
     * �式调用完成后持久化消息和配额，发送 done 事件。
     * <p>
     * 此方法在 Schedulers.boundedElastic 线程上执行。
     * 只有在 AI 调用成功完成后才持久化数据，保证数据一致性。
     */
    private void persistStreamResult(
            StringBuilder fullAnswer,
            String userMessageText,
            User user,
            AiChatSession session,
            long messageCount,
            int dailyLimit,
            SseEmitter emitter
    ) {
        String answerText = fullAnswer.toString();
        log.info("streamChat 完成: userId={}, sessionId={}, answerLen={}",
                user.getId(), session.getId(), answerText.length());

        try {
            messageRepository.save(new AiChatMessage(session, AiMessageRole.USER, userMessageText));
            messageRepository.save(new AiChatMessage(session, AiMessageRole.ASSISTANT, answerText));
        } catch (Exception e) {
            log.error("Failed to save AI chat message", e);
        }

        try {
            incrementQuota(user);
        } catch (Exception e) {
            log.error("Failed to update quota after successful AI call", e);
        }

        try {
            int remainingQuota = Math.max(0, dailyLimit - getCachedQuotaCount(user.getId()));
            emitter.send(SseEmitter.event()
                    .name(SSE_EVENT_DONE)
                    .data(new AiChatResponse(
                            session.getId(), answerText, remainingQuota,
                            (int) (MAX_MESSAGES_PER_SESSION - messageCount - 2)
                    )));
        } catch (Exception e) {
            log.error("Failed to send done event", e);
        } finally {
            try {
                emitter.complete();
            } catch (Exception ignored) {
                // 发射器可能已经完成
            }
        }
    }

    /**
     * 查询当前用户的每日 AI 配额使用情况。
     */
    @Transactional(readOnly = true)
    public AiQuotaResponse quota(AuthenticatedUser currentUser) {
        User user = activeUser(currentUser);
        int used = getCachedQuotaCount(user.getId());
        int dailyLimit = blogProperties.getAi().getDailyQuestionLimit();
        return new AiQuotaResponse(LocalDate.now(QUOTA_ZONE), dailyLimit, used);
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
                .map(m -> new AiChatMessageResponse(m.getId(), m.getRole().name(), m.getContent(), m.getCreatedAt()))
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
     * AiUserContext 必须在调用此方法前由调用方设置，调用完成后由调用方清除。
     * 此方法运行在调用方线程上，ThreadLocal 的 set/clear 保证在同一事务线程中配对。
     */
    private String generateAnswer(String userMessage, String conversationId) {
        try {
            return chatClient.prompt()
                    .user(userMessage)
                    .advisors(a -> a.param(ChatMemory.CONVERSATION_ID, conversationId))
                    .tools(blogTools)
                    .call()
                    .content();
        } catch (Exception e) {
            return "抱歉，AI 服务暂时不可用。错误信息: " + e.getMessage();
        }
    }

    /**
     * 递增用户的每日 AI 配额计数，并清除 Redis 缓存以强制下次回源。
     */
    private void incrementQuota(User user) {
        AiDailyQuota quota = quotaFor(user);
        quota.increase();
        quotaRepository.save(quota);
        String cacheKey = QUOTA_CACHE_PREFIX + user.getId() + ":" + LocalDate.now(QUOTA_ZONE);
        redisTemplate.delete(cacheKey);
    }

    /**
     * 获取或创建用户今日的配额记录（按 UTC+8 时区计算）。
     */
    private AiDailyQuota quotaFor(User user) {
        LocalDate today = LocalDate.now(QUOTA_ZONE);
        return quotaRepository.findByUserIdAndQuotaDate(user.getId(), today)
                .orElseGet(() -> quotaRepository.save(new AiDailyQuota(user, today)));
    }

    /**
     * 获取用户今日已使用的提问次数（优先从 Redis 缓存读取，缓存未命中时回源数据库）。
     * 配额按 UTC+8 时区计算，每天 0 点重置。
     */
    private int getCachedQuotaCount(UUID userId) {
        String cacheKey = QUOTA_CACHE_PREFIX + userId + ":" + LocalDate.now(QUOTA_ZONE);
        String cached = redisTemplate.opsForValue().get(cacheKey);
        if (cached != null) {
            return Integer.parseInt(cached);
        }

        LocalDate today = LocalDate.now(QUOTA_ZONE);
        int count = quotaRepository.findByUserIdAndQuotaDate(userId, today)
                .map(AiDailyQuota::getQuestionCount)
                .orElse(0);

        redisTemplate.opsForValue().set(cacheKey, String.valueOf(count));
        redisTemplate.expire(cacheKey, getSecondsUntilMidnight(), TimeUnit.SECONDS);
        return count;
    }

    /**
     * 计算距离 UTC+8 午夜的秒数，用于设置 Redis 缓存过期时间。
     */
    private long getSecondsUntilMidnight() {
        LocalDate today = LocalDate.now(QUOTA_ZONE);
        return java.time.Duration.between(
                ZonedDateTime.now(QUOTA_ZONE),
                today.plusDays(1).atStartOfDay(QUOTA_ZONE)
        ).getSeconds();
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
            emitter.complete();
        } catch (Exception ignored) {
            // 发射器可能已关闭
        }
    }
}
