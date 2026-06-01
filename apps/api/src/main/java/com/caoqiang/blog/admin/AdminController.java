package com.caoqiang.blog.admin;

import com.caoqiang.blog.common.ApiResponse;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin")
public class AdminController {

    @GetMapping("/dashboard")
    public ApiResponse<Map<String, Object>> dashboard() {
        return ApiResponse.ok(Map.of(
                "contents", 0,
                "users", 0,
                "comments", 0,
                "likes", 0,
                "views", 0,
                "aiChatsToday", 0
        ));
    }

    @GetMapping("/logs")
    public ApiResponse<List<Map<String, Object>>> logs() {
        return ApiResponse.ok(List.of(Map.of(
                "time", Instant.now(),
                "level", "INFO",
                "message", "Admin log endpoint placeholder"
        )));
    }

    @GetMapping("/modules")
    public ApiResponse<List<String>> modules() {
        return ApiResponse.ok(List.of(
                "tags",
                "contents",
                "media",
                "comments",
                "views",
                "likes",
                "friends",
                "users",
                "ai-chats",
                "knowledge"
        ));
    }
}
