package com.caoqiang.blog.config;

import java.util.concurrent.Executor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;
import org.springframework.security.concurrent.DelegatingSecurityContextExecutor;

/**
 * 异步任务配置类。
 * <p>
 * 为 {@code @Async} 方法提供专用线程池，避免使用默认的 {@code SimpleAsyncTaskExecutor}
 * （每次创建新线程，无线程池复用）。
 *
 * @author caoqiang
 */
@Configuration
@EnableAsync
public class AsyncConfig {

    /**
     * AI 流式对话专用线程池。
     * <p>
     * 用于 SSE 流式响应场景，控制并发数避免资源耗尽。
     * 使用 {@link DelegatingSecurityContextExecutor} 包装，确保安全上下文传播到异步线程，
     * 避免异步分派时 {@code AuthorizationFilter} 因缺少安全上下文而拒绝访问。
     */
    @Bean("aiStreamExecutor")
    public Executor aiStreamExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(5);
        executor.setMaxPoolSize(20);
        executor.setQueueCapacity(50);
        executor.setThreadNamePrefix("ai-stream-");
        executor.setRejectedExecutionHandler(new java.util.concurrent.ThreadPoolExecutor.CallerRunsPolicy());
        executor.initialize();
        return new DelegatingSecurityContextExecutor(executor);
    }

    /**
     * 评论审核专用线程池。
     * <p>
     * 用于 AI 评论异步审核场景，限制并发数避免 AI 服务过载。
     */
    @Bean("commentAuditExecutor")
    public Executor commentAuditExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(5);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("comment-audit-");
        executor.setRejectedExecutionHandler(new java.util.concurrent.ThreadPoolExecutor.CallerRunsPolicy());
        executor.initialize();
        return executor;
    }
}
