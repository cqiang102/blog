package com.caoqiang.blog.ai;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/ai")
public class AiChatController {

    private final AiChatService aiChatService;

    public AiChatController(AiChatService aiChatService) {
        this.aiChatService = aiChatService;
    }

    @PostMapping("/chat")
    public ApiResponse<AiChatResponse> chat(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @Valid @RequestBody AiChatRequest request
    ) {
        return ApiResponse.ok(aiChatService.chat(currentUser, request));
    }

    @GetMapping("/quota")
    public ApiResponse<AiQuotaResponse> quota(@AuthenticationPrincipal AuthenticatedUser currentUser) {
        return ApiResponse.ok(aiChatService.quota(currentUser));
    }

    @PostMapping("/sessions")
    public ApiResponse<AiChatSessionResponse> createSession(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @RequestBody(required = false) AiCreateSessionRequest request
    ) {
        return ApiResponse.ok(aiChatService.createSession(currentUser,
                request != null ? request : new AiCreateSessionRequest(null)));
    }

    @GetMapping("/sessions")
    public ApiResponse<List<AiChatSessionResponse>> listSessions(
            @AuthenticationPrincipal AuthenticatedUser currentUser
    ) {
        return ApiResponse.ok(aiChatService.listSessions(currentUser));
    }

    @GetMapping("/sessions/{sessionId}/messages")
    public ApiResponse<PageResponse<AiChatMessageResponse>> sessionMessages(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID sessionId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size
    ) {
        return ApiResponse.ok(aiChatService.sessionMessages(currentUser, sessionId, page, size));
    }
}
