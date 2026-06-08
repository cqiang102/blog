package com.caoqiang.blog.config;

import com.caoqiang.blog.auth.service.GithubOAuth2UserService;
import com.caoqiang.blog.auth.filter.JwtAuthenticationFilter;
import com.caoqiang.blog.auth.filter.OAuth2LoginSuccessHandler;
import tools.jackson.databind.ObjectMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.time.Clock;
import java.util.Map;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.http.HttpMethod;
import org.springframework.security.oauth2.client.registration.ClientRegistrationRepository;
import org.springframework.security.core.AuthenticationException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

/**
 * Spring Security 安全配置类。
 * <p>
 * 定义了博客系统的全局安全策略，包括：
 * <ul>
 *     <li>无状态 JWT 认证 — 禁用 Session，通过 {@link JwtAuthenticationFilter} 在每次请求中校验 Token</li>
 *     <li>CORS 跨域支持 — 使用 Spring 默认 CORS 配置</li>
 *     <li>基于角色的 URL 授权 — 匿名可访问健康检查、Swagger、公开内容接口；ADMIN 角色可访问管理后台</li>
 *     <li>可选 GitHub OAuth2 登录 — 当配置了 {@code ClientRegistrationRepository} 时自动启用</li>
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
     * @param clientRegistrationRepository    OAuth2 客户端注册仓库（可选，通过 ObjectProvider 延迟注入）
     * @param githubOAuth2UserService         GitHub OAuth2 用户服务（可选）
     * @param oAuth2LoginSuccessHandler       OAuth2 登录成功处理器（可选）
     * @return 配置完成的 SecurityFilterChain
     * @throws Exception 配置过程中可能抛出的异常
     */
    @Bean
    SecurityFilterChain securityFilterChain(
            HttpSecurity http,
            JwtAuthenticationFilter jwtAuthenticationFilter,
            ObjectProvider<ClientRegistrationRepository> clientRegistrationRepository,
            ObjectProvider<GithubOAuth2UserService> githubOAuth2UserService,
            ObjectProvider<OAuth2LoginSuccessHandler> oAuth2LoginSuccessHandler
    ) throws Exception {
        http
                .cors(Customizer.withDefaults())
                .csrf(AbstractHttpConfigurer::disable) // REST API 无状态，无需 CSRF 保护
                .sessionManagement(session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .exceptionHandling(exceptions -> exceptions
                        .authenticationEntryPoint(SecurityConfig::handleAuthenticationFailure)
                )
                .authorizeHttpRequests(authorize -> authorize
                        // 公开接口：健康检查、API 文档、认证接口
                        .requestMatchers(
                                "/actuator/health/**",
                                "/v3/api-docs/**",
                                "/swagger-ui/**",
                                "/swagger-ui.html",
                                "/api/v1/meta",
                                "/api/v1/auth/**",
                                "/error"
                        ).permitAll()
                        // 公开内容接口：文章、友链的 GET 请求
                        .requestMatchers(HttpMethod.GET, "/api/v1/contents/**", "/api/v1/friends/**").permitAll()
                        // 文件下载接口
                        .requestMatchers(HttpMethod.GET, "/api/v1/media-assets/*/file").permitAll()
                        // 文章浏览量统计接口（允许匿名访问以记录 PV）
                        .requestMatchers(HttpMethod.POST, "/api/v1/contents/*/views").permitAll()
                        // 管理后台接口需 ADMIN 角色
                        .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                        .anyRequest().authenticated()
                )
                .httpBasic(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                // JWT 过滤器插入到 UsernamePasswordAuthenticationFilter 之前
                .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);

        // 仅当配置了 OAuth2 客户端注册信息时才启用 GitHub OAuth2 登录
        if (clientRegistrationRepository.getIfAvailable() != null) {
            http.oauth2Login(oauth2 -> oauth2
                    .userInfoEndpoint(userInfo -> userInfo
                            .userService(githubOAuth2UserService.getIfAvailable())
                    )
                    .successHandler(oAuth2LoginSuccessHandler.getIfAvailable())
            );
        }

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
            HttpServletRequest request,
            HttpServletResponse response,
            AuthenticationException authException
    ) throws IOException {
        response.setStatus(HttpStatus.UNAUTHORIZED.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.getWriter().write(
                new ObjectMapper().writeValueAsString(
                        Map.of(
                                "success", false,
                                "code", 401,
                                "message", "未登录或登录已过期"
                        )
                )
        );
    }
}
