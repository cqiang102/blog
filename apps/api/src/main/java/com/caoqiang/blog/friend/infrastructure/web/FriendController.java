package com.caoqiang.blog.friend.infrastructure.web;

import com.caoqiang.blog.friend.application.service.FriendQueryService;
import com.caoqiang.blog.friend.application.dto.FriendResponse;
import com.caoqiang.blog.shared.response.ApiResponse;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 友链 REST 控制器
 * <p>
 * 提供友链相关的公开 API，供前端页面展示友情链接。
 * <p>
 * 所有端点均无需身份认证，用于博客前台展示。
 * 基础路径: {@code /api/v1/friends}
 */
@RestController
@RequestMapping("/api/v1/friends")
public class FriendController {

    /** 友链服务 */
    private final FriendQueryService friendQueryService;

    public FriendController(FriendQueryService friendQueryService) {
        this.friendQueryService = friendQueryService;
    }

    /**
     * 获取随机友链列表
     * <p>
     * 返回随机排序的可见友链，用于首页或侧边栏展示。
     *
     * @return 友链响应列表
     */
    @GetMapping("/random")
    public ApiResponse<List<FriendResponse>> randomFriends() {
        return ApiResponse.ok(friendQueryService.randomVisible());
    }
}
