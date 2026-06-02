package com.caoqiang.blog.friend;

import com.caoqiang.blog.common.ApiResponse;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/friends")
public class FriendController {

    private final FriendService friendService;

    public FriendController(FriendService friendService) {
        this.friendService = friendService;
    }

    @GetMapping("/random")
    public ApiResponse<List<FriendResponse>> randomFriends() {
        return ApiResponse.ok(friendService.randomVisible());
    }
}
