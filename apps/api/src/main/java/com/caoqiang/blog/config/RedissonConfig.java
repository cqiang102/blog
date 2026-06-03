package com.caoqiang.blog.config;

import org.redisson.Redisson;
import org.redisson.api.RedissonClient;
import org.redisson.config.Config;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Redisson 配置类。
 * <p>
 * 提供 Redisson 客户端 Bean，用于分布式锁、限流等高级 Redis 功能。
 * 仅在 Redis 启用时生效（spring.data.redis.enabled=true）。
 *
 * @author caoqiang
 */
@Configuration
@ConditionalOnProperty(name = "spring.data.redis.enabled", havingValue = "true", matchIfMissing = true)
public class RedissonConfig {

    /**
     * 创建 Redisson 客户端 Bean。
     * <p>
     * 使用单节点模式连接 Redis，适用于开发和中小规模生产环境。
     * 大规模生产环境建议使用集群模式。
     *
     * @return Redisson 客户端实例
     */
    @Bean
    public RedissonClient redissonClient() {
        Config config = new Config();
        config.useSingleServer()
              .setAddress("redis://localhost:6379");
        return Redisson.create(config);
    }
}
