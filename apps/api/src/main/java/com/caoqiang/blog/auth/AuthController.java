package com.caoqiang.blog.auth;

import com.caoqiang.blog.common.ApiResponse;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 认证 REST 控制器
 * 处理用户认证相关的 HTTP 请求，包括注册、登录、令牌刷新和 OAuth 提供者查询。
 * 位于博客系统的认证模块，是认证流程的入口层。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>用户注册 - 创建新用户账户并返回认证令牌</li>
 *   <li>用户登录 - 验证用户凭据并返回认证令牌</li>
 *   <li>令牌刷新 - 使用刷新令牌获取新的访问令牌</li>
 *   <li>OAuth 提供者查询 - 获取可用的第三方登录方式</li>
 * </ul>
 *
 * @author blog-mimo
 */
@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    /** 认证服务，处理具体的认证业务逻辑 */
    private final AuthService authService;

    /**
     * 构造函数，注入认证服务
     *
     * @param authService 认证服务实例
     */
    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    /**
     * 用户注册接口
     * 接收注册请求，创建新用户账户，并返回访问令牌和刷新令牌。
     *
     * @param request 注册请求，包含用户名、邮箱和密码
     * @return 包含访问令牌和刷新令牌的 API 响应
     */
    @PostMapping("/register")
    public ApiResponse<AuthTokenResponse> register(@Valid @RequestBody RegisterRequest request) {
        return ApiResponse.ok(authService.register(request));
    }

    /**
     * 用户登录接口
     * 验证用户凭据，成功后返回访问令牌和刷新令牌。
     *
     * @param request 登录请求，包含邮箱和密码
     * @return 包含访问令牌和刷新令牌的 API 响应
     */
    @PostMapping("/login")
    public ApiResponse<AuthTokenResponse> login(@Valid @RequestBody LoginRequest request) {
        return ApiResponse.ok(authService.login(request));
    }

    /**
     * 令牌刷新接口
     * 使用有效的刷新令牌获取新的访问令牌。
     *
     * @param request 刷新令牌请求，包含刷新令牌
     * @return 包含新访问令牌和刷新令牌的 API 响应
     */
    @PostMapping("/refresh")
    public ApiResponse<AuthTokenResponse> refresh(@Valid @RequestBody RefreshTokenRequest request) {
        return ApiResponse.ok(authService.refresh(request));
    }

    /**
     * 查询可用的 OAuth 提供者
     * 返回当前系统支持的 OAuth 登录方式及其授权 URL。
     *
     * @return 包含已启用、已预留的 OAuth 提供者列表及授权 URL 的 API 响应
     */
    @GetMapping("/providers")
    public ApiResponse<Map<String, Object>> providers() {
        return ApiResponse.ok(Map.of(
                "enabled", List.of(OAuthProvider.GITHUB),
                "reserved", List.of(OAuthProvider.QQ),
                "githubAuthorizationUrl", "/oauth2/authorization/github"
        ));
    }
}
