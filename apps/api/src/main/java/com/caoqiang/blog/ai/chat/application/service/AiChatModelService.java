package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.ai.chat.application.dto.AiChatHistoryMessage;
import com.caoqiang.blog.config.AiConfig;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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

    private static final Logger log = LoggerFactory.getLogger(AiChatModelService.class);

    /** 单次回答的最大字符数，与流式路径保持一致，防止模型进入重复循环导致 OOM。 */
    private static final int MAX_ANSWER_LENGTH = 50_000;

    private final ChatClient chatClient;
    private final AiBlogTools blogTools;

    public AiChatModelService(ChatClient chatClient, AiBlogTools blogTools) {
        this.chatClient = chatClient;
        this.blogTools = blogTools;
    }

    public String generateAnswer(String message, List<AiChatHistoryMessage> history, AuthenticatedUser currentUser) {
        try {
            String answer = prompt(message, history, currentUser).call().content();
            if (answer != null && answer.length() > MAX_ANSWER_LENGTH) {
                log.warn("Sync AI answer exceeded {} chars, truncating", MAX_ANSWER_LENGTH);
                answer = answer.substring(0, MAX_ANSWER_LENGTH);
            }
            return answer;
        } catch (Exception exception) {
            log.warn("AI model call failed: {}", exception.getMessage(), exception);
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
