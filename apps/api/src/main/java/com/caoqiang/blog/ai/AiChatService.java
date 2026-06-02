package com.caoqiang.blog.ai;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.content.Content;
import com.caoqiang.blog.content.ContentRepository;
import com.caoqiang.blog.content.ContentStatus;
import com.caoqiang.blog.user.User;
import com.caoqiang.blog.user.UserRepository;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AiChatService {

    private final BlogProperties blogProperties;
    private final Clock clock;
    private final UserRepository userRepository;
    private final ContentRepository contentRepository;
    private final AiChatSessionRepository sessionRepository;
    private final AiChatMessageRepository messageRepository;
    private final AiDailyQuotaRepository quotaRepository;

    public AiChatService(
            BlogProperties blogProperties,
            Clock clock,
            UserRepository userRepository,
            ContentRepository contentRepository,
            AiChatSessionRepository sessionRepository,
            AiChatMessageRepository messageRepository,
            AiDailyQuotaRepository quotaRepository
    ) {
        this.blogProperties = blogProperties;
        this.clock = clock;
        this.userRepository = userRepository;
        this.contentRepository = contentRepository;
        this.sessionRepository = sessionRepository;
        this.messageRepository = messageRepository;
        this.quotaRepository = quotaRepository;
    }

    @Transactional
    public AiChatResponse chat(AuthenticatedUser currentUser, AiChatRequest request) {
        User user = activeUser(currentUser);
        AiDailyQuota quota = quotaFor(user);
        int dailyLimit = blogProperties.getAi().getDailyQuestionLimit();
        if (quota.getQuestionCount() >= dailyLimit) {
            throw new BusinessException(HttpStatus.TOO_MANY_REQUESTS, "今日 AI 提问次数已用完");
        }

        AiChatSession session = sessionFor(user, request);
        messageRepository.save(new AiChatMessage(session, AiMessageRole.USER, request.message().trim()));

        quota.increase();
        String answer = answerFromContentSearch(request.message());
        messageRepository.save(new AiChatMessage(session, AiMessageRole.ASSISTANT, answer));

        return new AiChatResponse(
                session.getId(),
                answer,
                suggestions(request.message()),
                Math.max(0, dailyLimit - quota.getQuestionCount())
        );
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

    private AiChatSession sessionFor(User user, AiChatRequest request) {
        if (request.sessionId() != null) {
            return sessionRepository.findByIdAndUserId(request.sessionId(), user.getId())
                    .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));
        }

        String title = request.message().trim();
        if (title.length() > 40) {
            title = title.substring(0, 40);
        }
        return sessionRepository.save(new AiChatSession(user, title));
    }

    private AiDailyQuota quotaFor(User user) {
        LocalDate today = LocalDate.now(clock.withZone(ZoneOffset.UTC));
        return quotaRepository.findByUserIdAndQuotaDate(user.getId(), today)
                .orElseGet(() -> quotaRepository.save(new AiDailyQuota(user, today)));
    }

    private String answerFromContentSearch(String message) {
        String keyword = message.toLowerCase(Locale.ROOT);
        List<Content> matches = contentRepository
                .findTop10ByStatusAndPublishedAtIsNotNullOrderByPublishedAtDesc(ContentStatus.PUBLISHED)
                .stream()
                .filter(content -> contains(content.getTitle(), keyword) || contains(content.getSummary(), keyword))
                .limit(3)
                .toList();

        if (matches.isEmpty()) {
            return "我已经记录了你的问题。下一步会接入 Spring AI 和 pgvector 后，我会结合个人知识库给出更完整的回答。";
        }

        StringBuilder answer = new StringBuilder("我先从已发布内容里找到这些可能相关的记录：");
        for (Content content : matches) {
            answer.append("\n- ").append(content.getTitle());
        }
        return answer.toString();
    }

    private boolean contains(String value, String keyword) {
        return value != null && value.toLowerCase(Locale.ROOT).contains(keyword);
    }

    private List<ToolSuggestion> suggestions(String message) {
        return List.of(
                new ToolSuggestion("search_content", "搜索相关媒体内容", Map.of("query", message)),
                new ToolSuggestion("like_content", "对内容点赞，需要用户确认", Map.of("requiresConfirmation", true)),
                new ToolSuggestion("comment_content", "给内容发表评论，需要用户确认", Map.of("requiresConfirmation", true))
        );
    }

    private User activeUser(AuthenticatedUser currentUser) {
        return userRepository.findById(currentUser.id())
                .filter(User::isActive)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
    }
}
