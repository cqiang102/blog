package com.caoqiang.blog.auth.infrastructure.web;

import com.caoqiang.blog.auth.application.dto.AuthTokenResponse;
import com.caoqiang.blog.auth.application.dto.IssuedAuthSession;
import com.caoqiang.blog.auth.application.dto.LoginRequest;
import com.caoqiang.blog.auth.application.dto.OAuthProvidersResponse;
import com.caoqiang.blog.auth.application.dto.RegisterRequest;
import com.caoqiang.blog.auth.application.dto.SendCodeRequest;
import com.caoqiang.blog.auth.application.port.GithubOAuthClient;
import com.caoqiang.blog.auth.application.service.AuthService;
import com.caoqiang.blog.auth.application.service.OAuthStateService;
import com.caoqiang.blog.auth.application.service.VerificationService;
import com.caoqiang.blog.auth.domain.model.OAuthProvider;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.shared.util.EmailNormalizer;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.CookieValue;
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
    /** 验证码服务，处理邮箱验证码的发送和校验 */
    private final VerificationService verificationService;

    private final OAuthStateService oAuthStateService;
    private final OAuthStateCookieService oAuthStateCookieService;
    private final RefreshTokenCookieService refreshTokenCookieService;
    private final GithubOAuthClient githubOAuthClient;
    /** 前端基础地址 */
    private final String frontendBaseUrl;

    public AuthController(
            AuthService authService,
            VerificationService verificationService,
            OAuthStateService oAuthStateService,
            OAuthStateCookieService oAuthStateCookieService,
            RefreshTokenCookieService refreshTokenCookieService,
            GithubOAuthClient githubOAuthClient,
            @Value("${blog.frontend.base-url:http://localhost:3000}") String frontendBaseUrl) {
        this.authService = authService;
        this.verificationService = verificationService;
        this.oAuthStateService = oAuthStateService;
        this.oAuthStateCookieService = oAuthStateCookieService;
        this.refreshTokenCookieService = refreshTokenCookieService;
        this.githubOAuthClient = githubOAuthClient;
        this.frontendBaseUrl = frontendBaseUrl;
    }

    /**
     * 发送邮箱验证码
     * 向指定邮箱发送 6 位数字验证码，有效期 5 分钟，60 秒内不可重复发送。
     *
     * @param request 包含邮箱地址的请求
     * @return 操作成功的 API 响应
     */
    @PostMapping("/send-code")
    public ApiResponse<Void> sendCode(@Valid @RequestBody SendCodeRequest request) {
        verificationService.sendCode(EmailNormalizer.normalize(request.email()));
        return ApiResponse.ok(null);
    }

    /**
     * 用户注册接口
     * 接收注册请求，创建新用户账户，返回访问令牌并通过 HttpOnly Cookie 写入刷新令牌。
     *
     * @param request 注册请求，包含用户名、邮箱和密码
     * @return 包含访问令牌和用户信息的 API 响应
     */
    @PostMapping("/register")
    public ApiResponse<AuthTokenResponse> register(
            @Valid @RequestBody RegisterRequest request, HttpServletResponse response) {
        return sessionResponse(authService.register(request), response);
    }

    /**
     * 用户登录接口
     * 验证用户凭据，成功后返回访问令牌并通过 HttpOnly Cookie 写入刷新令牌。
     *
     * @param request 登录请求，包含邮箱和密码
     * @return 包含访问令牌和用户信息的 API 响应
     */
    @PostMapping("/login")
    public ApiResponse<AuthTokenResponse> login(
            @Valid @RequestBody LoginRequest request, HttpServletResponse response) {
        return sessionResponse(authService.login(request), response);
    }

    /**
     * 令牌刷新接口
     * 使用有效的刷新令牌获取新的访问令牌。
     *
     * @param refreshToken HttpOnly Cookie 中的刷新令牌
     * @return 包含新访问令牌和用户信息的 API 响应
     */
    @PostMapping("/refresh")
    public ApiResponse<AuthTokenResponse> refresh(
            @CookieValue(name = RefreshTokenCookieService.COOKIE_NAME, required = false) String refreshToken,
            HttpServletResponse response) {
        if (refreshToken == null || refreshToken.isBlank()) {
            throw new BusinessException(HttpStatus.UNAUTHORIZED, "刷新令牌无效");
        }
        return sessionResponse(authService.refresh(refreshToken), response);
    }

    /** 撤销刷新令牌并清除浏览器 Cookie。 */
    @PostMapping("/logout")
    public ApiResponse<Void> logout(
            @CookieValue(name = RefreshTokenCookieService.COOKIE_NAME, required = false) String refreshToken,
            HttpServletResponse response) {
        if (refreshToken != null && !refreshToken.isBlank()) {
            authService.revokeRefreshToken(refreshToken);
        }
        refreshTokenCookieService.clear(response);
        return ApiResponse.ok(null);
    }

    private ApiResponse<AuthTokenResponse> sessionResponse(IssuedAuthSession session, HttpServletResponse response) {
        refreshTokenCookieService.write(response, session.refreshToken());
        return ApiResponse.ok(session.toResponse());
    }

    /**
     * 查询可用的 OAuth 提供者
     * 返回当前系统支持的 OAuth 登录方式及其授权 URL。
     *
     * @return OAuth 提供者信息
     */
    @GetMapping("/providers")
    public ApiResponse<OAuthProvidersResponse> providers(HttpServletRequest request, HttpServletResponse response) {
        String browserId = oAuthStateCookieService.resolveOrCreate(request, response);
        String state = oAuthStateService.createLoginState(browserId);
        String callbackUrl = frontendBaseUrl + "/login/oauth2/code/github";
        String githubLoginUrl = githubOAuthClient.authorizationUrl(callbackUrl, state);
        response.setHeader(HttpHeaders.CACHE_CONTROL, "no-store");
        return ApiResponse.ok(
                new OAuthProvidersResponse(List.of(OAuthProvider.GITHUB), List.of(OAuthProvider.QQ), githubLoginUrl));
    }
}
