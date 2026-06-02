package com.caoqiang.blog.admin;

import com.caoqiang.blog.ai.AdminAiChatDetailResponse;
import com.caoqiang.blog.ai.AdminAiChatSessionResponse;
import com.caoqiang.blog.ai.AiChatAdminService;
import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
import java.util.Map;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/ai/chats")
public class AdminAiChatController {

    private final AiChatAdminService aiChatAdminService;

    public AdminAiChatController(AiChatAdminService aiChatAdminService) {
        this.aiChatAdminService = aiChatAdminService;
    }

    @GetMapping
    public ApiResponse<PageResponse<AdminAiChatSessionResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) UUID userId,
            @RequestParam(required = false) String query
    ) {
        return ApiResponse.ok(aiChatAdminService.sessions(page, size, userId, query));
    }

    @GetMapping("/{id}")
    public ApiResponse<AdminAiChatDetailResponse> detail(@PathVariable UUID id) {
        return ApiResponse.ok(aiChatAdminService.detail(id));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Map<String, Object>> delete(@PathVariable UUID id) {
        aiChatAdminService.delete(id);
        return ApiResponse.ok(Map.of("deleted", true, "id", id));
    }
}
