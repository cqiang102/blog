package com.caoqiang.blog.admin;

import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.friend.FriendAdminService;
import com.caoqiang.blog.friend.FriendRequest;
import com.caoqiang.blog.friend.FriendResponse;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/admin/friends")
public class AdminFriendController {

    private final FriendAdminService friendAdminService;

    public AdminFriendController(FriendAdminService friendAdminService) {
        this.friendAdminService = friendAdminService;
    }

    @GetMapping
    public ApiResponse<List<FriendResponse>> list() {
        return ApiResponse.ok(friendAdminService.list());
    }

    @PostMapping
    public ApiResponse<FriendResponse> create(@Valid @RequestBody FriendRequest request) {
        return ApiResponse.ok(friendAdminService.create(request));
    }

    @PutMapping("/{id}")
    public ApiResponse<FriendResponse> update(@PathVariable UUID id, @Valid @RequestBody FriendRequest request) {
        return ApiResponse.ok(friendAdminService.update(id, request));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Map<String, Object>> delete(@PathVariable UUID id) {
        friendAdminService.delete(id);
        return ApiResponse.ok(Map.of("deleted", true, "id", id));
    }
}
