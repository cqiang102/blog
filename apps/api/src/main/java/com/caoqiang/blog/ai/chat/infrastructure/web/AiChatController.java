package com.caoqiang.blog.ai.chat.infrastructure.web;

import com.caoqiang.blog.ai.chat.application.dto.AiChatRequest;
import com.caoqiang.blog.ai.chat.application.dto.AiChatResponse;
import com.caoqiang.blog.ai.chat.application.dto.AiCreateSessionRequest;
import com.caoqiang.blog.ai.chat.application.dto.AiQuotaResponse;
import com.caoqiang.blog.ai.chat.application.dto.AiChatSessionResponse;
import com.caoqiang.blog.ai.chat.application.dto.AiChatMessageResponse;
import com.caoqiang.blog.ai.chat.application.service.AiChatService;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.shared.response.OperationResult;
import com.caoqiang.blog.shared.response.PageResponse;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/**
 * AI 聊天 REST 控制器。
 * <p>
 * 提供 AI 对话相关的 HTTP 接口，包括同步聊天、流式聊天（SSE）、配额查询、会话管理和消息历史。
 * 所有接口均需要用户认证，路径前缀为 {@code /api/v1/ai}。
 */
@RestController
@RequestMapping("/api/v1/ai")
public class AiChatController {

    private final AiChatService aiChatService;

    public AiChatController(AiChatService aiChatService) {
        this.aiChatService = aiChatService;
    }

    /** 同步 AI 聊天接口，一次性返回完整回答。 */
    @PostMapping("/chat")
    public ApiResponse<AiChatResponse> chat(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @Valid @RequestBody AiChatRequest request
    ) {
        return ApiResponse.ok(aiChatService.chat(currentUser, request));
    }

    /** 流式 AI 聊天接口，通过 SSE 逐 token 推送回答。 */
    @PostMapping(value = "/chat/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter streamChat(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @Valid @RequestBody AiChatRequest request
    ) {
        return aiChatService.streamChat(currentUser, request);
    }

    /** 查询当前用户的每日 AI 配额使用情况。 */
    @GetMapping("/quota")
    public ApiResponse<AiQuotaResponse> quota(@AuthenticationPrincipal AuthenticatedUser currentUser) {
        return ApiResponse.ok(aiChatService.quota(currentUser));
    }

    /** 创建新的 AI 聊天会话。 */
    @PostMapping("/sessions")
    public ApiResponse<AiChatSessionResponse> createSession(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @RequestBody(required = false) AiCreateSessionRequest request
    ) {
        return ApiResponse.ok(aiChatService.createSession(currentUser,
                request != null ? request : new AiCreateSessionRequest(null)));
    }

    /** 获取当前用户的 AI 聊天会话列表。 */
    @GetMapping("/sessions")
    public ApiResponse<List<AiChatSessionResponse>> listSessions(
            @AuthenticationPrincipal AuthenticatedUser currentUser
    ) {
        return ApiResponse.ok(aiChatService.listSessions(currentUser));
    }

    /** 删除指定的 AI 聊天会话（逻辑删除）。 */
    @DeleteMapping("/sessions/{sessionId}")
    public ApiResponse<OperationResult> deleteSession(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID sessionId
    ) {
        aiChatService.deleteSession(currentUser, sessionId);
        return ApiResponse.ok(OperationResult.deleted(sessionId));
    }

    /** 分页获取指定会话的消息历史。 */
    @GetMapping("/sessions/{sessionId}/messages")
    public ApiResponse<PageResponse<AiChatMessageResponse>> sessionMessages(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID sessionId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return ApiResponse.ok(aiChatService.sessionMessages(currentUser, sessionId, page, size));
    }
}
