package com.caoqiang.blog.auth.infrastructure.web;

import com.caoqiang.blog.auth.application.dto.GithubOAuth2User;
import com.caoqiang.blog.auth.application.dto.JwtClaims;
import com.caoqiang.blog.auth.application.dto.AuthTokenResponse;
import com.caoqiang.blog.auth.application.service.JwtService;
import com.caoqiang.blog.auth.application.service.RefreshTokenService;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.context.SecurityContextHolderStrategy;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.security.web.context.RequestAttributeSecurityContextRepository;
import org.springframework.security.web.context.SecurityContextRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * JWT 认证过滤器
 * 拦截 HTTP 请求，从 Authorization 头部提取 JWT 令牌，验证其有效性，并设置 Spring Security 上下文。
 * 位于博客系统的认证模块，是请求认证流程的入口点。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>单次请求过滤 - 继承 OncePerRequestFilter，确保每个请求只过滤一次</li>
 *   <li>Bearer 令牌提取 - 从 Authorization 头部提取 Bearer 令牌</li>
 *   <li>JWT 验证 - 验证令牌签名和有效期</li>
 *   <li>用户身份设置 - 将验证后的用户信息设置到 Spring Security 上下文</li>
 *   <li>异常处理 - 认证失败时清除安全上下文，不中断请求</li>
 * </ul>
 *
 * <p>处理流程：</p>
 * <ol>
 *   <li>从请求头提取 Bearer 令牌</li>
 *   <li>如果令牌存在且当前无认证信息，尝试认证</li>
 *   <li>解析 JWT 令牌，验证签名和有效期</li>
 *   <li>查找用户并验证用户状态和角色</li>
 *   <li>设置认证信息到安全上下文</li>
 *   <li>继续过滤链</li>
 * </ol>
 *
 * @author blog-mimo
 */
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(JwtAuthenticationFilter.class);

    /** Bearer 令牌前缀 */
    private static final String BEARER_PREFIX = "Bearer ";

    /** JWT 服务，用于解析和验证令牌 */
    private final JwtService jwtService;
    /** 用户仓库，用于查找用户信息 */
    private final UserAccountService userAccountService;
    /** 安全上下文策略 */
    private final SecurityContextHolderStrategy securityContextHolderStrategy =
            SecurityContextHolder.getContextHolderStrategy();
    /** 安全上下文仓库，用于将安全上下文保存到请求属性，支持异步分派 */
    private final SecurityContextRepository securityContextRepository =
            new RequestAttributeSecurityContextRepository();

    /**
     * 构造函数，注入依赖
     *
     * @param jwtService     JWT 服务
     * @param userAccountService 用户模块公开账户服务
     */
    public JwtAuthenticationFilter(JwtService jwtService, UserAccountService userAccountService) {
        this.jwtService = jwtService;
        this.userAccountService = userAccountService;
    }

    /**
     * 过滤器核心逻辑
     * 拦截每个请求，提取并验证 JWT 令牌，设置认证信息。
     *
     * @param request     HTTP 请求
     * @param response    HTTP 响应
     * @param filterChain 过滤链
     * @throws ServletException 如果过滤过程中发生错误
     * @throws IOException      如果 I/O 操作失败
     */
    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        // 从请求头提取 Bearer 令牌
        String token = bearerToken(request);
        // 如果令牌存在且当前无认证信息，尝试认证
        if (token != null && securityContextHolderStrategy.getContext().getAuthentication() == null) {
            authenticate(request, response, token);
        }

        // 继续过滤链
        filterChain.doFilter(request, response);
    }

    /**
     * 尝试认证用户
     * 解析 JWT 令牌，验证用户有效性，设置认证信息到安全上下文，
     * 并保存到请求属性以支持异步分派（如 SseEmitter.complete() 触发的分派）。
     *
     * @param request HTTP 请求
     * @param token   JWT 令牌
     */
    private void authenticate(HttpServletRequest request, HttpServletResponse response, String token) {
        try {
            // 解析 JWT 令牌，提取用户声明
            JwtClaims claims = jwtService.parseAccessToken(token);
            // 查找用户并验证状态和角色
            userAccountService.findActiveById(claims.userId())
                    .filter(user -> user.role() == claims.role())
                    .ifPresent(user -> {
                        // 创建已认证用户主体
                        AuthenticatedUser principal = new AuthenticatedUser(
                                user.id(),
                                user.email(),
                                user.nickname(),
                                user.role()
                        );
                        // 创建认证令牌，设置用户主体和权限
                        UsernamePasswordAuthenticationToken authentication =
                                new UsernamePasswordAuthenticationToken(principal, null, principal.authorities());
                        // 设置请求详细信息
                        authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                        // 创建安全上下文并设置认证信息
                        SecurityContext context = securityContextHolderStrategy.createEmptyContext();
                        context.setAuthentication(authentication);
                        securityContextHolderStrategy.setContext(context);
                        // 保存到请求属性，确保异步分派时能恢复安全上下文
                        securityContextRepository.saveContext(context, request, response);
                    });
        } catch (RuntimeException e) {
            log.debug("JWT authentication failed: {}", e.getMessage());
            securityContextHolderStrategy.clearContext();
        }
    }

    /**
     * 从请求头提取 Bearer 令牌
     *
     * @param request HTTP 请求
     * @return Bearer 令牌字符串，如果不存在或格式不正确则返回 null
     */
    private String bearerToken(HttpServletRequest request) {
        String authorization = request.getHeader("Authorization");
        if (authorization == null || !authorization.startsWith(BEARER_PREFIX)) {
            return null;
        }
        String token = authorization.substring(BEARER_PREFIX.length()).trim();
        return token.isEmpty() ? null : token;
    }
}
