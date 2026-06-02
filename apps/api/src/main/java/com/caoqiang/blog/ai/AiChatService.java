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
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@Service
public class AiChatService {

    private static final int MAX_MESSAGES_PER_SESSION = 40;
    private static final String QUOTA_CACHE_PREFIX = "ai:quota:";

    private final BlogProperties blogProperties;
    private final Clock clock;
    private final UserRepository userRepository;
    private final AiChatSessionRepository sessionRepository;
    private final AiChatMessageRepository messageRepository;
    private final AiDailyQuotaRepository quotaRepository;
    private final ChatClient chatClient;
    private final StringRedisTemplate redisTemplate;

    public AiChatService(
            BlogProperties blogProperties,
            Clock clock,
            UserRepository userRepository,
            AiChatSessionRepository sessionRepository,
            AiChatMessageRepository messageRepository,
            AiDailyQuotaRepository quotaRepository,
            ChatClient chatClient,
            StringRedisTemplate redisTemplate
    ) {
        this.blogProperties = blogProperties;
        this.clock = clock;
        this.userRepository = userRepository;
        this.sessionRepository = sessionRepository;
        this.messageRepository = messageRepository;
        this.quotaRepository = quotaRepository;
        this.chatClient = chatClient;
        this.redisTemplate = redisTemplate;
    }

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

        AiDailyQuota quota = quotaFor(user);
        quota.increase();

        String cacheKey = QUOTA_CACHE_PREFIX + user.getId() + ":" + LocalDate.now(clock.withZone(ZoneOffset.UTC));
        redisTemplate.opsForValue().increment(cacheKey);
        redisTemplate.expire(cacheKey, getSecondsUntilMidnight(), TimeUnit.SECONDS);

        AiUserContext.set(currentUser);
        String answer;
        try {
            answer = generateAnswer(request.message(), session.getId().toString());
        } finally {
            AiUserContext.clear();
        }

        messageRepository.save(new AiChatMessage(session, AiMessageRole.ASSISTANT, answer));

        return new AiChatResponse(
                session.getId(),
                answer,
                Math.max(0, dailyLimit - quota.getQuestionCount()),
                (int) (MAX_MESSAGES_PER_SESSION - messageCount - 2)
        );
    }

    public SseEmitter streamChat(AuthenticatedUser currentUser, AiChatRequest request) {
        SseEmitter emitter = new SseEmitter(120_000L);

        org.springframework.core.task.AsyncTaskExecutor taskExecutor =
                new org.springframework.core.task.SimpleAsyncTaskExecutor("ai-stream-");

        taskExecutor.execute(() -> {
            User user;
            try {
                user = activeUser(currentUser);
            } catch (Exception e) {
                sendError(emitter, "登录状态无效");
                return;
            }

            int dailyLimit = blogProperties.getAi().getDailyQuestionLimit();
            int currentCount = getCachedQuotaCount(user.getId());
            if (currentCount >= dailyLimit) {
                sendError(emitter, "今日 AI 提问次数已用完");
                return;
            }

            AiChatSession session;
            try {
                session = resolveSession(user, request.sessionId());
            } catch (Exception e) {
                sendError(emitter, "会话不存在");
                return;
            }

            long messageCount = messageRepository.countBySessionId(session.getId());
            if (messageCount >= MAX_MESSAGES_PER_SESSION) {
                sendError(emitter, "该会话消息数已达上限，请创建新会话");
                return;
            }

            messageRepository.save(new AiChatMessage(session, AiMessageRole.USER, request.message().trim()));

            AiDailyQuota quota;
            try {
                quota = quotaFor(user);
                quota.increase();
                String cacheKey = QUOTA_CACHE_PREFIX + user.getId() + ":" + LocalDate.now(clock.withZone(ZoneOffset.UTC));
                redisTemplate.opsForValue().increment(cacheKey);
                redisTemplate.expire(cacheKey, getSecondsUntilMidnight(), TimeUnit.SECONDS);
            } catch (Exception e) {
                sendError(emitter, "配额更新失败");
                return;
            }

            StringBuilder fullAnswer = new StringBuilder();
            AiUserContext.set(currentUser);
            try {
                String conversationId = session.getId().toString();
                chatClient.prompt()
                        .user(request.message())
                        .advisors(a -> a.param(ChatMemory.CONVERSATION_ID, conversationId))
                        .stream()
                        .chatResponse()
                        .doOnNext(response -> {
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
                        })
                        .doOnError(e -> sendError(emitter, "AI 服务暂时不可用: " + e.getMessage()))
                        .doOnComplete(() -> {
                            messageRepository.save(new AiChatMessage(session, AiMessageRole.ASSISTANT, fullAnswer.toString()));
                            try {
                                emitter.send(SseEmitter.event()
                                        .name("done")
                                        .data(new AiChatResponse(
                                                session.getId(),
                                                fullAnswer.toString(),
                                                Math.max(0, dailyLimit - quota.getQuestionCount()),
                                                (int) (MAX_MESSAGES_PER_SESSION - messageCount - 2)
                                        )));
                                emitter.complete();
                            } catch (Exception ignored) {
                            }
                        })
                        .subscribe();
            } catch (Exception e) {
                sendError(emitter, "AI 服务暂时不可用: " + e.getMessage());
            } finally {
                AiUserContext.clear();
            }
        });

        return emitter;
    }

    @Transactional(readOnly = true)
    public AiQuotaResponse quota(AuthenticatedUser currentUser) {
        User user = activeUser(currentUser);
        LocalDate today = LocalDate.now(clock.withZone(ZoneOffset.UTC));
        int used = quotaRepository.findByUserIdAndQuotaDate(user.getId(), today)
                .map(AiDailyQuota::getQuestionCount)
                .orElse(0);
        return new AiQuotaResponse(today, blogProperties.getAi().getDailyQuestionLimit(), used);
    }

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

    @Transactional(readOnly = true)
    public List<AiChatSessionResponse> listSessions(AuthenticatedUser currentUser) {
        User user = activeUser(currentUser);
        List<AiChatSession> sessions = sessionRepository.findTop20ByUserIdOrderByUpdatedAtDesc(user.getId());
        return sessions.stream()
                .map(s -> toSessionResponse(s, (int) messageRepository.countBySessionId(s.getId())))
                .toList();
    }

    @Transactional(readOnly = true)
    public PageResponse<AiChatMessageResponse> sessionMessages(
            AuthenticatedUser currentUser, UUID sessionId, int page, int size
    ) {
        User user = activeUser(currentUser);
        AiChatSession session = sessionRepository.findByIdAndUserId(sessionId, user.getId())
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));

        List<AiChatMessage> messages = messageRepository.findBySessionIdOrderByCreatedAtAsc(session.getId());
        int total = messages.size();
        int safePage = Math.max(0, page);
        int safeSize = Math.max(1, Math.min(size, 50));
        int from = Math.min(safePage * safeSize, total);
        int to = Math.min(from + safeSize, total);

        List<AiChatMessageResponse> items = messages.subList(from, to).stream()
                .map(m -> new AiChatMessageResponse(
                        m.getId(),
                        m.getRole().name(),
                        m.getContent(),
                        m.getCreatedAt()
                ))
                .toList();

        return new PageResponse<>(items, safePage, safeSize, total);
    }

    private AiChatSession resolveSession(User user, UUID sessionId) {
        if (sessionId != null) {
            return sessionRepository.findByIdAndUserId(sessionId, user.getId())
                    .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));
        }
        return sessionRepository.findFirstByUserIdOrderByUpdatedAtDesc(user.getId())
                .orElseGet(() -> sessionRepository.save(new AiChatSession(user, "新会话")));
    }

    private String generateAnswer(String userMessage, String conversationId) {
        try {
            return chatClient.prompt()
                    .user(userMessage)
                    .advisors(a -> a.param(ChatMemory.CONVERSATION_ID, conversationId))
                    .call()
                    .content();
        } catch (Exception e) {
            return "抱歉，AI 服务暂时不可用。错误信息: " + e.getMessage();
        }
    }

    private AiDailyQuota quotaFor(User user) {
        LocalDate today = LocalDate.now(clock.withZone(ZoneOffset.UTC));
        return quotaRepository.findByUserIdAndQuotaDate(user.getId(), today)
                .orElseGet(() -> quotaRepository.save(new AiDailyQuota(user, today)));
    }

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

    private long getSecondsUntilMidnight() {
        LocalDate today = LocalDate.now(clock.withZone(ZoneOffset.UTC));
        return java.time.Duration.between(
                java.time.ZonedDateTime.now(clock.withZone(ZoneOffset.UTC)),
                today.plusDays(1).atStartOfDay(ZoneOffset.UTC)
        ).getSeconds();
    }

    private User activeUser(AuthenticatedUser currentUser) {
        return userRepository.findById(currentUser.id())
                .filter(User::isActive)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
    }

    private AiChatSessionResponse toSessionResponse(AiChatSession session, int messageCount) {
        return new AiChatSessionResponse(
                session.getId(),
                session.getTitle(),
                messageCount,
                session.getCreatedAt(),
                session.getUpdatedAt()
        );
    }

    private void sendError(SseEmitter emitter, String message) {
        try {
            emitter.send(SseEmitter.event().name("error").data(message));
            emitter.complete();
        } catch (Exception ignored) {
        }
    }
}
