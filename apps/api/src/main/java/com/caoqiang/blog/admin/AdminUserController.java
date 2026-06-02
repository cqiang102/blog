package com.caoqiang.blog.admin;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.auth.Role;
import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.user.AdminUserRequest;
import com.caoqiang.blog.user.AdminUserResponse;
import com.caoqiang.blog.user.UserAdminService;
import com.caoqiang.blog.user.UserStatus;
import jakarta.validation.Valid;
import java.util.Map;
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

@RestController
@RequestMapping("/api/v1/admin/users")
public class AdminUserController {

    private final UserAdminService userAdminService;

    public AdminUserController(UserAdminService userAdminService) {
        this.userAdminService = userAdminService;
    }

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

    @GetMapping("/{id}")
    public ApiResponse<AdminUserResponse> detail(@PathVariable UUID id) {
        return ApiResponse.ok(userAdminService.detail(id));
    }

    @PutMapping("/{id}")
    public ApiResponse<AdminUserResponse> update(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID id,
            @Valid @RequestBody AdminUserRequest request
    ) {
        return ApiResponse.ok(userAdminService.update(currentUser, id, request));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Map<String, Object>> disable(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID id
    ) {
        userAdminService.disable(currentUser, id);
        return ApiResponse.ok(Map.of("disabled", true, "id", id));
    }
}
