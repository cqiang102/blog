package com.caoqiang.blog.auth;

import com.caoqiang.blog.user.User;
import com.caoqiang.blog.user.UserProfileResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.security.core.Authentication;
import org.springframework.security.web.authentication.AuthenticationSuccessHandler;
import org.springframework.stereotype.Component;

/**
 * OAuth2 登录成功处理器
 * 处理 OAuth2 登录成功后的回调，生成 JWT 访问令牌和刷新令牌，并返回给客户端。
 * 位于博客系统的认证模块，是 OAuth2 认证流程的最后一步。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>GitHub 回调处理 - 专门处理 GitHub OAuth2 登录成功回调</li>
 *   <li>令牌生成 - 为 OAuth2 用户生成 JWT 访问令牌和刷新令牌</li>
 *   <li>JSON 响应 - 将令牌信息以 JSON 格式返回给客户端</li>
 *   <li>用户信息提取 - 从 OAuth2 认证信息中提取用户实体</li>
 * </ul>
 *
 * <p>处理流程：</p>
 * <ol>
 *   <li>从认证信息中获取 GithubOAuth2User 对象</li>
 *   <li>提取用户实体</li>
 *   <li>生成 JWT 访问令牌</li>
 *   <li>生成刷新令牌</li>
 *   <li>组装 AuthTokenResponse</li>
 *   <li>以 JSON 格式写入响应</li>
 * </ol>
 *
 * @author blog-mimo
 */
@Component
public class OAuth2LoginSuccessHandler implements AuthenticationSuccessHandler {

    /** JWT 服务，用于创建访问令牌 */
    private final JwtService jwtService;
    /** 刷新令牌服务，用于创建刷新令牌 */
    private final RefreshTokenService refreshTokenService;
    /** JSON 对象映射器，用于序列化响应 */
    private final ObjectMapper objectMapper;

    /**
     * 构造函数，注入依赖
     *
     * @param jwtService          JWT 服务
     * @param refreshTokenService 刷新令牌服务
     * @param objectMapper        JSON 对象映射器
     */
    public OAuth2LoginSuccessHandler(JwtService jwtService, RefreshTokenService refreshTokenService, ObjectMapper objectMapper) {
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
        this.objectMapper = objectMapper;
    }

    /**
     * OAuth2 认证成功回调
     * 处理 OAuth2 登录成功后的逻辑，生成令牌并返回 JSON 响应。
     *
     * @param request        HTTP 请求
     * @param response       HTTP 响应
     * @param authentication 认证信息
     * @throws IOException      如果 I/O 操作失败
     * @throws ServletException 如果 Servlet 处理失败
     */
    @Override
    public void onAuthenticationSuccess(HttpServletRequest request, HttpServletResponse response,
                                        Authentication authentication) throws IOException, ServletException {
        // 从认证信息中获取 GithubOAuth2User 对象
        GithubOAuth2User oauth2User = (GithubOAuth2User) authentication.getPrincipal();
        // 提取用户实体
        User user = oauth2User.getUser();

        // 生成 JWT 访问令牌
        JwtService.JwtToken accessToken = jwtService.createAccessToken(user);
        // 生成刷新令牌
        RefreshTokenService.RawRefreshToken refreshToken = refreshTokenService.createFor(user);

        // 设置响应内容类型为 JSON
        response.setContentType("application/json;charset=UTF-8");
        // 将令牌信息以 JSON 格式写入响应
        response.getWriter().write(objectMapper.writeValueAsString(new AuthTokenResponse(
                accessToken.value(),
                refreshToken.value(),
                accessToken.expiresAt(),
                UserProfileResponse.from(user)
        )));
    }
}
