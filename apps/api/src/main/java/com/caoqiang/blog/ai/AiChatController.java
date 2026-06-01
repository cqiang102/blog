package com.caoqiang.blog.ai;

import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.config.BlogProperties;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/ai")
public class AiChatController {

    private final BlogProperties blogProperties;

    public AiChatController(BlogProperties blogProperties) {
        this.blogProperties = blogProperties;
    }

    @PostMapping("/chat")
    public ApiResponse<AiChatResponse> chat(@Valid @RequestBody AiChatRequest request) {
        return ApiResponse.ok(new AiChatResponse(
                UUID.randomUUID(),
                "AI 助手已接收你的问题。真实实现会接入 Spring AI ChatClient、pgvector 检索和工具调用。",
                List.of(
                        new ToolSuggestion("search_content", "搜索相关媒体内容", Map.of("query", request.message())),
                        new ToolSuggestion("like_content", "对当前内容点赞", Map.of("requiresConfirmation", true))
                ),
                blogProperties.getAi().getDailyQuestionLimit() - 1
        ));
    }

    @GetMapping("/quota")
    public ApiResponse<AiQuotaResponse> quota() {
        return ApiResponse.ok(new AiQuotaResponse(LocalDate.now(), blogProperties.getAi().getDailyQuestionLimit(), 0));
    }

    public record AiChatRequest(
            UUID sessionId,
            @NotBlank @Size(max = 2000) String message
    ) {
    }

    public record AiChatResponse(
            UUID sessionId,
            String answer,
            List<ToolSuggestion> suggestedTools,
            int remainingQuestions
    ) {
    }

    public record ToolSuggestion(String name, String description, Map<String, Object> arguments) {
    }

    public record AiQuotaResponse(LocalDate date, int dailyLimit, int used) {
    }
}
