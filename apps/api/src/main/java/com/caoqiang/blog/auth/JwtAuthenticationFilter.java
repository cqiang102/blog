package com.caoqiang.blog.auth;

import com.caoqiang.blog.user.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
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

    /** Bearer 令牌前缀 */
    private static final String BEARER_PREFIX = "Bearer ";

    /** JWT 服务，用于解析和验证令牌 */
    private final JwtService jwtService;
    /** 用户仓库，用于查找用户信息 */
    private final UserRepository userRepository;

    /**
     * 构造函数，注入依赖
     *
     * @param jwtService     JWT 服务
     * @param userRepository 用户仓库
     */
    public JwtAuthenticationFilter(JwtService jwtService, UserRepository userRepository) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
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
        if (token != null && SecurityContextHolder.getContext().getAuthentication() == null) {
            authenticate(request, token);
        }

        // 继续过滤链
        filterChain.doFilter(request, response);
    }

    /**
     * 尝试认证用户
     * 解析 JWT 令牌，验证用户有效性，设置认证信息到安全上下文。
     *
     * @param request HTTP 请求
     * @param token   JWT 令牌
     */
    private void authenticate(HttpServletRequest request, String token) {
        try {
            // 解析 JWT 令牌，提取用户声明
            JwtClaims claims = jwtService.parseAccessToken(token);
            // 查找用户并验证状态和角色
            userRepository.findById(claims.userId())
                    .filter(user -> user.isActive() && user.getRole() == claims.role())
                    .ifPresent(user -> {
                        // 创建已认证用户主体
                        AuthenticatedUser principal = AuthenticatedUser.from(user);
                        // 创建认证令牌，设置用户主体和权限
                        UsernamePasswordAuthenticationToken authentication =
                                new UsernamePasswordAuthenticationToken(principal, null, principal.authorities());
                        // 设置请求详细信息
                        authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
                        // 将认证信息设置到安全上下文
                        SecurityContextHolder.getContext().setAuthentication(authentication);
                    });
        } catch (RuntimeException ignored) {
            // 认证失败时清除安全上下文
            SecurityContextHolder.clearContext();
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
        // 检查 Authorization 头部是否存在且以 Bearer 开头
        if (authorization == null || !authorization.startsWith(BEARER_PREFIX)) {
            return null;
        }
        // 提取令牌部分（去掉 Bearer 前缀）
        String token = authorization.substring(BEARER_PREFIX.length()).trim();
        return token.isEmpty() ? null : token;
    }
}
