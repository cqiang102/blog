package com.caoqiang.blog.user;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.auth.enums.OAuthProvider;
import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.shared.response.OperationResult;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.interaction.InteractionService;
import com.caoqiang.blog.interaction.UserActivityResponse;
import jakarta.validation.Valid;
import java.util.List;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * 个人资料 REST 控制器
 * <p>
 * 处理当前登录用户的个人资料相关操作，包括：
 * <ul>
 *   <li>获取/更新个人资料</li>
 *   <li>修改密码</li>
 *   <li>查看个人互动记录（评论、点赞、浏览）</li>
 *   <li>删除个人互动记录</li>
 * </ul>
 * <p>
 * 所有端点均需身份认证，通过 {@link AuthenticatedUser} 获取当前用户信息。
 * 基础路径: {@code /api/v1/me}
 */
@RestController
@RequestMapping("/api/v1/me")
public class ProfileController {

    /** 个人资料服务 */
    private final ProfileService profileService;
    /** 互动记录服务 */
    private final InteractionService interactionService;

    public ProfileController(ProfileService profileService, InteractionService interactionService) {
        this.profileService = profileService;
        this.interactionService = interactionService;
    }

    /**
     * 获取当前用户个人资料
     *
     * @param currentUser 当前认证用户
     * @return 用户资料响应
     */
    @GetMapping
    public ApiResponse<UserProfileResponse> me(@AuthenticationPrincipal AuthenticatedUser currentUser) {
        return ApiResponse.ok(profileService.me(currentUser));
    }

    /**
     * 更新当前用户个人资料
     *
     * @param currentUser 当前认证用户
     * @param request     更新资料请求体
     * @return 更新后的用户资料响应
     */
    @PutMapping
    public ApiResponse<UserProfileResponse> update(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @Valid @RequestBody UpdateProfileRequest request
    ) {
        return ApiResponse.ok(profileService.update(currentUser, request));
    }

    /**
     * 上传并更新用户头像
     * <p>
     * 接收 multipart/form-data 格式的图片文件，上传到对象存储后更新用户头像 URL。
     *
     * @param currentUser 当前认证用户
     * @param file        上传的图片文件，字段名 "file"
     * @return 更新后的用户资料响应，包含新的头像 URL
     */
    @PostMapping(value = "/avatar", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<UserProfileResponse> uploadAvatar(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @RequestParam("file") MultipartFile file
    ) {
        return ApiResponse.ok(profileService.uploadAndUpdateAvatar(currentUser, file));
    }

    /**
     * 获取当前用户绑定的 OAuth 账户列表
     *
     * @param currentUser 当前认证用户
     * @return OAuth 账户列表
     */
    @GetMapping("/oauth-accounts")
    public ApiResponse<List<OAuthAccountResponse>> oauthAccounts(
            @AuthenticationPrincipal AuthenticatedUser currentUser
    ) {
        return ApiResponse.ok(profileService.getOAuthAccounts(currentUser));
    }

    /**
     * 解绑指定的 OAuth 账户
     *
     * @param currentUser 当前认证用户
     * @param provider    要解绑的 OAuth 提供者（如 github）
     * @return 操作结果
     */
    @DeleteMapping("/oauth-accounts/{provider}")
    public ApiResponse<OperationResult> unbindOAuth(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable String provider
    ) {
        OAuthProvider oauthProvider = OAuthProvider.valueOf(provider.toUpperCase());
        profileService.unbindOAuthAccount(currentUser, oauthProvider);
        return ApiResponse.ok(OperationResult.success("解绑成功"));
    }

    /**
     * 修改当前用户密码
     *
     * @param currentUser 当前认证用户
     * @param request     修改密码请求体，包含旧密码和新密码
     * @return 操作结果
     */
    @PutMapping("/password")
    public ApiResponse<OperationResult> changePassword(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @Valid @RequestBody ChangePasswordRequest request
    ) {
        profileService.changePassword(currentUser, request);
        return ApiResponse.ok(OperationResult.success("密码修改成功"));
    }

    /**
     * 设置密码（用于 OAuth 用户首次设置密码）
     *
     * @param currentUser 当前认证用户
     * @param request     设置密码请求体，仅包含新密码
     * @return 操作结果
     */
    @PostMapping("/password")
    public ApiResponse<OperationResult> setPassword(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @Valid @RequestBody SetPasswordRequest request
    ) {
        profileService.setPassword(currentUser, request);
        return ApiResponse.ok(OperationResult.success("密码设置成功"));
    }

    /**
     * 获取当前用户的评论记录（分页）
     *
     * @param currentUser 当前认证用户
     * @param page        页码，从 0 开始
     * @param size        每页大小，默认 20
     * @return 评论记录分页响应
     */
    @GetMapping("/comments")
    public ApiResponse<PageResponse<UserActivityResponse>> comments(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return ApiResponse.ok(interactionService.myComments(currentUser, page, size));
    }

    /**
     * 获取当前用户的点赞记录（分页）
     *
     * @param currentUser 当前认证用户
     * @param page        页码，从 0 开始
     * @param size        每页大小，默认 20
     * @return 点赞记录分页响应
     */
    @GetMapping("/likes")
    public ApiResponse<PageResponse<UserActivityResponse>> likes(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return ApiResponse.ok(interactionService.myLikes(currentUser, page, size));
    }

    /**
     * 获取当前用户的浏览记录（分页）
     *
     * @param currentUser 当前认证用户
     * @param page        页码，从 0 开始
     * @param size        每页大小，默认 20
     * @return 浏览记录分页响应
     */
    @GetMapping("/views")
    public ApiResponse<PageResponse<UserActivityResponse>> views(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        return ApiResponse.ok(interactionService.myViews(currentUser, page, size));
    }

    /**
     * 删除当前用户的指定评论
     *
     * @param currentUser 当前认证用户
     * @param commentId   要删除的评论 ID
     * @return 操作结果
     */
    @DeleteMapping("/comments/{commentId}")
    public ApiResponse<OperationResult> deleteMyComment(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID commentId
    ) {
        interactionService.deleteComment(currentUser, commentId);
        return ApiResponse.ok(OperationResult.deleted(commentId));
    }

    /**
     * 删除当前用户对指定内容的点赞
     *
     * @param currentUser 当前认证用户
     * @param contentId   要取消点赞的内容 ID
     * @return 操作结果
     */
    @DeleteMapping("/likes/{contentId}")
    public ApiResponse<OperationResult> deleteMyLike(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID contentId
    ) {
        interactionService.deleteMyLike(currentUser, contentId);
        return ApiResponse.ok(OperationResult.deleted(contentId));
    }

    /**
     * 删除当前用户的指定浏览记录
     *
     * @param currentUser  当前认证用户
     * @param viewRecordId 要删除的浏览记录 ID
     * @return 操作结果
     */
    @DeleteMapping("/views/{viewRecordId}")
    public ApiResponse<OperationResult> deleteMyView(
            @AuthenticationPrincipal AuthenticatedUser currentUser,
            @PathVariable UUID viewRecordId
    ) {
        interactionService.deleteMyView(currentUser, viewRecordId);
        return ApiResponse.ok(OperationResult.deleted(viewRecordId));
    }
}
