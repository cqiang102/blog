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
import java.util.List;
import java.util.Map;
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

    /** 单个会话允许的最大消息数 */
    private static final int MAX_MESSAGES_PER_SESSION = 40;
    /** Redis 中每日配额缓存的 key 前缀 */
    private static final String QUOTA_CACHE_PREFIX = "ai:quota:";

    private final BlogProperties blogProperties;
    private final Clock clock;
    private final UserRepository userRepository;
    private final AiChatSessionRepository sessionRepository;
    private final AiChatMessageRepository messageRepository;
    private final AiDailyQuotaRepository quotaRepository;
    private final ChatClient chatClient;
    private final KnowledgeSearchService knowledgeSearchService;
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
            KnowledgeSearchService knowledgeSearchService,
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
        this.knowledgeSearchService = knowledgeSearchService;
        this.redisTemplate = redisTemplate;
        this.aiStreamExecutor = aiStreamExecutor;
    }

    /**
     * 同步对话接口。发送用户消息并一次性返回完整 AI 回答。
     * <p>
     * 处理流程：校验配额 → 解析会话 → 保存用户消息 → 更新配额 → 调用 AI 生成回答 → 保存助手消息。
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

        messageRepository.save(new AiChatMessage(session, AiMessageRole.USER, request.message().trim()));

        // 先调用 AI 生成回答
        AiUserContext.set(currentUser);
        String answer;
        try {
            answer = generateAnswer(request.message(), session.getId().toString());
        } finally {
            AiUserContext.clear();
        }

        // AI 调用成功后再扣减配额
        AiDailyQuota quota = quotaFor(user);
        quota.increase();
        quotaRepository.save(quota);

        String cacheKey = QUOTA_CACHE_PREFIX + user.getId() + ":" + LocalDate.now(clock.withZone(ZoneOffset.UTC));
        redisTemplate.delete(cacheKey);

        messageRepository.save(new AiChatMessage(session, AiMessageRole.ASSISTANT, answer));

        return new AiChatResponse(
                session.getId(),
                answer,
                Math.max(0, dailyLimit - quota.getQuestionCount()),
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

        aiStreamExecutor.execute(() -> {
            User user;
            try {
                user = activeUser(currentUser);
            } catch (Exception e) {
                log.warn("streamChat 认证失败: {}", e.getMessage());
                sendError(emitter, "登录状态无效");
                return;
            }

            int dailyLimit = blogProperties.getAi().getDailyQuestionLimit();
            int currentCount = getCachedQuotaCount(user.getId());
            if (currentCount >= dailyLimit) {
                log.warn("streamChat 配额用完: userId={}, used={}/{}", user.getId(), currentCount, dailyLimit);
                sendError(emitter, "今日 AI 提问次数已用完");
                return;
            }

            AiChatSession session;
            try {
                session = resolveSession(user, request.sessionId());
            } catch (Exception e) {
                log.warn("streamChat 会话解析失败: userId={}, error={}", user.getId(), e.getMessage());
                sendError(emitter, "会话不存在");
                return;
            }

            long messageCount = messageRepository.countBySessionId(session.getId());
            if (messageCount >= MAX_MESSAGES_PER_SESSION) {
                log.warn("streamChat 会话消息数达上限: sessionId={}, count={}", session.getId(), messageCount);
                sendError(emitter, "该会话消息数已达上限，请创建新会话");
                return;
            }

            messageRepository.save(new AiChatMessage(session, AiMessageRole.USER, request.message().trim()));
            log.info("streamChat 开始: userId={}, sessionId={}, message={}", user.getId(), session.getId(), request.message());

            // 向量搜索相关知识作为上下文
            String knowledgeContext = buildKnowledgeContext(request.message());

            StringBuilder fullAnswer = new StringBuilder();
            AiUserContext.set(currentUser);
            try {
                String conversationId = session.getId().toString();
                String userMessage = knowledgeContext.isEmpty()
                        ? request.message()
                        : request.message() + "\n\n[相关知识库内容]\n" + knowledgeContext;
                chatClient.prompt()
                        .user(userMessage)
                        // TODO: 等 Spring AI 修复 toolCallId bug 后启用工具调用
                        // .toolCallbacks(ToolCallbacks.from(aiBlogTools))
                        .advisors(a -> a.param(ChatMemory.CONVERSATION_ID, conversationId))
                        .stream()
                        .chatResponse()
                        .publishOn(Schedulers.boundedElastic())
                        .subscribe(
                                response -> {
                                    if (response.getResult() != null && response.getResult().getOutput() != null) {
                                        String token = response.getResult().getOutput().getText();
                                        if (token != null && !token.isEmpty()) {
                                            fullAnswer.append(token);
                                            try {
                                                emitter.send(SseEmitter.event()
                                                        .name("token")
                                                        .data(token));
                                            } catch (Exception ignored) {
                                            }
                                        }
                                    }
                                },
                                error -> {
                                    log.error("streamChat AI 流式调用失败: userId={}, sessionId={}, error={}",
                                            user.getId(), session.getId(), error.getMessage(), error);
                                    sendError(emitter, "AI 服务暂时不可用: " + error.getMessage());
                                    AiUserContext.clear();
                                },
                                () -> {
                                    log.info("streamChat 完成: userId={}, sessionId={}, answerLen={}",
                                            user.getId(), session.getId(), fullAnswer.length());
                                    try {
                                        AiDailyQuota quota = quotaFor(user);
                                        quota.increase();
                                        quotaRepository.save(quota);
                                        String cacheKey = QUOTA_CACHE_PREFIX + user.getId() + ":" + LocalDate.now(clock.withZone(ZoneOffset.UTC));
                                        redisTemplate.delete(cacheKey);
                                    } catch (Exception e) {
                                        log.error("Failed to update quota after successful AI call", e);
                                    }

                                    try {
                                        messageRepository.save(new AiChatMessage(session, AiMessageRole.ASSISTANT, fullAnswer.toString()));
                                    } catch (Exception e) {
                                        log.error("Failed to save AI chat message", e);
                                    }

                                    try {
                                        int remainingQuota = Math.max(0, dailyLimit - getCachedQuotaCount(user.getId()));
                                        emitter.send(SseEmitter.event()
                                                .name("done")
                                                .data(new AiChatResponse(
                                                        session.getId(),
                                                        fullAnswer.toString(),
                                                        remainingQuota,
                                                        (int) (MAX_MESSAGES_PER_SESSION - messageCount - 2)
                                                )));
                                    } catch (Exception e) {
                                        log.error("Failed to send done event", e);
                                    } finally {
                                        try {
                                            emitter.complete();
                                        } catch (Exception ignored) {
                                        }
                                        AiUserContext.clear();
                                    }
                                }
                        );
            } catch (Exception e) {
                log.error("streamChat 异常: userId={}, error={}", user.getId(), e.getMessage(), e);
                sendError(emitter, "AI 服务暂时不可用: " + e.getMessage());
                AiUserContext.clear();
            }
        });

        return emitter;
    }

    /**
     * 查询当前用户的每日 AI 配额使用情况。
     *
     * @param currentUser 当前登录用户
     * @return 包含今日日期、每日限额、已使用次数的配额信息
     */
    @Transactional(readOnly = true)
    public AiQuotaResponse quota(AuthenticatedUser currentUser) {
        User user = activeUser(currentUser);
        int used = getCachedQuotaCount(user.getId());
        int dailyLimit = blogProperties.getAi().getDailyQuestionLimit();
        return new AiQuotaResponse(LocalDate.now(clock.withZone(ZoneOffset.UTC)), dailyLimit, used);
    }

    /**
     * 创建新的 AI 聊天会话。
     *
     * @param currentUser 当前登录用户
     * @param request     创建会话请求，可选包含标题（默认为"新会话"，最大 40 字符）
     * @return 新创建的会话信息
     */
    @Transactional
    public AiChatSessionResponse createSession(AuthenticatedUser currentUser, AiCreateSessionRequest request) {
        User user = activeUser(currentUser);
        String title = request.title() != null ? request.title().trim() : "新会话";
        if (title.length() > 40) {
            title = title.substring(0, 40);
        }
        AiChatSession session = sessionRepository.save(new AiChatSession(user, title));
        return toSessionResponse(session, 0);
    }

    /**
     * 获取当前用户最近的 20 个 AI 聊天会话列表。
     *
     * @param currentUser 当前登录用户
     * @return 按更新时间倒序排列的会话列表，包含每个会话的消息数
     */
    @Transactional(readOnly = true)
    public List<AiChatSessionResponse> listSessions(AuthenticatedUser currentUser) {
        User user = activeUser(currentUser);
        List<Object[]> results = sessionRepository.findTop20WithMessageCount(user.getId());
        return results.stream()
                .map(row -> {
                    AiChatSession session = (AiChatSession) row[0];
                    Long messageCount = (Long) row[1];
                    return toSessionResponse(session, messageCount.intValue());
                })
                .toList();
    }

    /**
     * 分页获取指定会话的消息列表。
     *
     * @param currentUser 当前登录用户
     * @param sessionId   会话 ID
     * @param page        页码（从 0 开始）
     * @param size        每页大小（最大 50）
     * @return 分页消息列表，按创建时间正序排列
     */
    @Transactional(readOnly = true)
    public PageResponse<AiChatMessageResponse> sessionMessages(
            AuthenticatedUser currentUser, UUID sessionId, int page, int size
    ) {
        User user = activeUser(currentUser);
        AiChatSession session = sessionRepository.findByIdAndUserId(sessionId, user.getId())
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));

        int safePage = Math.max(0, page);
        int safeSize = Math.clamp(size, 1, 50);
        PageRequest pageRequest = PageRequest.of(safePage, safeSize, Sort.by(Sort.Direction.ASC, "createdAt"));

        Page<AiChatMessage> messagePage = messageRepository.findBySessionIdOrderByCreatedAtAsc(session.getId(), pageRequest);

        List<AiChatMessageResponse> items = messagePage.getContent().stream()
                .map(m -> new AiChatMessageResponse(
                        m.getId(),
                        m.getRole().name(),
                        m.getContent(),
                        m.getCreatedAt()
                ))
                .toList();

        return new PageResponse<>(items, messagePage.getNumber(), messagePage.getSize(), messagePage.getTotalElements());
    }

    /**
     * 解析会话：如果提供了 sessionId 则查找对应会话，否则复用用户最近的会话或自动创建新会话。
     *
     * @param user      当前用户
     * @param sessionId 可选的会话 ID
     * @return 解析后的会话实体
     */
    private AiChatSession resolveSession(User user, UUID sessionId) {
        if (sessionId != null) {
            return sessionRepository.findByIdAndUserId(sessionId, user.getId())
                    .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));
        }
        return sessionRepository.findFirstByUserIdOrderByUpdatedAtDesc(user.getId())
                .orElseGet(() -> sessionRepository.save(new AiChatSession(user, "新会话")));
    }

    /**
     * 调用 Spring AI ChatClient 生成同步回答。
     *
     * @param userMessage    用户消息内容
     * @param conversationId 会话 ID，用于 ChatMemory 维护上下文
     * @return AI 生成的回答文本
     */
    private String generateAnswer(String userMessage, String conversationId) {
        try {
            return chatClient.prompt()
                    .user(userMessage)
                    // TODO: 等 Spring AI 修复 toolCallId bug 后启用工具调用
                    // .toolCallbacks(ToolCallbacks.from(aiBlogTools))
                    .advisors(a -> a.param(ChatMemory.CONVERSATION_ID, conversationId))
                    .call()
                    .content();
        } catch (Exception e) {
            return "抱歉，AI 服务暂时不可用。错误信息: " + e.getMessage();
        }
    }

    /**
     * 构建知识库上下文。
     * 搜索向量数据库，将相关内容格式化为上下文字符串。
     *
     * @param query 用户消息
     * @return 格式化的知识上下文，无结果时返回空字符串
     */
    private String buildKnowledgeContext(String query) {
        try {
            List<Map<String, Object>> results = knowledgeSearchService.search(query);
            log.info("知识库搜索: query={}, results={}", query, results.size());
            if (results.isEmpty()) {
                return "";
            }
            StringBuilder sb = new StringBuilder();
            for (Map<String, Object> result : results) {
                String title = (String) result.get("title");
                String content = (String) result.get("content");
                if (title != null && content != null) {
                    sb.append("- ").append(title).append(": ").append(content).append("\n");
                }
            }
            return sb.toString();
        } catch (Exception e) {
            log.warn("知识库搜索失败: {}", e.getMessage());
            return "";
        }
    }

    /**
     * 获取或创建用户今日的配额记录。
     *
     * @param user 当前用户
     * @return 今日的配额实体
     */
    private AiDailyQuota quotaFor(User user) {
        LocalDate today = LocalDate.now(clock.withZone(ZoneOffset.UTC));
        return quotaRepository.findByUserIdAndQuotaDate(user.getId(), today)
                .orElseGet(() -> quotaRepository.save(new AiDailyQuota(user, today)));
    }

    /**
     * 获取用户今日已使用的提问次数（优先从 Redis 缓存读取，缓存未命中时回源数据库）。
     *
     * @param userId 用户 ID
     * @return 今日已使用次数
     */
    private int getCachedQuotaCount(UUID userId) {
        String cacheKey = QUOTA_CACHE_PREFIX + userId + ":" + LocalDate.now(clock.withZone(ZoneOffset.UTC));
        String cached = redisTemplate.opsForValue().get(cacheKey);
        if (cached != null) {
            return Integer.parseInt(cached);
        }

        LocalDate today = LocalDate.now(clock.withZone(ZoneOffset.UTC));
        int count = quotaRepository.findByUserIdAndQuotaDate(userId, today)
                .map(AiDailyQuota::getQuestionCount)
                .orElse(0);

        redisTemplate.opsForValue().set(cacheKey, String.valueOf(count));
        redisTemplate.expire(cacheKey, getSecondsUntilMidnight(), TimeUnit.SECONDS);
        return count;
    }

    /**
     * 计算距离 UTC 午夜的秒数，用于设置 Redis 缓存过期时间。
     *
     * @return 距离午夜的秒数
     */
    private long getSecondsUntilMidnight() {
        LocalDate today = LocalDate.now(clock.withZone(ZoneOffset.UTC));
        return java.time.Duration.between(
                java.time.ZonedDateTime.now(clock.withZone(ZoneOffset.UTC)),
                today.plusDays(1).atStartOfDay(ZoneOffset.UTC)
        ).getSeconds();
    }

    /**
     * 根据认证信息获取活跃用户实体，若用户不存在或已禁用则抛出异常。
     *
     * @param currentUser 当前认证用户
     * @return 用户实体
     */
    private User activeUser(AuthenticatedUser currentUser) {
        return userRepository.findById(currentUser.id())
                .filter(User::isActive)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
    }

    /**
     * 将会话实体转换为响应 DTO。
     */
    private AiChatSessionResponse toSessionResponse(AiChatSession session, int messageCount) {
        return new AiChatSessionResponse(
                session.getId(),
                session.getTitle(),
                messageCount,
                session.getCreatedAt(),
                session.getUpdatedAt()
        );
    }

    /**
     * 通过 SSE 向客户端发送错误事件并完成发射器。
     */
    private void sendError(SseEmitter emitter, String message) {
        try {
            emitter.send(SseEmitter.event().name("error").data(message));
            emitter.complete();
        } catch (Exception ignored) {
        }
    }
}
