package com.caoqiang.blog.config;

import tools.jackson.databind.ObjectMapper;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.core.StringRedisTemplate;

/**
 * 限流过滤器注册配置类。
 * <p>
 * 将 {@link RateLimitFilter} 注册为 Servlet 过滤器，应用于所有 {@code /api/*} 路径，
 * 并设置为最高优先级（order=1），确保限流逻辑在其他过滤器之前执行。
 *
 * @author caoqiang
 */
@Configuration
public class RateLimitConfig {

    /**
     * 注册限流过滤器 Bean。
     *
     * @param redisTemplate Redis 操作模板，用于滑动窗口计数
     * @param objectMapper  JSON 序列化器，用于构造限流响应体
     * @param blogProperties 博客配置，包含限流参数
     * @return 限流过滤器注册 Bean
     */
    @Bean
    public FilterRegistrationBean<RateLimitFilter> rateLimitFilter(
            StringRedisTemplate redisTemplate,
            ObjectMapper objectMapper,
            BlogProperties blogProperties
    ) {
        RateLimitFilter filter = new RateLimitFilter(redisTemplate, objectMapper, blogProperties);
        FilterRegistrationBean<RateLimitFilter> registration = new FilterRegistrationBean<>();
        registration.setFilter(filter);
        registration.addUrlPatterns("/api/*");
        registration.setOrder(1);
        return registration;
    }
}
