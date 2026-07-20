package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.ai.chat.application.dto.AiChatRequest;
import com.caoqiang.blog.ai.chat.application.dto.AiChatResponse;
import com.caoqiang.blog.ai.chat.application.dto.AiQuotaResponse;
import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.user.application.api.IdentityUser;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneOffset;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Coordinates synchronous AI chat and quota queries. Streaming transport has its own lifecycle service. */
@Service
public class AiChatService {

    private static final ZoneOffset QUOTA_ZONE = ZoneOffset.ofHours(8);

    private final BlogProperties blogProperties;
    private final Clock clock;
    private final AiChatSessionService sessionService;
    private final AiQuotaService quotaService;
    private final AiChatExchangeService exchangeService;
    private final AiChatModelService modelService;

    public AiChatService(
            BlogProperties blogProperties,
            Clock clock,
            AiChatSessionService sessionService,
            AiQuotaService quotaService,
            AiChatExchangeService exchangeService,
            AiChatModelService modelService) {
        this.blogProperties = blogProperties;
        this.clock = clock;
        this.sessionService = sessionService;
        this.quotaService = quotaService;
        this.exchangeService = exchangeService;
        this.modelService = modelService;
    }

    public AiChatResponse chat(AuthenticatedUser currentUser, AiChatRequest request) {
        AiChatExchangeService.PreparedExchange exchange = exchangeService.prepare(currentUser, request);
        boolean completed = false;
        try {
            String answer = modelService.generateAnswer(exchange.userMessage(), exchange.history(), currentUser);
            AiChatResponse response = exchangeService.complete(exchange, answer);
            completed = true;
            return response;
        } finally {
            if (!completed) {
                exchangeService.release(exchange);
            }
        }
    }

    @Transactional(readOnly = true)
    public AiQuotaResponse quota(AuthenticatedUser currentUser) {
        IdentityUser user = sessionService.requireActiveUser(currentUser);
        int used = quotaService.used(user.id());
        int dailyLimit = blogProperties.getAi().getDailyQuestionLimit();
        return new AiQuotaResponse(LocalDate.now(clock.withZone(QUOTA_ZONE)), dailyLimit, used);
    }
}
