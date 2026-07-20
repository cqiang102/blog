package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.ai.chat.application.dto.AiChatHistoryMessage;
import com.caoqiang.blog.config.AiConfig;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import java.util.List;
import java.util.Map;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.Message;
import org.springframework.ai.chat.messages.UserMessage;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import reactor.core.publisher.Flux;

/** Builds authenticated Spring AI prompts for synchronous and streaming conversations. */
@Service
public class AiChatModelService {

    private final ChatClient chatClient;
    private final AiBlogTools blogTools;

    public AiChatModelService(ChatClient chatClient, AiBlogTools blogTools) {
        this.chatClient = chatClient;
        this.blogTools = blogTools;
    }

    public String generateAnswer(String message, List<AiChatHistoryMessage> history, AuthenticatedUser currentUser) {
        try {
            return prompt(message, history, currentUser).call().content();
        } catch (Exception exception) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "AI 服务暂时不可用");
        }
    }

    public Flux<String> streamAnswer(
            String message, List<AiChatHistoryMessage> history, AuthenticatedUser currentUser) {
        return prompt(message, history, currentUser).stream().chatResponse().<String>handle((response, sink) -> {
            String token = token(response);
            if (token != null) {
                sink.next(token);
            }
        });
    }

    private ChatClient.ChatClientRequestSpec prompt(
            String message, List<AiChatHistoryMessage> history, AuthenticatedUser currentUser) {
        return chatClient
                .prompt()
                .system(AiConfig.systemPrompt(currentUser))
                .messages(toModelHistory(history))
                .user(message)
                .tools(blogTools)
                .toolContext(Map.of(AiBlogTools.AUTHENTICATED_USER_CONTEXT_KEY, currentUser));
    }

    List<Message> toModelHistory(List<AiChatHistoryMessage> history) {
        return history.stream()
                .map(message -> switch (message.role()) {
                    case USER -> (Message) new UserMessage(message.content());
                    case ASSISTANT -> new AssistantMessage(message.content());
                    default -> throw new IllegalArgumentException("Unsupported history role: " + message.role());
                })
                .toList();
    }

    private String token(ChatResponse response) {
        if (response.getResult() == null || response.getResult().getOutput() == null) {
            return null;
        }
        String token = response.getResult().getOutput().getText();
        return token == null || token.isEmpty() ? null : token;
    }
}
