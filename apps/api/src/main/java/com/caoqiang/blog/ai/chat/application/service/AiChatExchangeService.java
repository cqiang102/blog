package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.ai.chat.application.dto.AiChatHistoryMessage;
import com.caoqiang.blog.ai.chat.application.dto.AiChatRequest;
import com.caoqiang.blog.ai.chat.application.dto.AiChatResponse;
import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.user.application.api.IdentityUser;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** Coordinates the shared quota, session and persistence policy for one AI exchange. */
@Service
public class AiChatExchangeService {

    private static final Logger log = LoggerFactory.getLogger(AiChatExchangeService.class);
    private static final int MAX_MESSAGES_PER_SESSION = 40;

    private final BlogProperties blogProperties;
    private final AiChatSessionService sessionService;
    private final AiQuotaService quotaService;
    private final AiChatPersistenceService persistenceService;

    public AiChatExchangeService(
            BlogProperties blogProperties,
            AiChatSessionService sessionService,
            AiQuotaService quotaService,
            AiChatPersistenceService persistenceService) {
        this.blogProperties = blogProperties;
        this.sessionService = sessionService;
        this.quotaService = quotaService;
        this.persistenceService = persistenceService;
    }

    public PreparedExchange prepare(AuthenticatedUser currentUser, AiChatRequest request) {
        IdentityUser user = sessionService.requireActiveUser(currentUser);
        int dailyLimit = blogProperties.getAi().getDailyQuestionLimit();
        AiQuotaService.Reservation reservation = quotaService.reserve(user.id(), dailyLimit);
        try {
            AiChatSessionService.ResolvedSession resolved = sessionService.resolveForChat(user, request.sessionId());
            if (resolved.messageCount() + 2 > MAX_MESSAGES_PER_SESSION) {
                throw new BusinessException(HttpStatus.CONFLICT, "该会话消息数已达上限，请创建新会话");
            }
            return new PreparedExchange(
                    user,
                    resolved.session(),
                    reservation,
                    dailyLimit,
                    request.message().trim(),
                    resolved.history());
        } catch (RuntimeException exception) {
            release(reservation);
            throw exception;
        }
    }

    public AiChatResponse complete(PreparedExchange exchange, String answer) {
        long finalMessageCount = persistenceService.persistExchange(
                exchange.user().id(),
                exchange.session().getId(),
                exchange.userMessage(),
                answer,
                MAX_MESSAGES_PER_SESSION);
        return new AiChatResponse(
                exchange.session().getId(),
                answer,
                Math.max(0, exchange.dailyLimit() - exchange.reservation().used()),
                (int) (MAX_MESSAGES_PER_SESSION - finalMessageCount));
    }

    public void release(PreparedExchange exchange) {
        release(exchange.reservation());
    }

    private void release(AiQuotaService.Reservation reservation) {
        try {
            quotaService.release(reservation);
        } catch (Exception exception) {
            log.error("Failed to release AI quota reservation", exception);
        }
    }

    public record PreparedExchange(
            IdentityUser user,
            AiChatSession session,
            AiQuotaService.Reservation reservation,
            int dailyLimit,
            String userMessage,
            List<AiChatHistoryMessage> history) {}
}
