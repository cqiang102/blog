package com.caoqiang.blog.friend;

import com.caoqiang.blog.common.ApiResponse;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/friends")
public class FriendController {

    @GetMapping("/random")
    public ApiResponse<List<FriendLink>> randomFriends() {
        return ApiResponse.ok(List.of(
                new FriendLink(UUID.randomUUID(), "River Notes", "写技术和生活的朋友", "https://images.unsplash.com/photo-1494790108377-be9c29b29330", "https://example.com"),
                new FriendLink(UUID.randomUUID(), "小栈", "前端、摄影、咖啡", "https://images.unsplash.com/photo-1500648767791-00dcc994a43e", "https://example.org")
        ));
    }

    public record FriendLink(UUID id, String name, String intro, String avatarUrl, String siteUrl) {
    }
}
