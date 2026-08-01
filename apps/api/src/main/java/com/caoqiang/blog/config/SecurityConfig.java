package com.caoqiang.blog.config;

import com.caoqiang.blog.auth.infrastructure.web.JwtAuthenticationFilter;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import tools.jackson.databind.ObjectMapper;

/**
 * Spring Security 安全配置类。
 * <p>
 * 定义了博客系统的全局安全策略，包括：
 * <ul>
 *     <li>无状态 JWT 认证 — 禁用 Session，通过 {@link JwtAuthenticationFilter} 在每次请求中校验 Token</li>
 *     <li>CORS 跨域支持 — 使用 Spring 默认 CORS 配置</li>
 *     <li>基于角色的 URL 授权 — 匿名可访问健康检查、Swagger、公开内容接口；ADMIN 角色可访问管理后台</li>
 *     <li>GitHub OAuth 由浏览器绑定、单次消费的应用端流程处理</li>
 * </ul>
 *
 * @author caoqiang
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    /**
     * 构建核心安全过滤器链。
     * <p>
     * 安全规则优先级从高到低：
     * <ol>
     *     <li>放行健康检查、API 文档、认证接口（登录/注册/OAuth 回调）</li>
     *     <li>放行内容和友链的 GET 请求（公开可读）</li>
     *     <li>放行文件下载和文章浏览量统计接口</li>
     *     <li>管理后台接口仅限 ADMIN 角色</li>
     *     <li>其余接口需登录认证</li>
     * </ol>
     *
     * @param http                            Spring Security HTTP 安全构建器
     * @param jwtAuthenticationFilter         JWT 认证过滤器，在 UsernamePasswordAuthenticationFilter 之前执行
     * @return 配置完成的 SecurityFilterChain
     */
    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http, JwtAuthenticationFilter jwtAuthenticationFilter) {
        http.cors(Customizer.withDefaults())
                .csrf(AbstractHttpConfigurer::disable) // REST API 无状态，无需 CSRF 保护
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .headers(headers -> headers.httpStrictTransportSecurity(
                                hsts -> hsts.includeSubDomains(true).maxAgeInSeconds(31536000))
                        .contentSecurityPolicy(csp -> csp.policyDirectives(
                                "default-src 'self'; img-src 'self' data: https:; style-src 'self' 'unsafe-inline'"))
                        .referrerPolicy(referrer -> referrer.policy(
                                org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter
                                        .ReferrerPolicy.STRICT_ORIGIN_WHEN_CROSS_ORIGIN))
                        .frameOptions(frame -> frame.deny()))
                .exceptionHandling(
                        exceptions -> exceptions.authenticationEntryPoint(SecurityConfig::handleAuthenticationFailure))
                .authorizeHttpRequests(authorize -> authorize
                        .requestMatchers(HttpMethod.GET, "/api/v1/auth/github/bind")
                        .authenticated()
                        // 公开接口：健康检查、API 文档、认证接口
                        .requestMatchers(
                                "/actuator/health/**",
                                "/v3/api-docs/**",
                                "/swagger-ui/**",
                                "/swagger-ui.html",
                                "/api/v1/meta",
                                "/api/v1/auth/**",
                                "/error")
                        .permitAll()
                        // 公开内容接口：文章、友链的 GET 请求
                        .requestMatchers(HttpMethod.GET, "/api/v1/contents/**", "/api/v1/friends/**")
                        .permitAll()
                        // 文件下载接口
                        .requestMatchers(HttpMethod.GET, "/api/v1/media-assets/*/file")
                        .permitAll()
                        // 文章浏览量统计接口（允许匿名访问以记录 PV）
                        .requestMatchers(HttpMethod.POST, "/api/v1/contents/*/views")
                        .permitAll()
                        // 管理后台接口需 ADMIN 角色
                        .requestMatchers("/api/v1/admin/**")
                        .hasRole("ADMIN")
                        // 健康检查供容器编排公开探测；其余管理端点仅管理员可见
                        .requestMatchers("/actuator/**")
                        .hasRole("ADMIN")
                        .anyRequest()
                        .authenticated())
                .httpBasic(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                // JWT 过滤器插入到 UsernamePasswordAuthenticationFilter 之前
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    /**
     * 密码编码器，使用 BCrypt 强哈希算法。
     *
     * @return BCryptPasswordEncoder 实例
     */
    @Bean
    PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    /**
     * 系统时钟 Bean，使用 UTC 时区，供 JWT 签发/校验等场景使用。
     *
     * @return UTC 时钟
     */
    @Bean
    Clock clock() {
        return Clock.systemUTC();
    }

    private static void handleAuthenticationFailure(
            HttpServletRequest request, HttpServletResponse response, AuthenticationException authException)
            throws IOException {
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.getWriter()
                .write(new ObjectMapper()
                        .writeValueAsString(Map.of(
                                "success", false, "code", HttpStatus.UNAUTHORIZED.value(), "message", "未登录或登录已过期")));
    }
}
