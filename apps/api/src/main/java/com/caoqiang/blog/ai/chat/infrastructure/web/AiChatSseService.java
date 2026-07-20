package com.caoqiang.blog.ai.chat.infrastructure.web;

import com.caoqiang.blog.ai.chat.application.dto.AiChatRequest;
import com.caoqiang.blog.ai.chat.application.service.AiChatStreamingService;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/** Creates the Spring MVC SSE adapter and delegates the exchange lifecycle to the application service. */
@Component
public class AiChatSseService {

    private final AiChatStreamingService streamingService;

    public AiChatSseService(AiChatStreamingService streamingService) {
        this.streamingService = streamingService;
    }

    public SseEmitter stream(AuthenticatedUser currentUser, AiChatRequest request) {
        SseAiChatStream stream = new SseAiChatStream();
        streamingService.start(currentUser, request, stream);
        return stream.emitter();
    }
}
