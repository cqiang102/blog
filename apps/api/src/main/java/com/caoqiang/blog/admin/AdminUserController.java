package com.caoqiang.blog.admin;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.auth.Role;
import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.OperationResult;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.user.AdminUserRequest;
import com.caoqiang.blog.user.AdminUserResponse;
import com.caoqiang.blog.user.UserAdminService;
import com.caoqiang.blog.user.UserStatus;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 管理端用户 CRUD 控制器
 * <p>
 * 提供管理员对用户的管理操作，包括：
 * <ul>
 *   <li>用户列表查询（支持按关键词、角色、状态筛选）</li>
 *   <li>用户详情查看</li>
 *   <li>用户信息更新（包含角色和状态变更）</li>
 *   <li>用户禁用操作</li>
 * </ul>
 * <p>
 * 所有端点均需管理员身份认证。
 * 基础路径: {@code /api/v1/admin/users}
 */
@RestController
@RequestMapping("/api/v1/admin/users")
public class AdminUserController {

    /** 用户管理服务 */
    private final UserAdminService userAdminService;

    public AdminUserController(UserAdminService userAdminService) {
        this.userAdminService = userAdminService;
    }

    /**
     * 获取用户列表（分页、筛选）
     *
     * @param page   页码，从 0 开始
     * @param size   每页大小，默认 20
     * @param query  搜索关键词（匹配邮箱或昵称）
     * @param role   角色筛选条件
     * @param status 状态筛选条件
     * @return 用户列表分页响应
     */
    @GetMapping
    public ApiResponse<PageResponse<AdminUserResponse>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String query,
            @RequestParam(required = false) Role role,
            @RequestParam(required = false) UserStatus status
    ) {
        return ApiResponse.ok(userAdminService.list(page, size, query, role, status));
    }

    /**
     * 获取用户详情
     *
     * @param id 用户 ID
     * @return 用户详情响应 DTO
     */
    @GetMapping("/{id}")
    public ApiResponse<AdminUserResponse> detail(@PathVariable UUID id) {
        return ApiResponse.ok(userAdminService.detail(id));
    }

    /**
     * 更新用户信息
     * <p>
     * 更新用户的邮箱、昵称、头像、简介、博客 URL、角色和状态。
     * 包含安全防护：管理员不能修改自己的角色或状态。
     *
     * @param currentUser 当前操作管理员
     * @param id          目标用户 ID
     * @param request     更新请求体
     * @return 更新后的用户详情响应 DTO
     */
    @PutMapping("/{id}")
    public ApiResponse<AdminUserResponse> update(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID id,
            @Valid @RequestBody AdminUserRequest request
    ) {
        return ApiResponse.ok(userAdminService.update(currentUser, id, request));
    }

    /**
     * 禁用用户
     * <p>
     * 将用户状态设置为 DISABLED，用户将无法登录。
     * 包含安全防护：管理员不能禁用自己。
     *
     * @param currentUser 当前操作管理员
     * @param id          目标用户 ID
     * @return 操作结果
     */
    @DeleteMapping("/{id}")
    public ApiResponse<OperationResult> disable(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID id
    ) {
        userAdminService.disable(currentUser, id);
        return ApiResponse.ok(OperationResult.success("禁用成功", id));
    }
}
