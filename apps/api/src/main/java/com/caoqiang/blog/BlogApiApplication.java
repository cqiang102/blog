package com.caoqiang.blog;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.scheduling.annotation.EnableAsync;
import org.dromara.x.file.storage.spring.EnableFileStorage;

/**
 * 博客 API 应用入口类。
 * <p>
 * 作为 Spring Boot 应用的引导类，承担以下职责：
 * <ul>
 *     <li>{@code @SpringBootApplication} - 启用自动配置、组件扫描和配置类声明</li>
 *     <li>{@code @ConfigurationPropertiesScan} - 自动扫描并注册 {@code @ConfigurationProperties} 类（如 {@link com.caoqiang.blog.config.BlogProperties}）</li>
 *     <li>{@code @EnableAsync} - 启用异步方法执行能力（如 AI 对话、缓存预热等异步任务）</li>
 * </ul>
 *
 * @author caoqiang
 */
@SpringBootApplication
@ConfigurationPropertiesScan
@EnableAsync
@EnableFileStorage
public class BlogApiApplication {

    /**
     * 应用主入口方法。
     *
     * @param args 命令行参数
     */
    public static void main(String[] args) {
        SpringApplication.run(BlogApiApplication.class, args);
    }
}
