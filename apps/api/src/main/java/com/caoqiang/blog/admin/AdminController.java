package com.caoqiang.blog.admin;

import com.caoqiang.blog.ai.AiChatSessionRepository;
import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.content.ContentRepository;
import com.caoqiang.blog.content.MediaAssetRepository;
import com.caoqiang.blog.friend.FriendRepository;
import com.caoqiang.blog.interaction.CommentRepository;
import com.caoqiang.blog.interaction.LikeRepository;
import com.caoqiang.blog.interaction.ViewRecordRepository;
import com.caoqiang.blog.user.UserRepository;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin")
public class AdminController {

    private final ContentRepository contentRepository;
    private final MediaAssetRepository mediaAssetRepository;
    private final FriendRepository friendRepository;
    private final UserRepository userRepository;
    private final CommentRepository commentRepository;
    private final LikeRepository likeRepository;
    private final ViewRecordRepository viewRecordRepository;
    private final AiChatSessionRepository aiChatSessionRepository;

    public AdminController(
            ContentRepository contentRepository,
            MediaAssetRepository mediaAssetRepository,
            FriendRepository friendRepository,
            UserRepository userRepository,
            CommentRepository commentRepository,
            LikeRepository likeRepository,
            ViewRecordRepository viewRecordRepository,
            AiChatSessionRepository aiChatSessionRepository
    ) {
        this.contentRepository = contentRepository;
        this.mediaAssetRepository = mediaAssetRepository;
        this.friendRepository = friendRepository;
        this.userRepository = userRepository;
        this.commentRepository = commentRepository;
        this.likeRepository = likeRepository;
        this.viewRecordRepository = viewRecordRepository;
        this.aiChatSessionRepository = aiChatSessionRepository;
    }

    @GetMapping("/dashboard")
    public ApiResponse<Map<String, Object>> dashboard() {
        return ApiResponse.ok(Map.of(
                "contents", contentRepository.count(),
                "media", mediaAssetRepository.count(),
                "friends", friendRepository.count(),
                "users", userRepository.count(),
                "comments", commentRepository.count(),
                "likes", likeRepository.count(),
                "views", viewRecordRepository.count(),
                "aiChats", aiChatSessionRepository.count()
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
