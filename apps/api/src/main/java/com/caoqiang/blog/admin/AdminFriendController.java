package com.caoqiang.blog.admin;

import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.OperationResult;
import com.caoqiang.blog.friend.FriendAdminService;
import com.caoqiang.blog.friend.FriendRequest;
import com.caoqiang.blog.friend.FriendResponse;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 管理端友链 CRUD 控制器
 * <p>
 * 提供管理员对友情链接的完整 CRUD 操作，包括：
 * <ul>
 *   <li>友链列表查询</li>
 *   <li>创建新友链</li>
 *   <li>更新友链信息</li>
 *   <li>删除友链</li>
 * </ul>
 * <p>
 * 所有端点均需管理员身份认证。
 * 基础路径: {@code /api/v1/admin/friends}
 */
@RestController
@RequestMapping("/api/v1/admin/friends")
public class AdminFriendController {

    /** 友链管理服务 */
    private final FriendAdminService friendAdminService;

    public AdminFriendController(FriendAdminService friendAdminService) {
        this.friendAdminService = friendAdminService;
    }

    /**
     * 获取友链列表
     *
     * @return 友链响应列表
     */
    @GetMapping
    public ApiResponse<List<FriendResponse>> list() {
        return ApiResponse.ok(friendAdminService.list());
    }

    /**
     * 创建新友链
     *
     * @param request 友链请求体
     * @return 创建后的友链响应 DTO
     */
    @PostMapping
    public ApiResponse<FriendResponse> create(@Valid @RequestBody FriendRequest request) {
        return ApiResponse.ok(friendAdminService.create(request));
    }

    /**
     * 更新友链信息
     *
     * @param id      友链 ID
     * @param request 友链请求体
     * @return 更新后的友链响应 DTO
     */
    @PutMapping("/{id}")
    public ApiResponse<FriendResponse> update(@PathVariable UUID id, @Valid @RequestBody FriendRequest request) {
        return ApiResponse.ok(friendAdminService.update(id, request));
    }

    /**
     * 删除友链
     *
     * @param id 友链 ID
     * @return 操作结果
     */
    @DeleteMapping("/{id}")
    public ApiResponse<OperationResult> delete(@PathVariable UUID id) {
        friendAdminService.delete(id);
        return ApiResponse.ok(OperationResult.deleted(id));
    }
}
