package com.caoqiang.blog.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * Web MVC 全局配置类。
 * <p>
 * 实现 {@link WebMvcConfigurer} 接口，配置跨域资源共享（CORS）策略。
 * 允许的来源域名通过 {@code blog.cors.allowed-origins} 配置项指定，
 * 默认包含本地开发常用的三个端口。
 *
 * @author caoqiang
 */
@Configuration
public class WebConfig implements WebMvcConfigurer {

    /** 允许的跨域来源列表，可通过配置文件覆盖 */
    @Value("${blog.cors.allowed-origins:http://localhost:3000,http://localhost:5173,http://localhost:8081}")
    private String[] allowedOrigins;

    /**
     * 配置 CORS 映射规则。
     * <p>
     * 对所有 {@code /api/**} 路径启用跨域支持，允许携带凭证（Cookie），
     * 预检请求缓存 1 小时。
     *
     * @param registry CORS 注册器
     */
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins(allowedOrigins)
                .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(true) // 允许携带 Cookie/Authorization 头
                .maxAge(3600);          // 预检请求缓存 1 小时
    }
}
